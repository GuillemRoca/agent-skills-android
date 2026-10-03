# Floor guard: reference implementation

Every numbered dimension in `CONSTRAINTS.md` maps to a de facto tool (Step 4). The **floor** does not: it is a diff-scoped check for the moves in Step 6, and without a shipped reference every agent invents its own, so two runs produce two different guards. That is the exact non-determinism this skill exists to remove.

This is the reference. Adapt the patterns to your project; keep the contract identical.

## Contract

- **Input:** the diff between the merge base and the working tree (added *and* removed lines, plus untracked files). A guard that reads only `git diff` misses new files and staged-but-uncommitted work.
- **Detects the Step 6 moves:** a weakened threshold (in `CONSTRAINTS.md` or in build config: `kover { }`, `detekt.yml`, `lint { }`, `lint.xml`, `.editorconfig`), a test made easier (`@Ignore`/`@Disabled`, a deleted test file, an assertion removed from a test that stayed), a silenced checker (a new suppression without a `reason:`), a grown lint/detekt baseline, unfinished work (`TODO()`, `NotImplementedError`, empty `catch`) on non-test paths, a new Exceptions row.
- **Exit codes:** `0` clean, `1` at least one floor violation (block the change), `2` the guard could not run (no merge base, not a git repo). Never let a `2` read as a `0`.
- **Reports the rule and the location, never a matched secret value.** Secrets are gitleaks' job (`--redact`), not this guard's.
- **Tightening is silent, loosening is loud:** only moves that lower the bar surface.

## Running it

Save as `scripts/floor-guard.main.kts` and run with the Kotlin command-line compiler (`brew install kotlin`, or SDKMAN):

```bash
kotlin scripts/floor-guard.main.kts --base origin/main
```

In CI, run it after checkout with `fetch-depth: 0` (a shallow clone has no merge base and exits `2`, by design).

## Reference (Kotlin script)

```kotlin
#!/usr/bin/env kotlin
// floor-guard.main.kts — diff-scoped enforcement of the CONSTRAINTS.md floor.
// Usage: kotlin floor-guard.main.kts [--base <ref>]   (default base: origin/main)
import java.io.File
import kotlin.system.exitProcess

// Opt-in: set true only if CONSTRAINTS.md already bans `!!` in production code.
val BAN_NOT_NULL_ASSERTION = false

val base = args.indexOf("--base").let { i -> if (i >= 0 && i + 1 < args.size) args[i + 1] else "origin/main" }

fun bail(msg: String): Nothing {
    System.err.println("floor-guard: $msg")
    exitProcess(2)
}

// Runs git in `dir`. Returns stdout, or null on failure; null never reads as clean.
// `git diff --no-index` exits 1 whenever the two sides differ (the normal case for a new file).
fun git(vararg a: String, dir: File? = null, diffExit: Boolean = false): String? {
    val p = ProcessBuilder(listOf("git") + a)
        .apply { if (dir != null) directory(dir) }
        .redirectError(ProcessBuilder.Redirect.DISCARD)
        .start()
    val out = p.inputStream.bufferedReader().readText()
    val code = p.waitFor()
    return if (code == 0 || (diffExit && code == 1)) out else null
}

// Work from the top of the tree: `git ls-files` is relative to the current directory,
// `git diff` always covers the whole tree, and the two must name files the same way.
val top = git("rev-parse", "--show-toplevel")?.trim()?.let(::File) ?: bail("not inside a git work tree")
val mergeBase = git("merge-base", base, "HEAD", dir = top)?.trim()?.takeIf { it.isNotEmpty() }
    ?: bail("no merge base against $base")

val tracked = git("diff", "--unified=0", mergeBase, "--", dir = top) ?: bail("could not diff against $mergeBase")
val untrackedFiles = git("ls-files", "--others", "--exclude-standard", dir = top) ?: bail("could not list untracked files")
val untracked = untrackedFiles.lines().filter { it.isNotBlank() }.joinToString("\n") { f ->
    git("diff", "--no-index", "--unified=0", "/dev/null", f, dir = top, diffExit = true)
        ?: bail("could not diff untracked file $f")
}
val diff = tracked + "\n" + untracked

// Walk the diff. `---`/`+++` are headers only between a file's `diff` line and its first `@@`;
// inside a hunk every line is content. A deletion (`+++ /dev/null`) keeps the old name.
data class Line(val file: String, val text: String)
val added = mutableListOf<Line>()
val removed = mutableListOf<Line>()
val deleted = mutableListOf<String>()
fun pathOf(s: String) = s.replace(Regex("^[ab]/"), "")
var file = ""
var oldFile = ""
var inHeader = false
for (line in diff.lines()) {
    when {
        line.startsWith("diff ") -> inHeader = true
        line.startsWith("@@") -> inHeader = false
        inHeader -> when {
            line.startsWith("--- ") -> oldFile = pathOf(line.substring(4))
            line.startsWith("+++ ") -> {
                val newFile = pathOf(line.substring(4))
                file = if (newFile == "/dev/null") oldFile else newFile
                if (newFile == "/dev/null") deleted += file
            }
        }
        line.startsWith("+") -> added += Line(file, line.substring(1))
        line.startsWith("-") -> removed += Line(file, line.substring(1))
    }
}

data class Finding(val rule: String, val file: String, val text: String)
val findings = mutableListOf<Finding>()
fun flag(rule: String, f: String, text: String) = findings.add(Finding(rule, f, text.trim().take(120)))

// Source sets: src/test, src/androidTest, src/testDebug, src/testFixtures, ...
val isTest = { f: String -> Regex("""(^|/)src/[A-Za-z]*[Tt]est[A-Za-z]*/|(Test|Tests|Spec)\.kt$""").containsMatchIn(f) }
val isKotlin = { f: String -> f.endsWith(".kt") || f.endsWith(".java") }
val isConstraints = { f: String -> f.endsWith("CONSTRAINTS.md") }
val isBuildConfig = { f: String ->
    Regex("""(\.gradle(\.kts)?|detekt[^/]*\.ya?ml|(^|/)lint\.xml|\.editorconfig|gradle\.properties)$""").containsMatchIn(f)
}
val isBaseline = { f: String ->
    Regex("""(^|/)(lint-baseline[^/]*|[^/]*detekt[^/]*baseline[^/]*|baseline)\.xml$""").containsMatchIn(f)
}

// 1. Silenced checker — a suppression is allowed only with `reason:` on the same line.
val SUPPRESSIONS = Regex(
    """@(file:)?Suppress(Lint|Warnings)?\(|//\s*noinspection|ktlint-disable|tools:ignore=|gitleaks:allow"""
)
// 4. Unfinished work (non-test Kotlin only).
val STUBS = Regex(
    """\bTODO\(|NotImplementedError|UnsupportedOperationException\(\s*"[Nn]ot (yet )?implemented|catch\s*\([^)]*\)\s*\{\s*}"""
)
// 2. A test made easier.
val SKIPS = Regex("""@Ignore\b|@Disabled\b|@DisabledIf\w*|\bassume(True|False|That)\(""")
// 1b. Build config loosened without a number changing.
val CONFIG_LOOSENED = Regex(
    """abortOnError\s*=\s*false|warningsAsErrors\s*=\s*false|ignoreWarnings\s*=\s*true|checkReleaseBuilds\s*=\s*false|""" +
        """ignoreFailures\s*=\s*true|\bdisable\s*(\+=|\.add)|severity="(ignore|informational|warning)"|""" +
        """^\s*active:\s*false|ktlint_[\w-]+\s*=\s*disabled|excludeTestsMatching|failOnViolation\s*=\s*false"""
)
val NOT_NULL = Regex("""[\w)\]]!!""")

for ((f, text) in added) {
    if (SUPPRESSIONS.containsMatchIn(text) && !text.contains("reason:")) flag("silenced-checker", f, text)
    if (isKotlin(f) && !isTest(f) && STUBS.containsMatchIn(text)) flag("unfinished-work", f, text)
    if (isTest(f) && SKIPS.containsMatchIn(text)) flag("test-made-easier", f, text)
    if (isBuildConfig(f) && CONFIG_LOOSENED.containsMatchIn(text)) flag("check-weakened", f, text)
    if (BAN_NOT_NULL_ASSERTION && f.endsWith(".kt") && !isTest(f) && NOT_NULL.containsMatchIn(text)) {
        flag("not-null-assertion", f, text)
    }
    if (isConstraints(f) && Regex("""^\| *(W|E)\d+ *\|""").containsMatchIn(text)) flag("new-exception", f, text)
}

// 2b. A test file deleted, or an assertion removed from a test file that still exists.
val ASSERTION = Regex("""\b(assert\w*|verify|coVerify|expect\w*|should\w*|awaitItem|awaitError|awaitComplete)\b""")
for (f in deleted) if (isTest(f)) flag("test-deleted", f, "file deleted")
for ((f, text) in removed) {
    if (isTest(f) && f !in deleted && ASSERTION.containsMatchIn(text)) flag("assertion-removed", f, text)
}

// 3b. A lint or detekt baseline grew: more issue entries added than removed.
val BASELINE_ENTRY = Regex("""<issue\b|<ID>""")
for (f in (added.map { it.file } + removed.map { it.file }).distinct().filter(isBaseline)) {
    val grew = added.count { it.file == f && BASELINE_ENTRY.containsMatchIn(it.text) } -
        removed.count { it.file == f && BASELINE_ENTRY.containsMatchIn(it.text) }
    if (grew > 0) flag("baseline-grew", f, "+$grew entries")
}

// 1c. A numeric threshold in build config edited. The line with numbers masked is its key;
// `min*`/`minimum` keys are lowered to loosen, max/threshold/limit/budget keys raised to loosen.
val NUM = Regex("""\d+(?:\.\d+)?""")
val QUALITY_KEY = Regex("""(?i)minBound|maxBound|minValue|maxValue|maxIssues|minimum|threshold|coverage|budget|limit|allowed""")
fun configKey(t: String) = t.replace(NUM, "#").replace(Regex("""\s+"""), " ").trim()
for (r in removed.filter { isBuildConfig(it.file) && QUALITY_KEY.containsMatchIn(it.text) && NUM.containsMatchIn(it.text) }) {
    val a = added.firstOrNull { it.file == r.file && configKey(it.text) == configKey(r.text) } ?: continue
    val isMin = Regex("""(?i)\bmin|minimum|coverage""").containsMatchIn(r.text)
    val was = NUM.findAll(r.text).map { it.value.toDouble() }.toList()
    val now = NUM.findAll(a.text).map { it.value.toDouble() }.toList()
    if (was.zip(now).any { (b, n) -> if (isMin) n < b else n > b }) {
        flag("threshold-loosened", r.file, r.text.trim() + "  ->  " + a.text.trim())
    }
}

// 1d. A rule in CONSTRAINTS.md weakened or removed. A rule is a floor bullet (key: text before the
// first colon) or a table row (key: first cell). Each number carries a direction read from the words
// around it: a minimum (>=, at least, must not fall) loosens by going down, a maximum (<=, at most,
// under, must not grow) by going up. A number with no readable direction is reported whenever it
// changes. Numbers pair within their direction, so a number added elsewhere does not shift pairing.
fun ruleKey(t: String): String? {
    val s = t.trim()
    if (s.startsWith("|")) return s.split("|").map { it.trim() }.firstOrNull { it.isNotEmpty() } ?: ""
    if (Regex("""^[-*] """).containsMatchIn(s)) return s.substring(2).substringBefore(":").trim()
    return null // prose, headings, dates: not a rule
}
fun isException(t: String) = Regex("""^\| *(W|E)\d+ *\|""").containsMatchIn(t.trim())
val MIN_BEFORE = Regex("""(>=|>|≥|at least|minimum|\bmin\b|no less than|not fall|not drop)\s*$""")
val MAX_BEFORE = Regex("""(<=|<|≤|at most|maximum|\bmax\b|no more than|under|below|not grow|not exceed)\s*$""")
val MIN_AFTER = Regex("""^\s*\S*\s*(or more|or higher|must not fall|must not drop)""")
val MAX_AFTER = Regex("""^\s*\S*\s*(or less|or lower|must not grow|must not exceed)""")
data class Threshold(val n: Double, val dir: String?)
fun thresholds(t: String): List<Threshold> = NUM.findAll(t).map { m ->
    val before = t.substring(maxOf(0, m.range.first - 24), m.range.first).lowercase()
    val after = t.substring(m.range.last + 1, minOf(t.length, m.range.last + 41)).lowercase()
    val dir = when {
        MIN_BEFORE.containsMatchIn(before) || MIN_AFTER.containsMatchIn(after) -> "min"
        MAX_BEFORE.containsMatchIn(before) || MAX_AFTER.containsMatchIn(after) -> "max"
        else -> null
    }
    Threshold(m.value.toDouble(), dir)
}.toList()

val removedRules = removed.filter { isConstraints(it.file) && ruleKey(it.text) != null }
val addedRules = added.filter { isConstraints(it.file) && ruleKey(it.text) != null }
for (r in removedRules) {
    val a = addedRules.firstOrNull { ruleKey(it.text) == ruleKey(r.text) }
    if (a == null) {
        if (!isException(r.text)) flag("rule-removed", r.file, r.text) // dropping an exception tightens
        continue
    }
    val before = thresholds(r.text)
    val after = thresholds(a.text)
    var verdict: String? = null
    outer@ for (dir in listOf("min", "max", null)) {
        val now = after.filter { it.dir == dir }
        for ((i, b) in before.filter { it.dir == dir }.withIndex()) {
            val n = now.getOrNull(i)
            if (n == null) { verdict = "threshold-removed"; break@outer }
            if (n.n == b.n) continue
            val loosened = when (dir) { "min" -> n.n < b.n; "max" -> n.n > b.n; else -> true }
            if (loosened) { verdict = if (dir != null) "threshold-loosened" else "threshold-changed"; break@outer }
        }
    }
    if (verdict != null) flag(verdict, r.file, r.text.trim() + "  ->  " + a.text.trim())
}

if (findings.isEmpty()) {
    println("floor-guard: clean")
    exitProcess(0)
}
System.err.println("floor-guard: ${findings.size} floor violation(s):")
findings.forEach { System.err.println("  [${it.rule}] ${it.file}: ${it.text}") }
if (findings.any { it.rule == "rule-removed" }) {
    System.err.println("\nA rule-removed finding can also mean the rule's label changed: rename in one commit, change thresholds in another.")
}
if (findings.any { it.rule == "threshold-removed" }) {
    System.err.println("\nA threshold-removed finding can also mean a number gained or lost its direction words (\">= 80%\" becoming \"80%\").")
}
System.err.println("\nEach is a move that lowers the bar. Fix the code, or route it through a tracked exception.")
exitProcess(1)
```

## Adapting it

- **Patterns are the only project-specific part.** Extend the regexes for your suppressions (custom detekt rule sets, Compose lint IDs) and source-set layout (KMP `commonTest`, `jvmTest` already match `isTest`). The diff plumbing, the `CONSTRAINTS.md` checks, and the exit codes stay as-is.
- **`BAN_NOT_NULL_ASSERTION`** is off by default: flipping it on in a codebase that uses `!!` freely turns every touched line red. Enable it only when the project already bans `!!` (detekt `UnsafeCallOnNullableType`).
- **A `.constraintsignore`** (one glob per line) lets you exempt generated code or a path tracked in the Exceptions table; check each line's file against it before flagging, so a genuine exception is a tracked file rather than a loosened rule.
- **This is a starting point, not a finished tool.** It is deliberately regex-shallow: it catches the cheap-road-to-green moves agents actually make, not a determined human hiding a change. That is the right trade for a check that runs on every diff. Once you outgrow it, move to a real runner (Escalation Path level 3).

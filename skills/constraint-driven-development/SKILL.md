---
name: constraint-driven-development
description: >-
  Use when an Android project has no written quality bar, when the user says
  "set up constraints" or "define our standards", when coverage, performance,
  or accessibility should become enforced gates instead of per-PR arguments,
  when an agent keeps silencing checks or skipping tests to get to green, or
  when a threshold is needed and nobody knows what number to pick. Records the
  bar in CONSTRAINTS.md with a number and a Gradle command behind every rule,
  installs the de facto Android tool per dimension (Android Lint, detekt,
  Kover, Macrobenchmark, gitleaks), places checks by cost, and guards the diff
  against a lowered bar: new @Suppress or @SuppressLint, @Ignore or @Disabled
  tests, stripped assertions, TODO() stubs, grown lint or detekt baselines,
  thresholds edited down.
---

# Constraint-Driven Development

## Overview

Other skills describe what good looks like: `code-review-and-quality` gives five axes, `test-driven-development` a cycle, `security-and-hardening` a threat list. That is prose an agent may or may not follow, and none of it survives the session. This skill produces a written record of **this project's** bar, with numbers and the command that checks each one, that outlives the conversation and runs mechanically.

The reason: when you wrote the code, reading it told you whether it was good. An agent writes more in an afternoon than you will read that week, so judgement moves out of your head and into checks that run around the loop. Those checks need to exist, carry numbers you chose, and fire close enough to the work that the agent fixes its own output.

Spec-driven development says what to build. Test-driven development proves it works. Constraint-driven development defines "good enough to ship" before anyone argues about it in a pull request.

## When to Use

- Starting a project or significant feature and no quality bar is written down
- The user asks to "set up constraints", "add quality gates", "define our standards"
- An agent is producing volume nobody reads line by line
- CI runs `lint`, `detekt`, and tests, but nobody can say which ones block a merge
- Coverage, startup time, APK size, or accessibility get argued per PR instead of decided once
- Before `/build auto` or any autonomous loop, where the only thing between the agent and `main` is a test suite the agent also wrote

**Skip when:**
- `CONSTRAINTS.md` already exists and the user isn't changing it — read and follow it
- Spikes, throwaway prototypes, one-off scripts
- The user wants a review now (`code-review-and-quality`) or a pipeline built (`ci-cd-and-automation`)

**Non-interactive contexts** (CI, scheduled loops, autonomous runs): the interview needs a live user. If constraints are missing, apply the Floor below, say you did, and flag the rest for a human.

## Core Process

### Step 1: Detect Before You Ask

Never ask what you can read. Gather this first:

| What | Where to look |
|------|---------------|
| Modules and build | `settings.gradle.kts`, each `build.gradle.kts`, `gradle/libs.versions.toml`, convention plugins in `build-logic/` |
| Platform levels | `minSdk`, `targetSdk`, `compileSdk` in the app module or convention plugin |
| Test stack | JUnit4 vs JUnit5, MockK, Turbine, Robolectric, Compose UI test, existing `src/test` and `src/androidTest` |
| Static analysis | `lint.xml`, `lint { }` block, `lint-baseline.xml`, `detekt.yml`, detekt baseline, `.editorconfig` (ktlint), Spotless |
| Coverage | Kover or JaCoCo plugin, existing `koverVerify` rules, last report under `build/reports/` |
| Performance | `:benchmark` / `:baselineprofile` module, `baseline-prof.txt`, Compose compiler reports enabled |
| CI and agents | `.github/workflows/`, `AGENTS.md`, `CLAUDE.md`, `.claude/` |

Report what you found in two lines, then ask only what's left.

### Step 2: Four Questions, Each With a Default

Follow the one-question-at-a-time discipline from `interview-me`, with one change: every question has a default, so "I don't know" still produces a working config.

```
Q1: Beyond the floor, which do you want enforced?
    (a) Coverage on changed code   (b) Static analysis at zero new issues
    (c) Security: secrets + dependencies   (d) Performance budgets
    (e) Accessibility   (f) Module boundaries
GUESS: (a), (b), (c) — you have Kover and detekt already.
DEFAULT if unsure: (a), (b), (c).
Cost: (d) and (e) need a device or emulator; (f) needs rules written.
```

```
Q2: When a check fails mid-task, block or warn?
GUESS: Block. Unattended agents ignore warnings.
DEFAULT if unsure: Block on the floor, warn on the rest for two weeks.
```

```
Q3: Target numbers in mind, or measure today and hold the line?
GUESS: Measure. An invented number gets ignored.
DEFAULT if unsure: Measure and hold (see Step 7).
```

```
Q4: Slowest check you'll tolerate before the agent hands work back?
GUESS: About 90 seconds — a single module's unit tests plus koverVerify.
DEFAULT if unsure: 90 seconds at task end, unlimited in CI.
```

Stop at four. A twelve-question intake produces a config nobody understands.

### Step 3: Write CONSTRAINTS.md

One file at the repo root. Any agent on any harness can read it, and a change to it shows up in review.

```markdown
# Constraints

Last reviewed: 2026-10-04 by @owner

## Floor (always enforced, no setup required)

- Builds: `./gradlew assembleDebug` succeeds
- Unit tests: `./gradlew testDebugUnitTest` passes
- No new suppressions without a `// reason:` on the same line: `@Suppress`, `@SuppressLint`, `//noinspection`, `ktlint-disable`, `tools:ignore`
- No new `@Ignore` / `@Disabled` tests, no deleted tests, no assertions stripped from tests that stayed
- No `TODO()`, `NotImplementedError`, or empty `catch {}` on shipped (non-test) paths
- No growth of `lint-baseline.xml` or the detekt baseline
- No secrets in source
- This file does not get weakened to make a change pass

## Enforced with numbers

| Dimension | Rule | Checked by | Runs at |
|-----------|------|-----------|---------|
| Formatting | Zero violations | `./gradlew spotlessCheck` | every edit |
| Static analysis | Zero new detekt issues, maxIssues 0 | `./gradlew :<module>:detekt` | every edit |
| Lint | Zero errors, warnings as errors | `./gradlew lintDebug` | CI |
| Coverage | Changed domain/data modules ≥ 80% lines | `./gradlew :<module>:koverVerify` | task end, CI |
| Secrets | No findings | `gitleaks detect --redact --no-banner` | task end, CI |
| Dependencies | Nothing at high or above | `osv-scanner scan source -r .` | CI |
| Startup | Cold start median ≤ 500ms | `./gradlew :benchmark:connectedBenchmarkAndroidTest` | CI (emulator) |
| APK size | Release APK grows ≤ 100 KB per PR | `diffuse diff` on base vs head APK | CI |

Every row names the command that produces the verdict. A number with no
command is an aspiration, not a constraint.

## Measured, not yet enforced

| Metric | Today | Direction |
|--------|-------|-----------|
| Project line coverage | 62.4% | must not fall |
| lint-baseline.xml issues | 214 | must not grow |
| Release APK size | 18.3 MB | must not grow |

## Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
|----|------|------|--------|-------|---------|
| W1 | detekt LongMethod | `feature/legacy/**` | Rewrite tracked in ENG-441 | @owner | 2027-01-01 |
```

Then add one line to `AGENTS.md` and `CLAUDE.md`: `Read CONSTRAINTS.md before writing code. Do not weaken it to make a change pass.` (see `context-engineering`).

### Step 4: Install a Tool per Dimension

Picking a dimension means installing something. Don't leave a number with no mechanism, and don't hand-roll a checker when a de facto tool exists — the team's existing config and CI already target these.

| Dimension | Tool | Run | Gate on |
|-----------|------|-----|---------|
| Lint | Android Lint (`abortOnError = true`, `warningsAsErrors = true`) | `./gradlew lintDebug` | any error |
| Static analysis | detekt (`maxIssues: 0`, baseline for legacy) | `./gradlew detekt` | any new issue |
| Formatting | ktlint via Spotless | `./gradlew spotlessCheck` | any violation |
| Coverage | Kover (or JaCoCo with `jacocoTestCoverageVerification`) | `./gradlew koverVerify` | bound per module |
| Module boundaries | Konsist tests, or dependency-analysis-gradle-plugin | `./gradlew test` / `./gradlew buildHealth` | any violation |
| Secrets | gitleaks | `gitleaks detect --redact --no-banner` | any finding |
| Dependencies | Gradle dependency verification + osv-scanner (or OWASP dependency-check) | `osv-scanner scan source -r .` (reads `gradle.lockfile` or `verification-metadata.xml`) / `./gradlew dependencyCheckAnalyze` | high or above |
| Performance | Macrobenchmark + Baseline Profiles; Compose compiler stability reports | `./gradlew :benchmark:connectedBenchmarkAndroidTest` | startup / frame-time budget |
| APK size | diffuse, or a size-check task on `assembleRelease` output | `diffuse diff old.apk new.apk` | bytes per PR |
| Accessibility | Espresso `AccessibilityChecks.enable()`, Compose semantics tests, Lint a11y checks | `./gradlew connectedDebugAndroidTest` | any error-level result |
| Assertion quality | Pitest (gradle-pitest-plugin), JVM modules only | `./gradlew :<module>:pitest` | mutation score |

Coverage rules live in the module's build file, so the number and the check are the same artifact:

```kotlin
// core/domain/build.gradle.kts
plugins {
    id("org.jetbrains.kotlinx.kover")
}

kover {
    reports {
        verify {
            rule("Domain line coverage — see CONSTRAINTS.md") {
                bound {
                    minValue = 80
                    coverageUnits = kotlinx.kover.gradle.plugin.dsl.CoverageUnit.LINE
                }
            }
        }
    }
}
```

Five things that bite if skipped:

1. **`--redact` on gitleaks is not optional.** Without it the matched secret lands in the agent's transcript, then a log or a commit message. Report the rule and location, never the value.
2. **Macrobenchmark, instrumented accessibility checks, and `connected*` tasks need a device.** If CI has no emulator (see `ci-cd-and-automation`), keep those dimensions measured-only or CI-only on a device farm — don't pretend a JVM test covers them.
3. **Scope expensive ones to the change.** Pitest on the whole repo takes hours and gets switched off; on the touched module with `targetClasses` narrowed it takes minutes.
4. **Coverage needs no second test run.** `koverVerify` reads the same execution data `test` produced; wire it after the test task, don't run the suite twice.
5. **Baselines are debt ledgers, not escape hatches.** `lint-baseline.xml` and the detekt baseline may shrink. Regenerating one to absorb new issues is a lowered bar (Step 6).

Expose the stages as Gradle tasks so they are reproducible without an agent. A root-level aggregate keeps the commands in one place:

```kotlin
// build.gradle.kts (root)
tasks.register("checkFast") {
    group = "verification"
    description = "Edit loop: formatting + detekt. Mirrors CONSTRAINTS.md."
    dependsOn("spotlessCheck", "detekt")
}

tasks.register("checkTask") {
    group = "verification"
    description = "Task end: checkFast + unit tests + coverage bounds."
    dependsOn("checkFast", "testDebugUnitTest", "koverVerify")
}

tasks.register("checkFull") {
    group = "verification"
    description = "CI: checkTask + full lint + dependency scan."
    dependsOn("checkTask", "lintDebug", "dependencyCheckAnalyze")
}
```

`CONSTRAINTS.md` is the canonical source: it carries the reason beside each command and shows up in review. The Gradle tasks mirror it; if they drift, the file wins. Run module-scoped variants in the loop (`./gradlew :feature:tasks:detekt`) — `checkFast` at the root is for humans and hooks.

### Step 5: Place Checks by Cost

A check that stalls the agent gets switched off, and a switched-off gate is worse than none because the bar still looks like it exists.

| Phase | Command | What runs | Budget |
|-------|---------|-----------|--------|
| BUILD | `/build` | Compile of the changed module, ktlint/detekt on changed files, the floor | seconds |
| VERIFY | `/test` | Changed module's unit tests + `koverVerify` for that module, gitleaks | under 90s |
| REVIEW | `/review` | Full `lintDebug`, all unit tests, the guard (Step 6) | minutes |
| SHIP | `/ship` | Instrumented tests, Macrobenchmark, APK size diff, dependency scans | CI |

Two rules:

1. **Scope to the diff.** Gate coverage of the module a change touched, not the project — that's a number the agent can move.
2. **Cost decides placement.** Anything needing a device or a full `assembleRelease` leaves the edit loop.

### Step 6: Guard the Bar Itself

If the agent writes the code and the checks, the checks prove less. Agents don't craft clever loopholes; they hit red and take the cheapest road to green. Watch the diff for these moves:

1. **The threshold moved.** `minValue` lowered in a `kover { }` block, `maxIssues` raised in `detekt.yml`, `abortOnError = false`, a `lint.xml` severity downgraded to `warning`/`ignore`, a rule set `active: false`, `ignoreFailures = true`, a row edited in `CONSTRAINTS.md`.
2. **A test got easier.** `@Ignore`/`@Disabled` added, a test file deleted, `assertThat`/`verify`/`awaitItem` removed from a test that stayed, `excludeTestsMatching` added to the test task.
3. **A checker got silenced.** New `@Suppress`, `@SuppressLint`, `//noinspection`, `ktlint-disable`, `tools:ignore` without a reason. A grown `lint-baseline.xml` or detekt baseline is the same move in bulk.
4. **Work is unfinished.** `TODO()`, `throw NotImplementedError()`, an empty `catch (e: Exception) {}` turning a failure into silence, `runCatching { }` whose result is discarded.
5. **An exception appeared.** A new row in the Exceptions table nobody discussed.

None of this needs tooling beyond `git diff`. Tightening the bar should be silent; loosening it should be loud.

The floor has no de facto tool of its own, so an agent asked to enforce it writes a checker from scratch and two agents write two different ones. A reference implementation ships with this skill in [references/floor-guard.md](references/floor-guard.md) — a Kotlin script, diff-scoped, exit `0`/`1`/`2`. Adapt it rather than reinventing it.

**Not all checks are equally circular.** Ask: can the agent make this pass by writing code that doesn't work?

- **External** — Accessibility Test Framework encodes platform a11y rules, osv-scanner reads a vulnerability database, Macrobenchmark measures a real device. The agent can't argue with these.
- **Project** — your detekt config, your Konsist rules. A human owns the file.
- **Suite** — your own tests. Most useful, and the only genuinely circular one.

A bar made entirely of the third kind is worth less. Ensure at least one external constraint is present.

### Step 7: Ratchets, When There's No Number

Set 80% coverage on a codebase at 62% and you get a red build forever, then a team that ignores red builds.

Instead: record today's value in "Measured, not yet enforced" with a direction, and refuse to get worse. Every check compares against the recorded value, not an aspiration. When a number improves, update it; when it drops, that's the finding. Lint and detekt baselines are ratchets already — their entry count may only fall.

Models are rewarded for passing tests, which evaluate in seconds. Architectural rot shows up over months and never reaches the weights. A ratchet is the missing penalty, written where the build can see it.

## Sane Defaults

When the user has no opinion, use these. Most codebases meet them on day one.

| Constraint | Default | Why this number |
|------------|---------|-----------------|
| Coverage, domain/data modules | ≥ 80% lines (Kover) | High enough to force a test, low enough to allow wiring |
| Coverage, UI/feature modules | ≥ 50%, or today's value | Compose UI is covered better by screenshot/semantics tests than line coverage |
| Project coverage | today's value, must not fall | No argument needed to adopt |
| detekt / Lint new issues | 0 (baseline for legacy) | Existing debt is tracked, not re-litigated |
| Mutation score (Pitest, if used) | ≥ 60% to start | Typical for a never-mutated suite; 80% is mature |
| Dependency vulnerabilities | nothing at high or above | Below that is mostly noise |
| Cold startup | < 500ms median, no regression vs base | `performance-optimization` Vitals target |
| Slow frames | < 5% | Same source |
| APK size growth | ≤ 100 KB per PR, total < 10 MB compressed | Catches an accidental library; total from `performance-optimization` |
| Release health | user-perceived crash rate < 1.09%, ANR < 0.47% | Play Vitals bad-behavior thresholds (`observability-and-instrumentation`) |
| Accessibility | zero error-level ATF results | Warnings are often debatable; see `android-accessibility` |
| Exception lifetime | 90 days | Long enough to plan, short enough to remember |
| Ratchet tolerance | 0.5% | Absorbs drift when an unrelated file moves the number |

State the number and the reason together. A threshold without a rationale gets deleted by the next person who hits it.

## Escalation Path

Three levels of teeth. Start at the first.

1. **Written only.** `CONSTRAINTS.md` exists and agents read it. Catches honest mistakes.
2. **Scripted.** `checkFast` / `checkTask` / `checkFull` Gradle tasks wired into the agent's post-edit hook and CI. Deterministic, no new dependency.
3. **Tool-backed.** A dedicated runner handling diff scoping, budgets, ratchets, and the guard. Use when the config outgrows a few Gradle tasks; [references/floor-guard.md](references/floor-guard.md) is the starting point for the guard half.

Most projects stop at 2. **A first run can be floor-only:** the floor guard is diff-only and needs no plugins, so protect the first commit today and add dimensions as each tool lands. Machine-wide tools (gitleaks, osv-scanner) can run CI-only; declare it in `Runs at`.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "We'll add constraints once the code settles" | Code settles around whatever was allowed while it was moving |
| "The tests are the constraints" | Tests prove you agree with yourself; they say nothing about coverage of new code, dependency risk, or APK growth |
| "We can't hit 80% coverage" | Then don't set 80%. Record today's number and hold it |
| "Just regenerate the lint baseline" | That converts new issues into accepted debt with no owner. Baselines only shrink |
| "This will slow the agent down" | Only if device or full-lint checks sit in the edit loop. That's placement, not an argument against constraints |
| "A `@Suppress` is faster than fixing it" | It is. It's also invisible next time. Fix it, or add an Exceptions row with an owner and expiry |
| "Constraints will block shipping" | An exception with an owner and a date unblocks you. Deleting the constraint unblocks everyone forever |

## Red Flags

- The interview ran past four questions, or produced a config the user can't explain
- A budget the codebase fails today, with no ratchet or plan
- A dimension in `CONSTRAINTS.md` with a number but no Gradle task or command behind it
- A hand-rolled checker where Lint, detekt, or Kover already exists
- Every constraint judged by the project's own unit tests, no external opinion
- `CONSTRAINTS.md`, `detekt.yml`, a `kover { }` block, or a baseline file changed in the same commit as the feature that was failing
- An exception with no owner, or an expiry more than a year out
- The agent proposed relaxing a threshold instead of fixing the code
- `connectedAndroidTest` or Macrobenchmark in the edit loop, and someone started passing `--no-verify`
- Nobody has opened `CONSTRAINTS.md` since it was written

## Verification

- [ ] `CONSTRAINTS.md` exists at the repo root, every number has a stated reason
- [ ] The floor passes on the current branch: `./gradlew assembleDebug testDebugUnitTest` green and the floor guard exits `0`
- [ ] Every picked dimension has a tool applied and a command that runs today — paste the output
- [ ] Each rule states where it runs; the edit-loop stage finishes in seconds on one module
- [ ] Device-dependent dimensions are marked CI-only or measured-only if no emulator is available
- [ ] At least one constraint is external (ATF, osv-scanner, Macrobenchmark, gitleaks)
- [ ] Measured-only metrics record today's value and a direction
- [ ] Exceptions have an owner and an expiry date
- [ ] `AGENTS.md` or `CLAUDE.md` points at `CONSTRAINTS.md`
- [ ] A trial run on the current branch produces no failures the user disagrees with

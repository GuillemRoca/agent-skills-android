# /constraints — Constraint-Driven Development

Define and enforce this project's quality bar: detect, interview, sane defaults, CONSTRAINTS.md.

## Instructions

Load and follow these skills:
- `constraint-driven-development` from `skills/constraint-driven-development/SKILL.md`
- `interview-me` from `skills/interview-me/SKILL.md` (question discipline for the intake)

$ARGUMENTS

Default behaviour with no arguments: set up constraints for this repository.

1. **Detect first.** Read `settings.gradle.kts`, module `build.gradle.kts` files, `gradle/libs.versions.toml`, `minSdk`/`targetSdk`, the test stack (JUnit4/5, MockK, Turbine, Robolectric, Compose UI test), `lint.xml` / `lint-baseline.xml`, `detekt.yml` and its baseline, `.editorconfig` (ktlint), Kover or JaCoCo config, `.github/workflows/`, and `AGENTS.md` / `CLAUDE.md`. Report what you found in two lines. Never ask for anything you can read.

2. **Interview, at most four questions.** One at a time, each with your best guess and a usable default so "I don't know" still produces a working config:
   - Which dimensions beyond the floor (coverage, static analysis, security, performance, accessibility, module boundaries)
   - Block or warn when a check fails mid-task
   - Target numbers, or measure today's values and hold them
   - Slowest check tolerated before handing work back

3. **Write `CONSTRAINTS.md`** at the repo root: Floor, Enforced with numbers (each row names its Gradle task or command and where it runs), Measured not yet enforced (today's value + direction), Exceptions (owner + expiry). Every number needs a stated reason.

4. **Install what each picked dimension needs.** Use the de facto tool so existing config keeps working: Android Lint (`abortOnError`, `warningsAsErrors`) and detekt for static analysis, ktlint via Spotless for formatting, Kover (`koverVerify` rules) or JaCoCo for coverage, Konsist or dependency-analysis-gradle-plugin for module boundaries, gitleaks (always `--redact`) for secrets, Gradle dependency verification + osv-scanner or OWASP dependency-check for dependencies, Macrobenchmark + Baseline Profiles and an APK size diff for performance, `AccessibilityChecks.enable()` / Compose semantics tests for accessibility, Pitest for mutation testing on JVM modules. Macrobenchmark and instrumented accessibility checks need a device; with no emulator in CI, keep them measured-only and say so. Register `checkFast` / `checkTask` / `checkFull` Gradle tasks that mirror `CONSTRAINTS.md`.

5. **Place each check by cost.** Edit loop (seconds): compile of the changed module, ktlint/detekt on changed files. Task end (under 90s): the changed module's unit tests + its `koverVerify`, gitleaks. Review/CI: full `lintDebug`, instrumented tests, Macrobenchmark, dependency scans. Scope to the changed modules, not the whole project.

6. **Point the agent at it.** Add a line to `AGENTS.md` and `CLAUDE.md`: read `CONSTRAINTS.md` before writing code and never weaken it to make a change pass.

7. **Verify.** Run `./gradlew checkTask` and the floor guard against the current branch. If anything fails that the user disagrees with, fix the constraint now rather than leaving a gate people will learn to ignore.

## Sub-commands

- `/constraints check` — run the current constraints (`./gradlew checkTask`, plus the CI-stage commands that can run locally) against this branch and report each rule as pass/fail with its number
- `/constraints guard` — inspect the diff against the merge base for a lowered bar: thresholds edited down (`CONSTRAINTS.md`, `kover { }`, `detekt.yml`, `lint { }`, `lint.xml`), new `@Ignore`/`@Disabled` tests, deleted tests or stripped assertions, new `@Suppress`/`@SuppressLint`/`//noinspection`/`ktlint-disable` without a reason, grown lint or detekt baselines, `TODO()` stubs, new Exceptions rows. Use `skills/constraint-driven-development/references/floor-guard.md`
- `/constraints ratchet` — record today's measured values (project coverage, baseline issue counts, release APK size, startup median) in "Measured, not yet enforced" as the line that must not be crossed

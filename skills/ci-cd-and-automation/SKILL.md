---
name: ci-cd-and-automation
description: >-
  Use when setting up or improving CI/CD pipelines for Android. Covers
  sequential quality gates, Gradle caching, emulator testing in CI,
  feature flags, and automated deployment to Play Store.
---

# CI/CD and Automation

## Overview

Shift left: catch problems early through automated checks. A well-structured CI pipeline runs sequential quality gates — from fast checks (lint, compile) to slow checks (instrumented tests, security audit) — so feedback arrives quickly and issues are caught before merging.

## When to Use

- Setting up CI for a new Android project
- Adding quality gates to an existing pipeline
- CI pipeline exceeds 10 minutes (needs optimization)
- Automating deployment to Play Store or Firebase App Distribution
- Feature flag management for staged rollouts

**Skip when:** The project has no CI (start with `ci-cd-and-automation` first).

## Core Process

### Step 1: Sequential Quality Gates

1. **Gate order (fastest to slowest):**

```yaml
# .github/workflows/android-ci.yml
name: Android CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  lint-and-compile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      # Gate 1: Format check (~30s)
      - name: Check formatting
        run: ./gradlew spotlessCheck

      # Gate 2: Static analysis (~1min)
      - name: Run detekt
        run: ./gradlew detekt

      # Gate 3: Compile (~2min)
      - name: Compile
        run: ./gradlew assembleDebug

      # Gate 4: Android Lint (~3min)
      - name: Lint
        run: ./gradlew lint

  unit-tests:
    needs: lint-and-compile
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4

      # Gate 5: Unit tests (~3min)
      - name: Unit tests
        run: ./gradlew test

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: '**/build/reports/tests/'

  instrumented-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      # Gate 6: Instrumented tests (~10min)
      - name: Run instrumented tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 36   # Play target floor; add API 37 to the matrix for latest-behavior testing
          arch: x86_64
          script: ./gradlew connectedAndroidTest

  security-check:
    needs: unit-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Gate 7: Dependency vulnerability scan
      - name: Security audit
        run: ./gradlew dependencyCheckAnalyze

      # Gate 8: Secrets scan
      - name: Check for secrets
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified
```

2. **No gate skipping** — fix the code, don't disable the rule:

```kotlin
// BAD: suppressing lint
@Suppress("MagicNumber")
val timeout = 5000

// GOOD: use a named constant
private const val NETWORK_TIMEOUT_MS = 5_000L
```

### Step 2: Gradle Caching

3. **Cache Gradle dependencies and build outputs:**

```yaml
# Gradle caching is handled by gradle/actions/setup-gradle@v4
# It automatically caches:
# - ~/.gradle/caches
# - ~/.gradle/wrapper
# - .gradle (project-level)
# - Build outputs

- uses: gradle/actions/setup-gradle@v4
  with:
    cache-read-only: ${{ github.event_name == 'pull_request' }}
```

4. **Gradle build optimization:**

```properties
# gradle.properties
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configureondemand=true
org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC
```

### Step 3: Emulator Testing in CI

5. **Use `android-emulator-runner` for instrumented tests:**

```yaml
- name: Run instrumented tests
  uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: 36
    arch: x86_64
    target: google_apis
    profile: pixel_6
    emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio
    disable-animations: true
    script: ./gradlew connectedAndroidTest
```

If the repo has committed Maestro flows (`.maestro/`), run them in the same emulator job after installing the debug build — `./gradlew installDebug && maestro test .maestro/` — so every shipped acceptance criterion is regression-checked per PR (see `android-e2e-verification`).

When the `android` CLI is present in the runner image, `android sdk install` is a leaner alternative to `setup-android` for declarative platform/build-tools provisioning:

```yaml
- name: Install Android platforms
  run: |
    android sdk install \
      platforms/android-35 \
      build-tools/35.0.0 \
      platform-tools
```

Stick with `reactivecircus/android-emulator-runner` for the emulator itself — `android emulator` is **disabled on Windows** and the runner action handles snapshot caching, hardware acceleration, and animation disabling that you'd otherwise rebuild by hand. See `references/android-cli-reference.md`.

6. **Test sharding for large test suites:**

```yaml
strategy:
  matrix:
    shard: [0, 1, 2, 3]
steps:
  - name: Run tests (shard ${{ matrix.shard }})
    run: |
      ./gradlew connectedAndroidTest \
        -Pandroid.testInstrumentationRunnerArguments.numShards=4 \
        -Pandroid.testInstrumentationRunnerArguments.shardIndex=${{ matrix.shard }}
```

### Step 4: Feature Flags

7. **Decouple deployment from release:**

```kotlin
// Build-time flags (for CI/staging)
// build.gradle.kts
android {
    buildTypes {
        debug {
            buildConfigField("Boolean", "FEATURE_NEW_UI", "true")
        }
        release {
            buildConfigField("Boolean", "FEATURE_NEW_UI", "false")
        }
    }
}

// Runtime flags (for gradual rollout)
// Using Firebase Remote Config
class FeatureFlagRepository @Inject constructor(
    private val remoteConfig: FirebaseRemoteConfig,
) {
    fun isEnabled(key: String): Flow<Boolean> = callbackFlow {
        val listener = ConfigUpdateListener { trySend(remoteConfig.getBoolean(key)) }
        remoteConfig.addOnConfigUpdateListener(listener)
        trySend(remoteConfig.getBoolean(key))
        awaitClose { /* cleanup */ }
    }
}
```

### Step 5: Deployment Automation

8. **Firebase App Distribution (internal testing):**

```yaml
deploy-internal:
  needs: [unit-tests, instrumented-tests, security-check]
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-java@v4
      with:
        distribution: temurin
        java-version: 17

    - name: Build release APK
      run: ./gradlew assembleRelease

    - name: Upload to Firebase App Distribution
      uses: wzieba/Firebase-Distribution-Github-Action@v1
      with:
        appId: ${{ secrets.FIREBASE_APP_ID }}
        serviceCredentialsFileContent: ${{ secrets.FIREBASE_CREDENTIALS }}
        groups: internal-testers
        file: app/build/outputs/apk/release/app-release.apk
```

9. **Play Store (production):**

```yaml
deploy-production:
  needs: [deploy-internal]  # After internal testing
  if: startsWith(github.ref, 'refs/tags/v')
  runs-on: ubuntu-latest
  steps:
    - name: Upload to Play Store
      uses: r0adkll/upload-google-play@v1
      with:
        serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_CREDENTIALS }}
        packageName: com.example.app
        releaseFiles: app/build/outputs/bundle/release/app-release.aab
        track: internal  # internal → alpha → beta → production
        status: completed
```

### Step 6: Feedback Loops

10. **When CI fails, use the agent feedback loop:**
    1. Read the failure output
    2. Identify the gate that failed
    3. Fix the specific issue (don't disable the gate)
    4. Re-run the pipeline
    5. If the fix introduces new failures, revert and investigate

### Step 7: Pipeline Optimization

11. **If pipeline exceeds 10 minutes:**
    - **Cache dependencies** (Gradle, SDK components)
    - **Parallelize independent gates** (lint + unit tests simultaneously)
    - **Selective testing** (only run affected modules)
    - **Test sharding** (split instrumented tests across emulators)
    - **Build cache** (enable Gradle build cache)

## Environment Separation

| Environment | Secrets Source | Build Type |
|------------|---------------|-----------|
| Local | `local.properties` (gitignored) | Debug |
| CI | GitHub Secrets / Vault | Debug + Release |
| Staging | Firebase Remote Config | Release (staging flavor) |
| Production | Play Store + Firebase | Release |

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "CI is too slow, I'll push without waiting" | Pushing broken code blocks the team. Optimize the pipeline instead. |
| "Lint warnings aren't real errors" | Lint catches real bugs (unused resources, API compatibility, security issues). |
| "Instrumented tests are too flaky for CI" | Flaky tests have root causes. Fix them or isolate them — don't skip them. |
| "We'll add CI later" | Later means tech debt. Start with lint + compile + unit tests on day one. |

## Red Flags

- No CI pipeline
- CI gates disabled or skipped (`@Suppress`, `-x lint`)
- No Gradle caching in CI
- Instrumented tests not running in CI
- Secrets in repository (use GitHub Secrets)
- No deployment automation
- Pipeline exceeds 15 minutes without optimization
- Feature flags without cleanup plan

## Verification

- [ ] CI runs on every PR and push to main
- [ ] Gates run in order: format → lint → compile → unit tests → instrumented tests → security
- [ ] No gates skipped or disabled
- [ ] Gradle caching configured
- [ ] Instrumented tests run on emulator in CI
- [ ] Secrets stored in CI environment (not in repo)
- [ ] Deployment automated (Firebase App Distribution and/or Play Store)
- [ ] Pipeline completes in < 15 minutes
- [ ] Failed gates produce actionable error messages

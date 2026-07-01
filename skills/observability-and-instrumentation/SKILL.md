---
name: observability-and-instrumentation
description: >-
  Use when adding logging, crash reporting, or performance monitoring, or
  before shipping a release that must be watched in production. Covers
  Crashlytics, Play Vitals thresholds, structured logging with Timber,
  reportFullyDrawn, release-health monitoring, and CI performance gates.
---

# Observability and Instrumentation

## Overview

You cannot fix what you cannot see. This skill makes production behavior observable: crashes and ANRs reported with enough context to fix, startup and jank measured against Play Vitals thresholds, and logs structured so they help without leaking user data. Instrumentation is part of the feature, not an afterthought bolted on when the first bad review arrives.

## When to Use

- Adding a feature whose failures would be invisible without instrumentation (payments, sync, background work)
- Setting up or auditing crash reporting and performance monitoring
- Before any release that will be watched during staged rollout (see `shipping-and-launch`)
- Investigating field-only issues where local reproduction failed (see `debugging-and-error-recovery`)

**Skip when:** Prototypes or internal builds that will never reach users — but wire observability in before the first external release, not after.

## Core Process

### Step 1: Crash and ANR Reporting

1. **Crashlytics (or Sentry) with context, not just stack traces:**

```kotlin
// Attach the state that turns a stack trace into a diagnosis
FirebaseCrashlytics.getInstance().apply {
    setCustomKey("screen", "task_detail")
    setCustomKey("sync_state", syncState.name)
    setUserId(pseudonymousId)          // NEVER an email or real identifier
    recordException(NonFatalSyncError(cause))  // non-fatals for handled-but-wrong paths
}
```

2. **Reporting rules:**
   - Record **non-fatal** exceptions for caught-but-abnormal paths — a swallowed exception is an invisible bug
   - Custom keys over log spam: state at crash time beats a breadcrumb trail
   - Upload the R8 mapping file automatically in the release pipeline (Crashlytics Gradle plugin does this) — an obfuscated stack trace is noise
   - ANRs are surfaced by Play Vitals, not your crash SDK — watch both

### Step 2: Play Vitals Thresholds

3. **Know the numbers Google judges you by** (Play Console → Android Vitals):

| Metric | Bad-behavior threshold |
|--------|------------------------|
| User-perceived ANR rate | 0.47% |
| User-perceived crash rate | 1.09% |
| Excessive wakeups / stuck wake locks | per-device-hour budgets |

Exceeding a threshold suppresses your Play Store visibility. Vitals is the scoreboard; your in-app instrumentation exists to explain *why* a number moved.

### Step 3: Structured Logging

4. **Timber with a release tree — logs are for debug builds, telemetry is for release:**

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(
            if (BuildConfig.DEBUG) Timber.DebugTree()
            else CrashReportingTree()   // routes WARN/ERROR to Crashlytics, drops the rest
        )
    }
}

// GOOD: structured, no PII
Timber.w("sync_failed attempt=%d reason=%s", attempt, reason.name)

// BAD: PII in a log line — logcat is world-readable on rooted devices
Timber.d("sync failed for user %s token %s", email, token)
```

5. **Logging rules:**
   - No PII, tokens, or request bodies at any level
   - `Log.d`/`Log.v` stripped in release via R8 (`-assumenosideeffects`, see `references/security-checklist.md`)
   - One event, one line, stable key=value shape — greppable beats prose

### Step 4: Performance Instrumentation

6. **Measure startup honestly with `reportFullyDrawn`:**

```kotlin
// The system's TTID stops at first frame; report when content is actually usable
class TaskListActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val uiState by viewModel.uiState.collectAsStateWithLifecycle()
            if (uiState is TaskListUiState.Success) {
                LaunchedEffect(Unit) { reportFullyDrawn() }
            }
            TaskListContent(uiState)
        }
    }
}
```

7. **Custom traces for the flows that matter** (Firebase Performance or `androidx.tracing`):

```kotlin
val trace = Firebase.performance.newTrace("checkout_flow")
trace.start()
// ...
trace.putMetric("items", cart.size.toLong())
trace.stop()
```

8. **Gate regressions in CI:** run Macrobenchmark on the release candidate and fail on startup/jank regressions against the previous baseline (see `performance-optimization` and `ci-cd-and-automation`). A regression caught in CI costs a re-run; caught in Vitals it costs users.

### Step 5: Release Health During Rollout

9. **Staged rollout is only as good as what you watch** (see `shipping-and-launch`):
   - Define the abort criteria *before* rolling: e.g. "halt at crash rate > 0.5% or ANR > 0.3% on the new version"
   - Compare version-over-version, not absolute: a new crash cluster at 5% rollout predicts the 100% disaster
   - Watch: Crashlytics velocity alerts, Vitals per-version, key business events (did sign-ins drop?)

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "We'll add monitoring after launch" | The launch is exactly when you need it. Post-hoc instrumentation can't explain last week's spike. |
| "Crashlytics is set up, we're covered" | Crash reporting without custom keys, non-fatals, and mapping uploads produces unactionable noise. |
| "Logs are enough" | Release builds strip logs, and users don't send logcat. Telemetry is what you actually get from the field. |
| "PII in logs is fine, it's just debug" | Debug logs leak into bug reports, screenshots, and third-party SDK capture. Treat every log line as public. |
| "Vitals looks fine, ship it" | Vitals lags by days. Version-scoped Crashlytics velocity is your early-warning system during rollout. |

## Red Flags

- `catch (e: Exception) { }` with no `recordException` — swallowed failures are invisible
- Log lines containing emails, tokens, or request bodies
- Release builds still planting `Timber.DebugTree()`
- No mapping file upload in the release pipeline
- Staged rollout with no written abort criteria
- Startup "measured" only by TTID with no `reportFullyDrawn`
- Performance claims in PRs with no Macrobenchmark or trace evidence

## Verification

- [ ] Crash reporting captures custom keys and non-fatals for the changed flows
- [ ] R8 mapping file uploaded automatically on release builds
- [ ] No PII/tokens in any log statement (grep the diff for log calls)
- [ ] Release log tree drops DEBUG/VERBOSE; R8 strips `Log.d`/`Log.v`
- [ ] `reportFullyDrawn` called when primary content is usable
- [ ] Macrobenchmark (or trace) evidence attached for performance-sensitive changes
- [ ] Rollout abort criteria written down with owner and thresholds

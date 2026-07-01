---
name: android-background-work
description: >-
  Use when work must run outside the visible UI — sync, uploads, periodic
  jobs, long-running tasks. Covers WorkManager constraints and expedited
  work, foreground service types, exact alarms policy, Doze/App Standby,
  and testing background work deterministically.
---

# Android Background Work

## Overview

Background execution on Android is a negotiation with the OS, not a right. Doze, App Standby buckets, foreground-service type enforcement, and exact-alarm policy all exist to kill battery-hungry work — code that ignores them runs fine on the developer's charging Pixel and silently never runs in the field. This skill picks the correct primitive for each job and makes background work observable and testable.

## When to Use

- Syncing data, uploading files, or refreshing content off-screen
- Scheduling periodic or deferred jobs
- Long-running user-initiated tasks (export, media processing)
- Anything currently "solved" with `GlobalScope.launch` or a raw `Service`

**Skip when:** The work only matters while the screen is visible — use `viewModelScope`/`lifecycleScope` and let it cancel with the UI.

## Core Process

### Step 1: Pick the Right Primitive

1. **Decision table — default to WorkManager:**

| Need | Primitive |
|------|-----------|
| Deferrable, guaranteed (sync, upload) | WorkManager `OneTimeWorkRequest` |
| Periodic (≥15 min interval) | WorkManager `PeriodicWorkRequest` |
| User-visible ongoing task (playback, navigation, recording) | Foreground service with a declared type |
| User-facing alarm/reminder at an exact time | `AlarmManager.setExactAndAllowWhileIdle` + `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` |
| Work only while UI is alive | Coroutine scope tied to the lifecycle — not background work |

Choosing a foreground service for deferrable work, or exact alarms for "roughly hourly", fails Play review and drains battery.

### Step 2: WorkManager Done Right

2. **Constraints and backoff instead of retry loops:**

```kotlin
val syncRequest = OneTimeWorkRequestBuilder<SyncWorker>()
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .build()
    )
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
    .build()

// Unique work: a second "sync now" tap must not enqueue a second sync
WorkManager.getInstance(context).enqueueUniqueWork(
    "sync", ExistingWorkPolicy.KEEP, syncRequest
)
```

3. **Worker rules:**
   - `CoroutineWorker` + `Result.retry()` on transient failures; `Result.failure()` only for permanent ones
   - **Expedited work** (`setExpedited`) for short user-initiated jobs that should dodge Doze — with `getForegroundInfo()` implemented for the pre-API-31 fallback
   - Workers are re-run after process death: make them idempotent (upsert, not insert)
   - Inject dependencies via Hilt's `@HiltWorker` + `HiltWorkerFactory`, not service locators

### Step 3: Foreground Services Under Type Enforcement

4. **Since API 34 every foreground service declares a type** — in the manifest *and* at start, with the type's prerequisite permission:

```xml
<service
    android:name=".playback.PlaybackService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="false" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

```kotlin
ServiceCompat.startForeground(
    this, NOTIFICATION_ID, notification,
    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
)
```

Starting with a mismatched or undeclared type throws; `dataSync` type is being phased out — use WorkManager for transfers. The notification requires `POST_NOTIFICATIONS` runtime permission on API 33+.

### Step 4: Respect Doze and Standby

5. **Design for the powered-off case:**
   - Doze defers network, jobs, and standard alarms into maintenance windows — WorkManager already cooperates; hand-rolled `Handler.postDelayed` loops do not
   - App Standby buckets throttle how often deferred work runs — heavy users get more budget than dormant installs; never promise sync freshness the bucket can't deliver
   - `setAndAllowWhileIdle` is rate-limited (~once/9 min per app) — it is for user-facing alarms, not sync
   - **Never** ask for `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` as a convenience — it's a Play-policy-restricted permission for genuinely exempt app categories

### Step 5: Test It Deterministically

6. **WorkManager has a real test API — use it instead of sleeping:**

```kotlin
@Before
fun setup() {
    val config = Configuration.Builder()
        .setExecutor(SynchronousExecutor())
        .build()
    WorkManagerTestInitHelper.initializeTestWorkManager(context, config)
}

@Test
fun syncWorker_runs_whenConstraintsMet() {
    val request = OneTimeWorkRequestBuilder<SyncWorker>()
        .setConstraints(networkConstraints)
        .build()
    WorkManager.getInstance(context).enqueue(request).result.get()

    // Simulate the OS satisfying constraints
    WorkManagerTestInitHelper.getTestDriver(context)!!
        .setAllConstraintsMet(request.id)

    val info = WorkManager.getInstance(context).getWorkInfoById(request.id).get()
    assertEquals(WorkInfo.State.SUCCEEDED, info.state)
}
```

7. **On-device verification** (see `android-device-testing`):

```bash
adb shell dumpsys jobscheduler | grep <package>     # scheduled jobs
adb shell am send-trim-memory <package> RUNNING_CRITICAL
adb shell cmd deviceidle force-idle                  # simulate Doze
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "A foreground service is simpler than WorkManager" | Type enforcement, notification permission, and Play review make it the complicated option — and it dies anyway when the user swipes the app. |
| "GlobalScope.launch works fine" | Until process death. No retry, no constraints, no guarantee — it works on the dev device and drops work in the field. |
| "I need exact timing for sync" | You need *eventual* sync. Exact alarms are policy-gated for user-facing alarms; sync at :00 sharp is battery abuse with no user benefit. |
| "I'll test background work manually" | Doze and standby buckets don't manifest in a 2-minute manual test. `WorkManagerTestInitHelper` and `force-idle` reproduce what the field does. |
| "Battery-optimization exemption fixes it" | It fixes your test device and fails Play review. Design for Doze instead of opting out of it. |

## Red Flags

- Raw `Service` or `GlobalScope.launch` doing deferrable work
- Foreground service without a manifest `foregroundServiceType`
- `dataSync` foreground service where WorkManager belongs
- Periodic work under 15 minutes "scheduled" with self-rearming alarms
- Non-idempotent workers (duplicate rows after a retry)
- `enqueue` instead of `enqueueUniqueWork` for user-triggerable jobs
- No test using `WorkManagerTestInitHelper` for critical background flows

## Verification

- [ ] Each background job maps to the decision table's primitive (state which and why)
- [ ] WorkRequests have constraints and backoff; user-triggerable work is unique work
- [ ] Workers are idempotent — a forced re-run produces no duplicates
- [ ] Foreground services declare types + prerequisite permissions; start succeeds on API 34+
- [ ] `POST_NOTIFICATIONS` flow handled for service notifications (API 33+)
- [ ] Tests pass with `WorkManagerTestInitHelper` (`./gradlew test` output)
- [ ] Behavior verified under `cmd deviceidle force-idle` for sync-critical flows

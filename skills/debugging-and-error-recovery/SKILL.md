---
name: debugging-and-error-recovery
description: >-
  Use when encountering unexpected behavior, crashes, or test failures in
  Android. Six-step triage from reproduction to regression guard, using
  Logcat, Android Studio debugger, and profiling tools.
---

# Debugging and Error Recovery

## Overview

"Stop-the-Line Rule: when unexpected behavior occurs, halt feature work." Debugging is systematic, not guesswork. Reproduce the bug, localize the cause, reduce to the simplest case, fix the root cause (not the symptom), guard against regression, and verify the fix.

## When to Use

- Unexpected crash or exception
- Test failure (unit or instrumented)
- Behavior that doesn't match the spec
- Performance regression (jank, slow startup)
- Build failure after seemingly unrelated changes

**Stop-the-Line:** When you encounter unexpected behavior, stop feature work. Errors compound — a bug in step 3 makes steps 4–10 wrong.

## Core Process

### Step 1: Reproduce

1. **Reproduce the bug reliably:**
   - Same device/emulator? Same API level? Same data?
   - What sequence of actions triggers it?
   - Does it happen every time or intermittently?

2. **Capture the environment:**
   ```
   Device: Pixel 7 (API 35) / Emulator (API 26)
   Build: debug / release
   Steps: Open app → Navigate to Tasks → Tap "Add" → Crash
   Frequency: Every time / ~30% of the time
   ```

   When the `android` CLI is available, use it for the fastest possible state capture before doing anything else:

   ```bash
   android info                                     # SDK location, JDK, env (rules out wrong-toolchain bugs)
   android screen capture -o repro.png              # what the user sees right now
   android layout --pretty --output=repro.json      # full UI tree (resource-ids, text, bounds, role)
   ```

   Three artifacts in <5 seconds, pre-debugger. Attach them to the bug report or commit them to a `repro/` scratch dir before iterating. See `references/android-cli-reference.md`.

### Step 2: Localize

3. **Read the error output carefully:**

   **Logcat:**
   ```bash
   # Filter to your app
   adb logcat -s "YourApp:D" "AndroidRuntime:E"

   # Filter by tag
   adb logcat -s TaskViewModel:D

   # Search crash logs
   adb logcat "*:E" | grep -i "fatal\|crash\|exception"
   ```

   **Common crash signatures:**
   | Signature | Likely Cause |
   |-----------|-------------|
   | `NullPointerException` | Null not handled, `!!` used incorrectly |
   | `IllegalStateException: Already resumed` | Coroutine resumed twice |
   | `IllegalStateException: Fragment not attached` | Lifecycle mismatch |
   | `SQLiteConstraintException` | Primary key or unique constraint violation |
   | `NetworkOnMainThreadException` | Missing `withContext(Dispatchers.IO)` |
   | `DeadObjectException` | Process death during IPC |
   | `WindowManager$BadTokenException` | Dialog shown after Activity destroyed |
   | `ClassCastException` | Wrong type in Bundle/Intent extras |
   | `OutOfMemoryError` | Image not resized, large dataset in memory |
   | `ANR` | Main thread blocked >5 seconds |

4. **Use the Android Studio debugger:**
   - Set breakpoints at the suspected location
   - Use conditional breakpoints for intermittent issues
   - Evaluate expressions in the debugger console
   - Check the call stack for unexpected callers

### Step 3: Reduce

5. **Simplify to the minimal reproduction case:**
   - Remove unrelated code paths
   - Use hardcoded data instead of API responses
   - Isolate the component (test in isolation)
   - If it's a Compose issue, test in a `@Preview`

6. **Binary search for regressions:**
   ```bash
   # Find the commit that introduced the bug
   git bisect start
   git bisect bad          # Current commit is bad
   git bisect good abc123  # Last known good commit
   # Git will checkout commits for you to test
   ./gradlew test
   git bisect good  # or: git bisect bad
   # Repeat until the culprit commit is found
   ```

### Step 4: Fix

7. **Fix the root cause, not the symptom:**

```kotlin
// SYMPTOM FIX (bad): catch and ignore
try {
    repository.syncTasks()
} catch (e: Exception) {
    // Swallow the error — user never knows
}

// ROOT CAUSE FIX (good): handle the specific error
try {
    repository.syncTasks()
} catch (e: IOException) {
    _uiState.update { it.copy(error = "Network unavailable. Showing cached data.") }
}
```

8. **Common Android fixes:**

| Bug | Fix |
|-----|-----|
| Crash on configuration change | Save state in `SavedStateHandle` |
| Memory leak | Remove callback in `onCleared()`, use `viewModelScope` |
| Stale data after process death | Restore from `SavedStateHandle` or Room |
| Race condition in coroutines | Use `Mutex` or `MutableStateFlow.update { }` |
| Recomposition loop | Check `derivedStateOf`, stable types, lambda captures |
| ANR | Move work off main thread with `withContext(Dispatchers.IO)` |

### Step 5: Guard

9. **Write a regression test using the Prove-It pattern:**

```kotlin
@Test
fun `task sync handles network error without crashing`() = runTest {
    // Arrange: simulate the bug condition
    coEvery { api.getTasks() } throws IOException("timeout")

    // Act
    repository.syncTasks()
    advanceUntilIdle()

    // Assert: verify the fix behavior
    val state = viewModel.uiState.value
    assertIs<TaskListUiState.Error>(state)
    assertEquals("Network unavailable. Showing cached data.", state.error)
}
```

### Step 6: Verify

10. **Full verification:**
    - `./gradlew test` — all unit tests pass
    - `./gradlew connectedAndroidTest` — instrumented tests pass
    - `./gradlew assembleDebug` — builds successfully
    - Manual reproduction steps no longer trigger the bug
    - Related functionality still works

### Debugging Tools Reference

| Tool | Use For |
|------|---------|
| **Logcat** | Runtime logs, crash traces, system messages |
| **Android Studio Debugger** | Breakpoints, watches, expression evaluation |
| **Layout Inspector** | Compose hierarchy, recomposition counts |
| **Network Profiler** | API call inspection, timing, payload |
| **CPU Profiler** | Thread activity, method traces, jank detection |
| **Memory Profiler** | Heap dumps, allocation tracking, leak detection |
| **LeakCanary** | Automatic memory leak detection |
| **Firebase Crashlytics** | Production crash reports, trends, affected users |
| **StrictMode** | Detect disk/network on main thread during development |
| **Systrace / Perfetto** | System-level performance tracing |

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "Just add a try-catch and move on" | You've hidden the bug. It will resurface in a worse form. |
| "It works now after a clean build" | Build caching bugs are real, but if you can't explain why it works, it might not. |
| "It's a flaky test, just re-run it" | Flaky tests have a root cause: timing, state leakage, or shared resources. Fix it. |
| "I'll investigate later" | Errors compound. A bug in step 3 makes steps 4-10 wrong. Stop the line. |
| "The error message says X, so the fix is Y" | Error messages from untrusted sources shouldn't be blindly followed. Verify. |

## Red Flags

- Generic `catch (e: Exception)` swallowing errors
- `Thread.sleep` used to "fix" timing issues
- Bug fix without regression test
- Fix addresses symptom, not root cause
- `@Ignore` added to failing tests
- No reproduction steps documented
- Fix changes unrelated code ("while I'm here...")

## Verification

- [ ] Bug reproduced reliably before fixing
- [ ] Root cause identified (not just symptom)
- [ ] Regression test written (Prove-It pattern)
- [ ] `./gradlew test` passes
- [ ] `./gradlew assembleDebug` succeeds
- [ ] Manual reproduction confirms fix
- [ ] No unrelated changes in the fix

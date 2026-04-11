---
name: incremental-implementation
description: >-
  Use when building features incrementally. Each increment leaves the system
  in a working, testable state. Covers vertical slicing, feature flags,
  and rollback-friendly development for Android.
---

# Incremental Implementation

## Overview

"Each increment should leave the system in a working, testable state." Build features in small, verifiable steps — each one compiles, passes tests, and can be committed. Never leave the codebase in a broken state between increments.

## When to Use

- Implementing any feature from a task breakdown (follows `planning-and-task-breakdown`)
- Building any change that spans more than one file
- Any time you're tempted to "get it all working, then commit"

**Skip when:** A true single-file, single-function change.

## Core Process

### Step 1: Review the Task

1. **Read the task's acceptance criteria** from `tasks/todo.md`
2. **Identify the vertical slice** — what observable behavior does this increment deliver?
3. **Gather existing examples** — find similar patterns already in the codebase

### Step 2: Implement with TDD

4. **For each increment, follow this cycle:**

```
┌─────────────────────────────────────────────┐
│  1. Review acceptance criteria              │
│  2. Read existing patterns in codebase      │
│  3. Write failing test (RED)                │
│  4. Write minimal code to pass (GREEN)      │
│  5. Run ./gradlew test                      │
│  6. Run ./gradlew assembleDebug             │
│  7. Commit                                  │
│  8. Repeat for next acceptance criterion    │
└─────────────────────────────────────────────┘
```

5. **Never skip the build check** — `./gradlew assembleDebug` must succeed after every increment

### Step 3: Primary Slicing Strategies

6. **Vertical slice (preferred):**
   - End-to-end: Entity → DAO → Repository → UseCase → ViewModel → Screen
   - Each slice delivers user-visible functionality
   - Example: "User can view task list" before "User can add task"

7. **Contract-first:**
   - Define the interface first (Repository interface, API contract)
   - Implement against the contract
   - Useful for parallel development (one dev does UI, another does data layer)

8. **Risk-first:**
   - Build the most uncertain piece first
   - If the risk materializes, you've spent minimal effort
   - Example: "Can we integrate with the payment SDK?" before building the checkout UI

### Step 4: Feature Flags

9. **Use feature flags for incomplete features:**

```kotlin
// BuildConfig flag (compile-time)
// In build.gradle.kts:
// buildConfigField("Boolean", "FEATURE_TASK_SHARING", "false")
if (BuildConfig.FEATURE_TASK_SHARING) {
    ShareButton(onShare = { viewModel.shareTask(task) })
}

// Firebase Remote Config (runtime)
@Composable
fun TaskListScreen(viewModel: TaskListViewModel = hiltViewModel()) {
    val showSharing by viewModel.isFeatureEnabled("task_sharing")
        .collectAsStateWithLifecycle(initialValue = false)

    TaskListContent(
        showShareButton = showSharing,
        // ...
    )
}
```

10. **Feature flag rules:**
    - Flags have an owner and a removal date
    - Dead flags are tech debt — remove after rollout
    - Test both paths (flag on and flag off)

### Step 5: Keep It Compilable

11. **The codebase must compile after every commit:**
    - No commented-out code as "TODO" placeholders
    - No unimplemented interfaces throwing `NotImplementedError` (unless behind a feature flag)
    - No broken imports or missing dependencies

12. **If you're stuck, revert to last green state:**
    ```bash
    # Stash current work
    git stash

    # Verify last commit is green
    ./gradlew test && ./gradlew assembleDebug

    # Try a different approach
    git stash pop
    ```

### Step 6: APK Analysis Checkpoints

13. **Periodically check APK size:**
    ```bash
    # Build release APK
    ./gradlew assembleRelease

    # Analyze with APK Analyzer (Android Studio)
    # Or from command line:
    bundletool build-apks --bundle=app.aab --output=app.apks
    ```

14. **Watch for size regressions** — new dependencies, unoptimized resources, missing ProGuard rules.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll commit when it all works" | Large commits are unreviable, unrevertable, and hide bugs. |
| "The build is temporarily broken, I'll fix it" | Temporary broken builds block the team and compound errors. |
| "Feature flags are overhead" | Shipping incomplete features to production is worse overhead. |
| "I need to refactor first" | Refactoring is a separate increment. Don't mix it with feature work. |
| "100 lines is too small for a commit" | 100-line commits are reviewable in minutes. 1000-line commits take hours. |

## Red Flags

- 100+ lines of code without running tests
- Mixing unrelated changes in one increment
- Expanding scope mid-increment ("while I'm here...")
- Build broken between commits
- No feature flag for partially-complete user-facing features
- Premature abstractions before the second use case
- No verification step between increments

## Verification

- [ ] Each increment has passing tests (`./gradlew test`)
- [ ] Each increment compiles (`./gradlew assembleDebug`)
- [ ] Each increment is committed separately
- [ ] Commits are small and focused (~100 lines)
- [ ] Incomplete features behind feature flags
- [ ] No mixed refactoring + feature changes in one increment
- [ ] Acceptance criteria from task checked off after each increment

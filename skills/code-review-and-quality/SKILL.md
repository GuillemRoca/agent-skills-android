---
name: code-review-and-quality
description: >-
  Use when reviewing Android code (own or others'). Five-axis review
  framework: Correctness, Readability, Architecture, Security, Performance.
  Categorized findings with Kotlin/Compose-specific checks.
---

# Code Review and Quality

## Overview

Review code across five axes: Correctness, Readability, Architecture, Security, and Performance. The approval standard: "Approve when it definitely improves overall code health of the system." Every finding is categorized and actionable.

## When to Use

- Reviewing a pull request (own or teammate's)
- Self-review before creating a PR
- Requested code quality check on a specific file or module
- After completing a feature (final quality gate)

**Skip when:** Not reviewing code (this is a review skill, not a writing skill).

## Core Process

### Step 1: Understand Context

1. **Read the PR description** — what problem does it solve?
2. **Read the spec or ticket** — does the PR match the stated goal?
3. **Check the diff size** — target ~100 lines, flag >1000 lines for splitting

### Step 2: Review Tests First

4. **Start with test files** — they reveal the intended behavior
5. **Check for:**
   - Are critical paths tested?
   - Are edge cases covered (null, empty, error, boundary values)?
   - Do test names describe behavior?
   - Are tests independent (no shared mutable state)?

### Step 3: Five-Axis Review

#### Axis 1: Correctness

6. **Verify behavior matches intent:**
   - Does the code handle all states? (loading, success, error, empty)
   - Are nulls handled safely? (no `!!`, proper `?.` chains)
   - Are coroutines structured correctly? (proper scope, cancellation)
   - Are lifecycle-aware collections used? (`collectAsStateWithLifecycle`)
   - Do Room queries match the schema?
   - Are migrations correct and tested?

#### Axis 2: Readability

7. **Kotlin-specific readability:**

```kotlin
// GOOD: idiomatic Kotlin
val activeTask = tasks.firstOrNull { !it.completed }
    ?: return TaskListUiState.Empty

// BAD: Java-style
var activeTask: Task? = null
for (task in tasks) {
    if (!task.completed) {
        activeTask = task
        break
    }
}
if (activeTask == null) return TaskListUiState.Empty
```

8. **Check for:**
   - Clear naming (functions describe actions, variables describe content)
   - Appropriate use of `when` expressions, `let`/`also`/`apply`, extension functions
   - Functions under ~40 lines
   - Sealed classes/interfaces for exhaustive state handling
   - No nested callbacks (use coroutines)

#### Axis 3: Architecture

9. **Verify layer boundaries:**
   - UI layer only calls ViewModel (never Repository/DAO directly)
   - Domain layer has no Android dependencies
   - Data layer implements domain interfaces
   - Feature modules don't depend on each other
   - No business logic in Composables

10. **Check for:**
    - Proper use of `@Inject constructor` (not field injection)
    - `StateFlow` exposed from ViewModel (not `MutableStateFlow`)
    - Repository pattern for data access
    - Single source of truth (local DB for offline-first)

#### Axis 4: Security

11. **Check for:**
    - No hardcoded secrets, API keys, or passwords
    - Input validation for user-provided data
    - Proper intent validation (exported components)
    - No logging of sensitive data (`Log.d` with tokens, passwords)
    - Secure storage (EncryptedSharedPreferences for sensitive data)
    - See `security-and-hardening` for comprehensive checklist

#### Axis 5: Performance

12. **Check for:**
    - N+1 query patterns in Room
    - Unbounded data loading (should use Paging3 for large datasets)
    - Unnecessary recompositions in Compose (unstable parameters, lambda allocations)
    - Heavy work on main thread (use `withContext(Dispatchers.IO)`)
    - Memory leaks (Activity/Context references in singletons)
    - See `performance-optimization` for comprehensive checklist

### Step 4: Categorize Findings

13. **Use severity categories:**

| Category | Description | Action Required |
|----------|-------------|----------------|
| **Critical** | Security vulnerability, data loss, crash | Must fix before merge |
| **Important** | Missing tests, architecture violation, bug risk | Should fix before merge |
| **Suggestion** | Better Kotlin idiom, readability improvement | Optional, author's discretion |
| **Nit** | Formatting, naming preference | Optional |
| **FYI** | Context or explanation, no action needed | Informational |

14. **Format findings:**
```
**[Critical]** `TaskRepository.kt:45` — API key hardcoded in source.
Move to `local.properties` and access via `BuildConfig`.

**[Important]** `TaskListViewModel.kt:23` — Uses `GlobalScope.launch`.
Use `viewModelScope.launch` for proper lifecycle management.

**[Suggestion]** `TaskMapper.kt:12` — Could use `copy()` instead
of manual field mapping for partial updates.
```

### Step 5: Verify Build and Tests

15. **Before approving:**
    - `./gradlew test` passes
    - `./gradlew assembleDebug` builds
    - `./gradlew lint` has no new warnings
    - `./gradlew detekt` passes (if configured)

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "LGTM" without reading the code | Rubber-stamp reviews miss bugs. They also train teammates to skip reviews. |
| "I'll clean it up later" | Later never comes. Fix it now or create a tracked issue. |
| "It works, so it's fine" | Working code with poor architecture becomes non-working code during the next change. |
| "The author knows best" | Fresh eyes catch blind spots. That's the point of review. |
| "It's just a small change" | Small changes in the wrong layer create architectural debt. |

## Red Flags

- PR over 1000 lines without justification
- No tests in the PR
- Tests that only cover happy path
- `!!` (non-null assertion) without justification
- `GlobalScope` usage
- Mutable state exposed from ViewModel
- Business logic in Composables
- Feature module depending on another feature module
- Secrets or API keys in source code
- `@Suppress` annotations without explanatory comments

## Verification

- [ ] All five axes reviewed (Correctness, Readability, Architecture, Security, Performance)
- [ ] Tests reviewed first (coverage, edge cases, naming)
- [ ] Findings categorized (Critical, Important, Suggestion, Nit, FYI)
- [ ] Critical findings resolved before approval
- [ ] `./gradlew test` passes
- [ ] `./gradlew assembleDebug` builds
- [ ] `./gradlew lint` clean
- [ ] PR size reasonable (~100 lines, flagged if >1000)

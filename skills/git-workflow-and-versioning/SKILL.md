---
name: git-workflow-and-versioning
description: >-
  Use when managing branches, commits, versioning, and release workflows
  for Android projects. Covers trunk-based development, atomic commits,
  versionCode/versionName, and signing configurations.
---

# Git Workflow and Versioning

## Overview

Trunk-based development: keep `main` always deployable, use short-lived feature branches (1–3 days), and make atomic commits that address one logical concern. Android versioning requires managing `versionCode` (monotonic integer for Play Store) and `versionName` (human-readable semver).

## When to Use

- Starting a new feature branch
- Making commits during development
- Preparing a release
- Managing version numbers
- Reviewing branch strategy or merge approach
- Setting up signing configurations

**Skip when:** The project has an established, documented git workflow.

## Core Process

### Step 1: Trunk-Based Development

1. **Branch strategy:**

```
main (always deployable)
  ├── feature/task-sharing      (1-3 days, then merge)
  ├── feature/dark-mode         (1-3 days, then merge)
  ├── fix/crash-on-empty-list   (hours, then merge)
  └── release/1.2.0             (cut from main, hotfixes only)
```

2. **Branch rules:**
   - `main` is always green (CI passes)
   - Feature branches are short-lived (1–3 days max)
   - Delete branches after merge
   - No long-lived feature branches — use feature flags instead
   - Release branches are cut from `main`, not from feature branches

### Step 2: Atomic Commits

3. **Each commit addresses one logical concern:**

```bash
# GOOD: atomic commits
git commit -m "$(cat <<'EOF'
Add TaskDao with CRUD operations

Room DAO for tasks table with observe, upsert, and delete operations.
Flow-based observation for reactive UI updates.
EOF
)"

git commit -m "$(cat <<'EOF'
Add TaskRepository with offline-first sync

Implements TaskRepository interface. Local Room database is the source
of truth. Remote sync via Retrofit with error handling for network
failures.
EOF
)"

# BAD: kitchen sink commit
git commit -m "Add task feature with database, API, UI, and tests"
```

4. **Commit message format:**
   - First line: imperative, under 72 characters ("Add", "Fix", "Update", "Remove")
   - Blank line
   - Body: explain *why*, not *what* (the diff shows what)
   - Reference issue numbers: `Fixes #42`

### Step 3: Change Sizing

5. **Target ~100 lines per commit:**

| Size | Lines | Review Time | Action |
|------|-------|-------------|--------|
| Small | < 50 | Minutes | Merge quickly |
| Medium | 50–200 | ~30 min | Standard review |
| Large | 200–500 | Hours | Consider splitting |
| Too Large | > 500 | Days | **Must split** |

6. **Split strategies:**
   - Refactoring separate from feature work
   - Data layer separate from UI layer
   - Tests in the same commit as the code they test (not separate)

### Step 4: Save-Point Pattern

7. **Commits as checkpoints:**

```bash
# Before risky changes:
./gradlew test && git add -A && git commit -m "Checkpoint: working state before refactor"

# Try the change...
# If it breaks:
git revert HEAD  # Undo cleanly

# If it works:
# Continue to next increment
```

### Step 5: Android Versioning

8. **Version management in `build.gradle.kts`:**

```kotlin
android {
    defaultConfig {
        // versionCode: monotonically increasing integer
        // Play Store requires each upload to have a higher versionCode
        versionCode = 12

        // versionName: human-readable semantic version
        versionName = "1.2.0"
    }
}
```

9. **Versioning strategy:**

```
versionName: MAJOR.MINOR.PATCH (semantic versioning)
  MAJOR: breaking changes, major redesign
  MINOR: new features, backward compatible
  PATCH: bug fixes, no new features

versionCode: monotonically increasing integer
  Strategy 1: Simple increment (1, 2, 3, ...)
  Strategy 2: Derived from version (10200 for 1.2.0 = major*10000 + minor*100 + patch)
  Strategy 3: Build number from CI (autoincrement)
```

10. **Automated version management:**

```kotlin
// build.gradle.kts — derive versionCode from versionName
val versionMajor = 1
val versionMinor = 2
val versionPatch = 0

android {
    defaultConfig {
        versionCode = versionMajor * 10000 + versionMinor * 100 + versionPatch
        versionName = "$versionMajor.$versionMinor.$versionPatch"
    }
}
```

### Step 6: Signing Configuration

11. **Release signing setup:**

```kotlin
// build.gradle.kts
android {
    signingConfigs {
        create("release") {
            storeFile = file(properties["KEYSTORE_PATH"] as String)
            storePassword = properties["KEYSTORE_PASSWORD"] as String
            keyAlias = properties["KEY_ALIAS"] as String
            keyPassword = properties["KEY_PASSWORD"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

```properties
# local.properties (NEVER committed)
KEYSTORE_PATH=../release.keystore
KEYSTORE_PASSWORD=secure_password
KEY_ALIAS=release
KEY_PASSWORD=secure_password
```

12. **Signing rules:**
    - Keystore file NEVER in git (store securely, backup separately)
    - Signing credentials in `local.properties` or CI secrets
    - Use Google Play App Signing for production (Google manages the upload key)
    - Debug keystore is auto-generated (don't commit it)

### Step 7: Pre-Commit Checks

13. **Before committing:**

```bash
# Verify staged changes compile and pass tests
./gradlew test && ./gradlew assembleDebug

# Check for secrets
grep -rn "password\|secret\|api_key\|token" --include="*.kt" --include="*.properties" | grep -v "local.properties" | grep -v "test"
```

### Step 8: Git Worktrees for Parallel Work

14. **Use worktrees when working on multiple features:**

```bash
# Create a worktree for a parallel task
git worktree add ../project-feature-b feature/dark-mode

# Work in the worktree independently
cd ../project-feature-b
# ... make changes, commit ...

# Clean up when done
git worktree remove ../project-feature-b
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll squash it all at the end" | Squashed commits lose context. Atomic commits are reviewable and revertable. |
| "The feature branch will only take a week" | Week-long branches drift from main and create merge conflicts. Use feature flags. |
| "versionCode doesn't matter" | Play Store rejects uploads with non-increasing versionCode. Plan the strategy early. |
| "I'll fix the commit message later" | Rewriting history after push is destructive. Write good messages the first time. |

## Red Flags

- Long-lived feature branches (> 3 days)
- Kitchen-sink commits (> 500 lines, multiple concerns)
- Commit messages that only say "fix" or "update"
- Keystore or signing credentials in git
- versionCode not monotonically increasing
- No CI check on `main` branch
- Force-push to `main`

## Verification

- [ ] Feature branches are short-lived (1–3 days)
- [ ] Commits are atomic (one logical concern each)
- [ ] Commit messages explain *why*, not *what*
- [ ] versionCode increases with every release
- [ ] Signing credentials not in git
- [ ] `main` branch always passes CI
- [ ] Pre-commit: `./gradlew test && ./gradlew assembleDebug` passes

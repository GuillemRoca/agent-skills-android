---
name: git-workflow-and-versioning
description: >-
  Use when managing branches, commits, versioning, and release workflows
  for Android projects, or when cutting a release, choosing a version bump,
  tagging, or writing a changelog. Covers trunk-based development, atomic
  commits, versionCode/versionName derived from tags, semver for library
  modules, changelogs and Play release notes, and signing configurations.
---

# Git Workflow and Versioning

## Overview

Trunk-based development: keep `main` always deployable, use short-lived feature branches (1–3 days), and make atomic commits that address one logical concern. Android versioning requires managing `versionCode` (monotonic integer for Play Store) and `versionName` (human-readable semver).

## When to Use

- Starting a new feature branch
- Making commits during development
- Preparing a release
- Managing version numbers, tagging a release, or writing a changelog / Play "What's new"
- Publishing a library module (AAR/Maven) that other code depends on
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

   For an app, MAJOR is a product call (redesign, dropped minSdk); semver is a strict contract only for published library modules (Step 6). Whatever the strategy, `versionCode` must exceed every value ever uploaded — when switching strategies, offset the new scheme above the last upload.

10. **Derive versions from the release tag, don't hand-edit them.** CI passes them as Gradle properties; local builds get safe defaults:

```kotlin
// app/build.gradle.kts
val appVersionName = providers.gradleProperty("versionName").getOrElse("0.0.0-dev")
val appVersionCode = providers.gradleProperty("versionCode").map(String::toInt).getOrElse(1)

android {
    defaultConfig {
        versionCode = appVersionCode
        versionName = appVersionName
    }
}
```

```bash
# CI job triggered by pushing tag v1.4.0
VERSION_NAME="${GITHUB_REF_NAME#v}"   # "1.4.0"
IFS=. read -r MAJOR MINOR PATCH <<< "$VERSION_NAME"
VERSION_CODE=$((MAJOR * 10000 + MINOR * 100 + PATCH))   # 10400 (Strategy 1 above)
./gradlew bundleRelease -PversionName="$VERSION_NAME" -PversionCode="$VERSION_CODE"
```

   The tag, the artifact, and the changelog can then never disagree, and two branches can't both hand-bump to the same `versionCode`.

### Step 6: Release & Versioning

11. **Tag every release** — an immutable, reproducible point in history, on the exact commit that was built:

```bash
git tag -a v1.4.0 -m "Release 1.4.0"
git push origin v1.4.0
# Hotfix: fix on main, cherry-pick to release/1.4, tag v1.4.1 there
```

12. **Keep a human changelog.** `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com) style: newest on top, grouped by `Added / Changed / Fixed / Deprecated / Removed / Security`, phrased around user impact — not dumped commit messages. Write the entry in the same PR as the change, not reconstructed at release time.

```markdown
## [1.4.0] - 2026-06-12
### Added
- Share a task list via link
### Fixed
- Recurring tasks drifting by an hour after a timezone change
```

13. **Play Store "What's new" per locale** — a short, user-facing summary per release (Play Console limits it to 500 characters per language). Keep the text in the repo so it's reviewed in the PR; the path depends on your upload tool (e.g. `distribution/whatsnew/whatsnew-en-US` for the `r0adkll/upload-google-play` GitHub Action, `src/main/play/release-notes/en-US/default.txt` for Gradle Play Publisher). Automating the upload is `ci-cd-and-automation`; rollout is `shipping-and-launch`.

14. **Published library modules (AAR/Maven) follow strict semver:** removing or changing a public signature — or behaviour consumers rely on (Hyrum's Law, see `api-and-interface-design`) — is MAJOR; additive API is MINOR; fixes are PATCH. Deprecate in a minor, remove in the next major (see `deprecation-and-migration`). Catch accidental breaks with the Kotlin binary-compatibility-validator plugin:

```kotlin
// library/build.gradle.kts
plugins {
    id("org.jetbrains.kotlinx.binary-compatibility-validator") version "<latest>"
}
```

```bash
./gradlew apiDump   # writes api/<module>.api — commit it
./gradlew apiCheck  # runs as part of ./gradlew check; fails if the public API drifted from the dump
```

   The `.api` diff is the review signal: removals or changed signatures mean MAJOR, additions only mean MINOR.

### Step 7: Signing Configuration

15. **Release signing setup:**

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

16. **Signing rules:**
    - Keystore file NEVER in git (store securely, backup separately)
    - Signing credentials in `local.properties` or CI secrets
    - Use Google Play App Signing for production (Google manages the upload key)
    - Debug keystore is auto-generated (don't commit it)

### Step 8: Pre-Commit Checks

17. **Before committing:**

```bash
# Verify staged changes compile and pass tests
./gradlew test && ./gradlew assembleDebug

# Check for secrets
grep -rn "password\|secret\|api_key\|token" --include="*.kt" --include="*.properties" | grep -v "local.properties" | grep -v "test"
```

### Step 9: Git Worktrees for Parallel Work

18. **Use worktrees when working on multiple features:**

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
| "I'll just bump versionName in build.gradle.kts" | Hand edits drift from the tag, and parallel branches collide on the same `versionCode`. Derive both from the tag/CI. |
| "It's a small library change, bump the patch" | Diff size is irrelevant; consumers' code is. If `apiCheck` shows a removed or changed signature, it's a major. |
| "The changelog is just the commit log" | Commits are for developers; the changelog and "What's new" are for users, curated by impact. |
| "We'll write the changelog at release time" | By then the impact is reconstructed from memory and half is missing. Write the entry with the change. |

## Red Flags

- Long-lived feature branches (> 3 days)
- Kitchen-sink commits (> 500 lines, multiple concerns)
- Commit messages that only say "fix" or "update"
- Keystore or signing credentials in git
- versionCode not monotonically increasing
- No CI check on `main` branch
- Force-push to `main`
- `versionName`/`versionCode` hand-edited in build files, out of sync with the release tag
- A release build with no tag, or a tag not on the commit that was built
- A library module's public API changed with no `.api` dump diff in the PR, or `apiCheck` disabled
- A breaking library change shipped under a minor or patch bump
- A release with no `CHANGELOG.md` entry, or placeholder "What's new" text

## Verification

- [ ] Feature branches are short-lived (1–3 days)
- [ ] Commits are atomic (one logical concern each)
- [ ] Commit messages explain *why*, not *what*
- [ ] versionCode increases with every release
- [ ] Signing credentials not in git
- [ ] `main` branch always passes CI
- [ ] Pre-commit: `./gradlew test && ./gradlew assembleDebug` passes

For every release:

- [ ] Release commit tagged (`git tag -a vX.Y.Z`) and the tag pushed; `versionName`/`versionCode` came from the tag/CI, not a hand edit
- [ ] `CHANGELOG.md` has a curated entry for this version, grouped by impact
- [ ] Play "What's new" text exists for every shipped locale, within the 500-character limit
- [ ] Library modules: `./gradlew apiCheck` passes; the bump matches the `.api` diff (removal/change → major, addition → minor, none → patch)

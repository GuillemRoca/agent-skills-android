---
name: deprecation-and-migration
description: >-
  Use when deprecating APIs, bumping minSdk, migrating libraries (AndroidX,
  Compose, Kotlin versions), or removing legacy code. Covers Kotlin
  @Deprecated annotation, strangler pattern, and incremental migration.
---

# Deprecation and Migration

## Overview

"Code is a liability, not an asset." Every line of code carries ongoing maintenance cost. Deprecation and migration are how you manage that liability — removing what's no longer needed and upgrading what must evolve. Hyrum's Law applies: once systems have users, simple announcements aren't enough.

## When to Use

- Bumping `minSdk` or `targetSdk`
- Migrating to a new library version (Room, Compose, Kotlin)
- Replacing deprecated Android APIs
- Removing legacy feature flags or dead code
- Migrating from XML to Compose
- Upgrading from Java to Kotlin in existing modules

**Skip when:** The code has no callers and can be deleted outright.

## Core Process

### Step 1: Decision Framework

1. **Assess before deprecating:**

| Question | Impact |
|----------|--------|
| How many callers exist? | grep/find usages to count |
| Is there a replacement ready? | Never deprecate without an alternative |
| What's the maintenance cost of keeping it? | Security risk? Build complexity? |
| What's the migration cost? | Test effort, rollback risk |
| Is there a deadline? (security, API level) | Compulsory vs advisory |

2. **Deprecation types:**
   - **Advisory:** Migration recommended but not required on a timeline
   - **Compulsory:** Hard deadline (security fix, API level requirement, Play Store policy)

### Step 2: Deprecate with Guidance

3. **Use Kotlin's `@Deprecated` with replacement:**

```kotlin
@Deprecated(
    message = "Use TaskRepository.getTasks() with Flow instead",
    replaceWith = ReplaceWith(
        expression = "getTasks()",
        imports = ["com.example.data.TaskRepository"]
    ),
    level = DeprecationLevel.WARNING  // WARNING → ERROR → HIDDEN
)
suspend fun getTaskList(): List<Task> = getTasks().first()
```

4. **Deprecation levels:**
   - `WARNING` — compile-time warning, still usable
   - `ERROR` — compile-time error, forces migration
   - `HIDDEN` — invisible in IDE, only for binary compatibility

5. **Progression:**
   ```
   Phase 1: Add @Deprecated(WARNING) + replacement guidance
   Phase 2: Migrate all internal callers
   Phase 3: Escalate to @Deprecated(ERROR)
   Phase 4: Remove (or HIDDEN for library backward compatibility)
   ```

### Step 3: minSdk and targetSdk Bumps

6. **Audit before bumping:**

```bash
# Check usage of APIs below new minSdk
./gradlew lint 2>&1 | grep -i "NewApi\|ObsoleteSdkInt"

# Find API level checks that become unnecessary
grep -rn "Build.VERSION.SDK_INT" --include="*.kt"
```

7. **Migration checklist for minSdk bump:**

```markdown
## minSdk 26 → 28 Migration

### Removed compatibility code:
- [ ] Remove `if (Build.VERSION.SDK_INT >= 26)` checks for features now always available
- [ ] Remove AppCompat workarounds for features in API 28+ baseline
- [ ] Update `@RequiresApi` annotations

### New capabilities unlocked:
- [ ] Non-SDK interface restrictions (test for reflection issues)
- [ ] Privacy changes (background location, etc.)

### Verification:
- [ ] `./gradlew lint` — no NewApi warnings below new minSdk
- [ ] `./gradlew test` — all tests pass
- [ ] Test on API 28 emulator
```

### Step 4: Library Migration

8. **Strangler pattern for large migrations:**

```kotlin
// Phase 1: Introduce adapter layer
interface ImageLoader {
    fun load(url: String, target: ImageView)
}

// Old implementation (Glide)
class GlideImageLoader @Inject constructor() : ImageLoader {
    override fun load(url: String, target: ImageView) {
        Glide.with(target).load(url).into(target)
    }
}

// Phase 2: New implementation (Coil) behind feature flag
class CoilImageLoader @Inject constructor() : ImageLoader {
    override fun load(url: String, target: ImageView) {
        target.load(url)
    }
}

// Phase 3: Gradually switch callers
// Phase 4: Remove old implementation and adapter
```

9. **Compose migration from XML:**

```kotlin
// Phase 1: New screens in Compose, old screens stay XML
// Phase 2: Compose Islands — embed Compose in XML via ComposeView
// Phase 3: Migrate screen by screen (highest-traffic first)
// Phase 4: Remove XML layouts and View-based dependencies

// ComposeView bridge pattern
class LegacyFragment : Fragment() {
    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return ComposeView(requireContext()).apply {
            setContent {
                AppTheme {
                    NewComposeScreen()
                }
            }
        }
    }
}
```

### Step 5: Kotlin Version Migration

10. **Kotlin version upgrade checklist:**

```markdown
## Kotlin X.Y → X.Z Migration

- [ ] Update `kotlin` version in `libs.versions.toml`
- [ ] Update `org.jetbrains.kotlin.plugin.compose` to the same version — since
      Kotlin 2.0 the Compose compiler ships as a Kotlin Gradle plugin versioned
      with Kotlin itself (the old Compose-compiler compatibility map is obsolete)
- [ ] Run `./gradlew build` — fix compile errors (K2 is the default compiler;
      check the K2 migration notes for stricter diagnostics)
- [ ] Check for deprecated API usage in new version
- [ ] Run `./gradlew test` — verify tests pass
- [ ] Review Kotlin migration guide for breaking changes
- [ ] Update `.editorconfig` or ktlint config if needed
```

To resolve the current compatible AGP/Kotlin/Compose versions authoritatively, use
`android studio version-lookup agp kotlin compose` when the `android` CLI and a
running Android Studio are available (see `references/android-cli-reference.md`),
instead of guessing from memory.

### Step 6: Cleanup

11. **After migration is complete:**
    - Remove deprecated code (don't leave dead code)
    - Remove feature flags used for migration
    - Remove adapter layers (strangler pattern cleanup)
    - Update documentation and ADRs
    - Verify no references remain: `grep -rn "OldClassName" --include="*.kt"`

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "We'll migrate everything at once" | Big-bang migrations are high risk. Incremental strangler is safer. |
| "Just delete it, no one uses it" | Check callers first. Hyrum's Law: someone depends on behavior you didn't intend. |
| "The deprecated code still works" | It works until the next API level bump, library update, or security patch. |
| "We'll clean up the feature flags later" | Dead flags are tech debt with runtime cost. Clean up within 2 sprints of rollout. |

## Red Flags

- `@Deprecated` without `replaceWith` guidance
- Deprecated code with no migration timeline
- Big-bang migration (everything at once)
- Zombie code: unmaintained but still used
- Feature flags older than 3 months
- minSdk bump without testing on the new minimum API level
- Deleted code that should have been deprecated first (library consumers exist)

## Verification

- [ ] Deprecated APIs have `@Deprecated` with `replaceWith`
- [ ] Deprecation level progresses: WARNING → ERROR → removal
- [ ] All internal callers migrated before escalating to ERROR
- [ ] minSdk/targetSdk bumps tested on the new minimum API level
- [ ] Strangler pattern used for large library migrations
- [ ] Migration feature flags cleaned up within 2 sprints
- [ ] Removed code verified with `grep` — no remaining references
- [ ] ADR written for significant migration decisions
- [ ] `./gradlew build` and `./gradlew test` pass after migration

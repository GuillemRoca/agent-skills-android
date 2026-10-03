---
name: deprecation-and-migration
description: >-
  Use when deprecating APIs, bumping minSdk, migrating libraries (AndroidX,
  Compose, Kotlin versions), changing an API contract or database schema,
  or removing legacy code. Covers Kotlin @Deprecated annotation, strangler
  pattern, expand/contract for API and schema changes, and incremental
  migration.
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
- Renaming/removing a field or endpoint the app consumes, or changing a Room or server schema

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

   Per-screen migration workflow: `android-skills:migrate-xml-views-to-jetpack-compose` (optional Google companion plugin, see README).

10. **Guided library upgrades** (optional Google companion plugin, see README): `android-skills:agp-9-upgrade` (AGP 9, non-KMP), `android-skills:play-billing-library-version-upgrade`, `android-skills:camerax` (Camera1/Camera2 → CameraX), `android-skills:leanback-to-compose-tv-migration`.

### Step 5: Kotlin Version Migration

11. **Kotlin version upgrade checklist:**

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

### Step 6: API Contract and Schema Changes (Expand/Contract)

Old app versions stay installed for months or years and keep calling your API — users don't all update, and you can't roll their builds back. So a server contract change can never be "change it in place and ship the app the same day". Migrate in additive phases so every app version still in the wild stays valid at every step:

```
EXPAND (server)      → SHIP (app)              → WAIT / FORCE          → CONTRACT (server)
add new field or       read new, fall back to    old-version share below   stop sending old field;
endpoint alongside     old; tolerate unknowns    threshold, or min-version later, remove app fallback
the old one                                      gate forces the upgrade
```

12. **Worked example — renaming JSON field `name` → `fullName`:**
    1. **Expand.** Server returns *both* `name` and `fullName`, and accepts both on writes. Deploy.
    2. **Ship.** App reads `fullName ?: name`. Release it as version N.
    3. **Wait or force.** Check the version distribution (Play Console statistics by app version, or your analytics) until builds below N fall under an agreed threshold — or raise a minimum supported version (remote config or a backend check) that routes older builds to a force-update screen using Play In-App Updates' immediate flow.
    4. **Contract.** Server stops sending `name`. In a *later* app release, delete the fallback.

13. **Clients must tolerate change they don't know about yet:**

```kotlin
val networkJson = Json {
    ignoreUnknownKeys = true  // server may add fields this build has never seen
    coerceInputValues = true  // unknown enum value -> the property's default
}

@Serializable
enum class AccountStatus { ACTIVE, SUSPENDED, UNKNOWN }

@Serializable
data class UserDto(
    val name: String? = null,     // old field, still sent during the window
    val fullName: String? = null, // new field
    val status: AccountStatus = AccountStatus.UNKNOWN,
) {
    val displayName: String get() = fullName ?: name.orEmpty()
}
```

   Add a unit test that decodes a payload with an extra field and an unrecognised enum value — it must not throw.

14. **Local Room schema:** migrations run on-device in one step at app upgrade, so there is no mixed-version window for the local database — a rename can be a single `Migration` or `AutoMigration`. The rules from `android-data-persistence` (Step 2) still hold: write the migration, test it with `MigrationTestHelper`, never `fallbackToDestructiveMigration()`. Two mobile twists: (a) **rollback is roll-forward** — Play rejects a lower `versionCode` and Room won't downgrade, so a "revert" build must keep the new database version (or migrate forward again); (b) **synced data** follows the API contract above, so the sync layer must accept both shapes during the window.

15. **Server-owned databases** (if your team owns the backend): same pattern — add the new column nullable, dual-write, backfill in throttled batches, switch reads, then drop the old column in its own later deploy.

### Step 7: Cleanup

16. **After migration is complete:**
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
| "Rename the field server-side; the app update ships the same day" | Old builds keep calling the API for months. Expand first; contract only once old-version share is below threshold or a min-version gate forces the upgrade. |
| "Strict JSON parsing catches server bugs" | It turns every additive server change into a crash in builds you can no longer fix. Use `ignoreUnknownKeys` and an `UNKNOWN` enum fallback; catch server bugs with contract tests. |
| "If the migration breaks, we'll roll back the release" | Play won't take a lower `versionCode` and Room won't downgrade. Rollback is a new build that keeps the new schema version. |

## Red Flags

- `@Deprecated` without `replaceWith` guidance
- Deprecated code with no migration timeline
- Big-bang migration (everything at once)
- Zombie code: unmaintained but still used
- Feature flags older than 3 months
- minSdk bump without testing on the new minimum API level
- Deleted code that should have been deprecated first (library consumers exist)
- A server field or endpoint removed/renamed while app versions that read it still have meaningful active share
- Network `Json` without `ignoreUnknownKeys`, or network enums with no `UNKNOWN` fallback
- A breaking API change with no minimum-supported-version mechanism to fall back on
- A rollback plan that lowers the Room database version

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

After an API contract or schema change:

- [ ] The change ships expand → app release → wait/force → contract; the contract step cites the old-version share (or the min-version gate) that allowed it
- [ ] A unit test decodes a payload with an unknown field and an unknown enum value without throwing
- [ ] Room schema change has a `Migration`/`AutoMigration` and a passing `MigrationTestHelper` test (`./gradlew connectedAndroidTest`), with no destructive fallback
- [ ] The rollback build keeps the current database version

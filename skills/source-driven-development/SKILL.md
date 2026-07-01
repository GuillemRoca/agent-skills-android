---
name: source-driven-development
description: >-
  Use when implementing framework-specific code (Jetpack Compose, Room,
  Hilt, Navigation, etc.). Every API usage must be backed by official
  documentation, not memory or Stack Overflow.
---

# Source-Driven Development

## Overview

Every framework-specific decision must be backed by official documentation. Don't guess at APIs, don't rely on outdated patterns, don't trust Stack Overflow answers for current behavior. Fetch the source, read it, implement from it, and cite it.

## When to Use

- Implementing any Jetpack library feature (Compose, Room, Navigation, WorkManager, etc.)
- Using Android platform APIs (permissions, intents, lifecycle)
- Configuring Gradle plugins or build system features
- Integrating third-party libraries (Retrofit, Hilt, Coil, etc.)
- Unsure about the correct API for a given Android version

**Skip when:** Using internal project code that doesn't touch framework APIs.

## Source Authority Hierarchy

| Priority | Source | Example |
|----------|--------|---------|
| 1 (highest) | Official Android docs | developer.android.com, `kb://` URIs from `android docs fetch` |
| 2 | Official library docs | Kotlin docs, Hilt docs, Retrofit docs |
| 3 | AndroidX release notes | developer.android.com/jetpack/androidx/releases |
| 4 | Official blog posts | android-developers.googleblog.com |
| 5 | Material Design docs | m3.material.io |
| 6 | Source code (AndroidX, AOSP) | cs.android.com, GitHub mirrors |
| **Never** | Stack Overflow, tutorials, AI summaries, Medium posts | — |

## Core Process

### Step 1: Detect Stack and Versions

1. **Read `build.gradle.kts`** to determine:
   - `compileSdk`, `minSdk`, `targetSdk`
   - Compose compiler version and BOM version
   - Library versions (Room, Hilt, Navigation, etc.)
   - Kotlin version

```kotlin
// Example: build.gradle.kts
android {
    compileSdk = 37   // Android 17; requires AGP 9.1.1+
    defaultConfig {
        minSdk = 26
        targetSdk = 37
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.01.00"))
    implementation("androidx.room:room-runtime:2.7.0")
}
```

### Step 2: Fetch Official Documentation

2. **Go to the source** for every framework API:
   - **Compose:** developer.android.com/develop/ui/compose
   - **Room:** developer.android.com/training/data-storage/room
   - **Hilt:** dagger.dev/hilt/
   - **Navigation:** developer.android.com/guide/navigation
   - **WorkManager:** developer.android.com/develop/background-work/persistent
   - **Kotlin:** kotlinlang.org/docs
   - **Material 3:** m3.material.io/develop/android
   - **Coroutines:** kotlinlang.org/docs/coroutines-guide.html

3. **Check version-specific docs** — APIs change between versions:
   - Room 2.7 has different migration APIs than Room 2.5
   - Compose BOM releases change APIs — check the BOM mapping for your date
   - Navigation 3 (back-stack-as-state) is a different API surface from Navigation 2.x type-safe routes

4. **Never guess versions — resolve them.** When the `android` CLI and a running Android Studio are available:

```bash
android studio version-lookup agp kotlin compose        # toolchain keywords
android studio version-lookup androidx.room:room-runtime  # Maven coordinates
```

The output is authoritative and current — accepted at priority 1 in the source hierarchy, same as `kb://` URIs. Fallback: the official release-notes pages (`developer.android.com/build/releases/gradle-plugin`, AndroidX release pages).

5. **When available, use `android docs` for cite-able URIs:**

```bash
android docs search "compose recomposition"
android docs fetch kb://android/topic/compose/performance/recomposition
```

The returned `kb://` URI is a stable citation — prefer it over a plain `developer.android.com` URL when both point to the same topic. See `references/android-cli-reference.md`.

### Step 3: Implement Matching Documented Patterns

6. **Match the official example pattern**, not your memory:

```kotlin
// Official Room pattern (verify against docs for your version)
@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "display_name") val displayName: String,
    @ColumnInfo(name = "created_at") val createdAt: Long
)

@Dao
interface UserDao {
    @Query("SELECT * FROM users WHERE id = :userId")
    suspend fun getById(userId: String): UserEntity?

    @Upsert
    suspend fun upsert(user: UserEntity)
}
```

7. **Surface conflicts** with existing code:
   - "The docs recommend `@Upsert` but the project uses `@Insert(onConflict = REPLACE)` — which should I follow?"
   - "Navigation Compose 2.8+ uses type-safe routes but the project is on 2.7 — should I upgrade or use string routes?"

### Step 4: Cite Sources

8. **Include source references** in code comments for non-obvious patterns:

```kotlin
// Using rememberLauncherForActivityResult per:
// developer.android.com/training/permissions/requesting#kotlin
val permissionLauncher = rememberLauncherForActivityResult(
    ActivityResultContracts.RequestPermission()
) { isGranted ->
    if (isGranted) onPermissionGranted()
}
```

9. **In PRs, link to documentation** that justifies the approach.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I know how this API works" | APIs change between versions. What you remember may be deprecated. |
| "Stack Overflow has the answer" | SO answers are often outdated, use deprecated APIs, or apply to different versions. |
| "The tutorial shows this pattern" | Tutorials simplify and may skip error handling, lifecycle awareness, or edge cases. |
| "I'll check docs later" | Code written from memory will have subtle bugs caught only in production. |

## Red Flags

- Framework code written without checking official docs
- "I think this is how it works" (instead of citing a source)
- Code without source citations for non-obvious patterns
- Using deprecated APIs when current alternatives exist
- Patterns that don't match the project's library versions
- Mixing patterns from different library versions

## Verification

- [ ] `build.gradle.kts` versions checked before implementation
- [ ] Official documentation consulted for every framework API used
- [ ] API patterns match the documented version (not outdated tutorials)
- [ ] Deprecated API usage flagged with migration path
- [ ] Source URLs cited in comments for non-obvious patterns (`developer.android.com/...` or `kb://...`)
- [ ] Conflicts with existing code surfaced (not silently overridden)

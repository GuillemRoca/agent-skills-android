---
name: performance-optimization
description: >-
  Use when measuring or improving Android app performance. Covers Android
  Vitals (startup, jank, ANR), Macrobenchmark, APK size, recomposition
  tracing, and profiling with Android Studio tools.
---

# Performance Optimization

## Overview

"Performance optimization without measurement is guessing." Measure first, identify bottlenecks with data, fix with targeted changes, verify the improvement, and guard against regressions. Never optimize based on assumptions.

## When to Use

- App startup exceeds 500ms (cold) or 200ms (warm)
- UI jank (dropped frames, janky scrolling)
- ANR (Application Not Responding) reports
- APK/AAB size exceeds budget
- Before a release (performance regression check)
- Users report slowness or battery drain

**Skip when:** No performance issue is observed or measured.

## Android Vitals Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Cold startup | < 500ms | > 1s |
| Warm startup | < 200ms | > 500ms |
| Frame rendering (jank) | < 5% slow frames | > 10% slow frames |
| ANR rate | < 0.47% | > 1% |
| APK size (compressed) | < 10MB | > 50MB |
| Memory usage | < 150MB typical | > 256MB |

## Core Process

### Step 1: Measure

1. **Baseline Profiles (startup and scrolling):**

```kotlin
// benchmark/src/main/java/BaselineProfileGenerator.kt
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {
    @get:Rule
    val rule = BaselineProfileRule()

    @Test
    fun generateBaselineProfile() {
        rule.collect(packageName = "com.example.app") {
            // Cold start
            pressHome()
            startActivityAndWait()

            // Critical user journeys
            device.findObject(By.text("Tasks")).click()
            device.waitForIdle()

            // Scroll the list
            val list = device.findObject(By.res("task_list"))
            list.setGestureMargin(device.displayWidth / 5)
            list.fling(Direction.DOWN)
            device.waitForIdle()
        }
    }
}
```

2. **Macrobenchmark (startup timing):**

```kotlin
@RunWith(AndroidJUnit4::class)
class StartupBenchmark {
    @get:Rule
    val rule = MacrobenchmarkRule()

    @Test
    fun coldStartup() {
        rule.measureRepeated(
            packageName = "com.example.app",
            metrics = listOf(StartupTimingMetric()),
            startupMode = StartupMode.COLD,
            iterations = 5,
        ) {
            pressHome()
            startActivityAndWait()
        }
    }
}
```

3. **Android Studio Profiler:**
   - **CPU Profiler:** Record method traces, identify hot methods
   - **Memory Profiler:** Track allocations, find leaks, heap dumps
   - **Network Profiler:** Inspect API calls, timing, payload sizes
   - **Energy Profiler:** CPU, network, and GPS wake lock usage

### Step 2: Identify Bottlenecks

4. **Common performance anti-patterns:**

| Anti-Pattern | Impact | Fix |
|-------------|--------|-----|
| N+1 queries in Room | Slow list loading | Use `@Transaction` with `@Relation` or single JOIN query |
| Unbounded data fetch | OOM, slow rendering | Paging3 |
| Large images unscaled | Memory pressure, OOM | Coil/Glide with size constraints |
| Work on main thread | ANR, jank | `withContext(Dispatchers.IO)` |
| Unnecessary recomposition | Jank in Compose | Stable types, `key()`, `derivedStateOf` |
| Large APK | Slow downloads | R8, resource shrinking, dynamic delivery |
| Missing Baseline Profiles | Slow cold start | Generate and include profiles |
| Unoptimized imports | Slow build, large APK | Only import what's needed |
| Synchronous initialization | Slow startup | `App Startup` library, lazy init |

### Step 3: Fix

5. **Startup optimization:**

```kotlin
// Use App Startup library for lazy initialization
class AnalyticsInitializer : Initializer<Analytics> {
    override fun create(context: Context): Analytics {
        return Analytics.init(context)
    }
    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}

// Defer non-critical work
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Critical path only — show UI immediately
        setContent { AppTheme { AppNavigation() } }

        // Defer non-critical initialization
        lifecycleScope.launch {
            lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                initializeAnalytics()
                prefetchUserData()
            }
        }
    }
}
```

6. **Compose recomposition optimization:**

```kotlin
// Use key() for list items
LazyColumn {
    items(tasks, key = { it.id }) { task ->
        TaskItem(task = task)
    }
}

// Use derivedStateOf for computed values
val showScrollToTop by remember {
    derivedStateOf { listState.firstVisibleItemIndex > 5 }
}

// Use ImmutableList for stable parameters
@Composable
fun TaskList(
    tasks: ImmutableList<Task>, // from kotlinx.collections.immutable
    onToggle: (String) -> Unit,
)

// Avoid lambda allocations in loops
items(tasks, key = { it.id }) { task ->
    // BAD: new lambda per recomposition
    TaskItem(onToggle = { viewModel.toggle(task.id) })
    // GOOD: method reference
    TaskItem(onToggle = viewModel::toggleTask)
}
```

7. **APK size reduction:**

```kotlin
// build.gradle.kts
android {
    buildTypes {
        release {
            isMinifyEnabled = true     // R8 code shrinking
            isShrinkResources = true   // Remove unused resources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Use WebP for images, vector drawables where possible
// Use dynamic feature modules for large optional features
// Analyze APK: Build → Analyze APK in Android Studio
```

8. **Image loading optimization:**

```kotlin
// Coil with size constraints — request only the pixels you render.
// Size.ORIGINAL decodes the full bitmap and defeats the point.
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(task.imageUrl)
        .size(200, 200)  // match the display size; never Size.ORIGINAL for thumbnails
        .crossfade(true)
        .build(),
    contentDescription = task.title,
    modifier = Modifier.size(64.dp),
)
```

### Step 4: Verify

9. **Confirm improvement with measurements:**
   - Re-run Macrobenchmark — compare before/after
   - Check frame metrics in Android Studio Profiler
   - Verify APK size: `./gradlew assembleRelease` → Analyze APK
   - Run on lower-end devices (not just your development device)

### Step 5: Guard

10. **Prevent regressions:**
    - Baseline Profiles generated in CI
    - Macrobenchmark tests run on pre-release builds
    - APK size budget checked in CI
    - Performance monitoring in production (Firebase Performance)

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "It's fast on my Pixel 8" | Your flagship device is not your users' device. Test on low-end hardware. |
| "We'll optimize later" | Performance debt compounds. Fixing later costs 10x more. |
| "The profiler shows it's fine" | Profiling in debug mode hides R8 optimizations and ART compilation. Profile release builds. |
| "Only 5% of users hit this" | 5% of 1M users is 50,000 people. Every percentage matters. |

## Red Flags

- No Baseline Profiles
- No Macrobenchmark tests
- APK size growing without tracking
- `Thread.sleep` or busy-wait patterns
- Unbounded list loading (no Paging3)
- Heavy computation on main thread
- Images loaded at full resolution
- Profiling only done on debug builds

## Verification

- [ ] Startup time measured (cold and warm)
- [ ] Frame rendering metrics checked (slow frames < 5%)
- [ ] APK size within budget
- [ ] Baseline Profiles generated and included
- [ ] No N+1 query patterns
- [ ] Images loaded with proper sizing
- [ ] Heavy work off main thread
- [ ] Macrobenchmark tests guard critical paths
- [ ] Performance tested on low-end devices

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
   - For agent-driven capture and Perfetto trace analysis, see `android-skills:android-profiler` (optional Google companion plugin, see README)

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

   To audit keep rules for redundant or overly broad entries, see `android-skills:r8-analyzer` (optional Google companion plugin, see README).

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

### Step 4: Verify (Keep or Revert)

A fix is a hypothesis until you re-measure. This step decides whether it survives.

9. **Re-measure the way you measured the baseline:** same Macrobenchmark module and `iterations`, same `CompilationMode`, same device, same build type (release/benchmark), same `StartupMode`. A cold-start baseline compared against a warm-start result measures the start mode, not your change.
   - Startup and frames: re-run Macrobenchmark and compare median *and* spread
   - APK/AAB size: `./gradlew bundleRelease` and compare against the baseline artifact
   - Run on lower-end devices, not just your development device
10. **Change one thing at a time.** Three optimizations landed together produce one number you can't attribute. If they must ship together, measure each in isolation first.
11. **Beat the noise, not just the mean.** Compare the delta against run-to-run variance across iterations. A 20ms startup gain inside ±40ms variance is a different sample, not a gain.
12. **Then decide, strictly:**

| Result vs. baseline | Action |
|---|---|
| Past the threshold, tests green | **Keep.** Commit with the before/after numbers in the message |
| Within noise | **Revert** |
| Worse | **Revert** |
| Improved, but a test went red | **Revert** — a regression wearing a win's clothing |

"Neutral" is a revert, not a keep: code you keep, you maintain forever. Correctness gates the metric — an "optimization" that wins by dropping work the product needed (skipping validation, caching data that must be fresh, moving required init off the startup path so it races) is a regression.

13. **Log every attempt, including reverted ones.** Reverted work leaves no trace in git, which is why the same dead idea comes back next quarter. Keep a short ledger in the PR description or a `PERF.md`:

| Idea | Baseline → Result | Verdict | Why |
|---|---|---|---|
| `remember` the row's formatted date | 6.1% → 6.0% slow frames | reverted | Inside noise; rows weren't the bottleneck |
| Stable keys + `contentType` in `LazyColumn` | 6.1% → 1.8% slow frames | kept | Recompositions per scroll dropped 10x |
| Lazy-init analytics SDK via App Startup | TTID 820ms → 815ms | reverted | Init was already off the main thread |

### Step 5: Guard

14. **Prevent regressions:**
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
| "It didn't help much, but it doesn't hurt" | Neutral changes are a revert. You maintain them forever and got nothing back. |
| "We already wrote it, may as well keep it" | Sunk cost. The measurement doesn't care how long the change took. |
| "The improvement is obvious, no need to re-measure" | Then re-measuring is cheap and proves it. Unmeasured wins are how neutral complexity lands. |

## Red Flags

- No Baseline Profiles
- No Macrobenchmark tests
- APK size growing without tracking
- `Thread.sleep` or busy-wait patterns
- Unbounded list loading (no Paging3)
- Heavy computation on main thread
- Images loaded at full resolution
- Profiling only done on debug builds
- Optimizations kept without a re-measurement that justifies them
- Several optimizations bundled into one measurement
- A "win" that required a test to be changed, skipped, or deleted
- The same failed optimization tried again because nobody recorded the first attempt

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
- [ ] Each change re-measured the same way as the baseline, and the delta exceeds run-to-run variance
- [ ] Changes that didn't beat the baseline were reverted, and every attempt (kept or reverted) is logged

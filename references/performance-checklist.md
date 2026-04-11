# Performance Checklist — Android Reference

## Android Vitals Targets

| Metric | Good | Needs Work | Critical |
|--------|------|-----------|----------|
| Cold startup | < 500ms | 500ms–1s | > 1s |
| Warm startup | < 200ms | 200ms–500ms | > 500ms |
| Slow frame rate | < 5% | 5%–10% | > 10% |
| Frozen frames | < 1% | 1%–3% | > 3% |
| ANR rate | < 0.47% | 0.47%–1% | > 1% |
| Crash rate | < 1.09% | 1.09%–2% | > 2% |

## Startup Optimization

- [ ] **Baseline Profiles** generated and included in release builds
- [ ] **App Startup library** used for lazy initialization
- [ ] **Non-critical initialization** deferred to after first frame:

```kotlin
// Defer analytics, pre-fetching, etc.
lifecycleScope.launch {
    lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
        deferredInit()
    }
}
```

- [ ] **Splash screen** using `SplashScreen` API (not custom Activity)
- [ ] **Content provider initialization** minimized (auto-init libraries)
- [ ] **Trace startup** with Perfetto or `Debug.startMethodTracing()`

## Rendering & Compose Performance

- [ ] **Stable types** for Compose parameters (data classes, `@Stable` annotation)
- [ ] **`ImmutableList`** from kotlinx.collections.immutable for list parameters
- [ ] **`key()` parameter** on `LazyColumn` / `LazyRow` items
- [ ] **`derivedStateOf`** for computed values to reduce recompositions
- [ ] **Method references** over inline lambdas in loops where possible
- [ ] **Recomposition counts** checked in Layout Inspector
- [ ] **No heavy computation** in composition (move to ViewModel/UseCase)

```kotlin
// Check recomposition with Layout Inspector or:
@Composable
fun TaskList(tasks: ImmutableList<Task>) {
    LazyColumn {
        items(tasks, key = { it.id }) { task ->
            TaskItem(task = task)
        }
    }
}
```

## Memory Management

- [ ] **No Activity/Context leaks** (check with LeakCanary)
- [ ] **Large bitmaps** loaded with proper sampling:

```kotlin
// Coil handles this automatically
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(url)
        .size(Size(200, 200)) // Don't load full resolution
        .crossfade(true)
        .memoryCachePolicy(CachePolicy.ENABLED)
        .build(),
    contentDescription = "...",
)
```

- [ ] **Large datasets** paginated with Paging3 (not loaded into memory)
- [ ] **Coroutine scopes** properly scoped (no GlobalScope)
- [ ] **Listeners/callbacks** unregistered in `onCleared()` or `DisposableEffect`
- [ ] **`onTrimMemory`** handled for background memory pressure

## Network Efficiency

- [ ] **API responses** paginated (not unbounded)
- [ ] **Caching** headers respected (OkHttp cache)
- [ ] **Compression** enabled (gzip)
- [ ] **Batch requests** where possible (reduce connection count)
- [ ] **Image CDN** with resizing parameters (request device-appropriate sizes)
- [ ] **Offline-first** — read from cache, sync in background

## Database Performance

- [ ] **No N+1 queries** — use `@Transaction` with `@Relation` or JOINs
- [ ] **Indices** on frequently queried columns:

```kotlin
@Entity(
    tableName = "tasks",
    indices = [
        Index(value = ["created_at"]),
        Index(value = ["completed", "created_at"]),
    ]
)
```

- [ ] **Queries return only needed columns** (no `SELECT *` for large tables)
- [ ] **Room queries** profiled (enable query logging in debug)
- [ ] **Transactions** for batch operations (`@Transaction` annotation)
- [ ] **Write-ahead logging** (WAL) enabled (Room default)

## APK / AAB Size

- [ ] **R8 / ProGuard** enabled for release
- [ ] **Resource shrinking** enabled (`isShrinkResources = true`)
- [ ] **WebP** format for images (smaller than PNG/JPEG)
- [ ] **Vector drawables** for icons (instead of multiple PNG densities)
- [ ] **Dynamic feature modules** for large optional features
- [ ] **APK Analyzer** reviewed (Build → Analyze APK):
  - `classes.dex` — identify large dependencies
  - `res/` — identify large resources
  - `lib/` — native libraries per ABI
- [ ] **ABI splits** or App Bundle for native libraries
- [ ] **Unused resources** removed (Lint `UnusedResources` check)

## Background Work

- [ ] **WorkManager** for deferrable background work (not AlarmManager/JobScheduler)
- [ ] **Constraints** specified on WorkRequests (network, charging, idle)
- [ ] **Foreground Services** only for user-visible tasks (with notification)
- [ ] **Battery optimization** — respect Doze mode and app standby
- [ ] **No wake locks** held unnecessarily

## Profiling Tools

| Tool | Use For | When |
|------|---------|------|
| **Android Studio CPU Profiler** | Method traces, thread activity | Jank, slow operations |
| **Android Studio Memory Profiler** | Heap dumps, allocation tracking | Memory leaks, OOM |
| **Network Profiler** | API calls, payload sizes | Network optimization |
| **LeakCanary** | Automatic leak detection | Development builds |
| **Macrobenchmark** | Startup, scroll, animation timing | CI regression testing |
| **Baseline Profile Generator** | AOT compilation optimization | Release builds |
| **Perfetto** | System-level traces | Deep performance analysis |
| **APK Analyzer** | Size breakdown | Before release |
| **Layout Inspector** | Recomposition counts, UI hierarchy | Compose optimization |
| **Firebase Performance** | Production monitoring | Post-release |

## Anti-Patterns

| Anti-Pattern | Impact | Fix |
|-------------|--------|-----|
| Loading images at full resolution | OOM, high memory | Use Coil/Glide with size constraints |
| N+1 database queries | Slow list loading | JOIN queries or `@Relation` |
| Main thread disk/network I/O | ANR | `withContext(Dispatchers.IO)` |
| Unbounded RecyclerView/LazyColumn data | OOM, slow render | Paging3 |
| GlobalScope.launch | Leaked coroutines | viewModelScope or structured scope |
| Missing Baseline Profiles | Slow cold start | Generate profiles in CI |
| Synchronous initialization in Application.onCreate | Slow startup | Defer with App Startup library |
| Large JSON parsing on main thread | Jank | Parse on IO dispatcher |

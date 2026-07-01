---
name: android-ui-engineering
description: >-
  Use when building UI with Jetpack Compose. Covers component design,
  state hoisting, recomposition optimization, Material 3 theming,
  Navigation 3, adaptive layouts for large screens, previews,
  screenshot verification, and XML interop.
---

# Android UI Engineering

## Overview

Build production-quality Android UI with Jetpack Compose. This skill covers component architecture, state management, Material 3 theming, navigation, performance optimization (recomposition), accessibility, and interoperability with legacy XML views.

## When to Use

- Building new screens or UI components with Compose
- Refactoring XML layouts to Compose
- Debugging recomposition or performance issues in Compose
- Implementing Material 3 design system
- Setting up navigation between screens
- Adapting layouts for tablets, foldables, and desktop windows

**Skip when:** Modifying non-UI code (repositories, use cases, data layer).

## Core Process

### Step 1: Component Architecture

1. **Stateless composables with state hoisting:**

```kotlin
// Stateless — reusable, testable, previewable
@Composable
fun TaskItem(
    task: Task,
    onToggle: (String) -> Unit,
    onDelete: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    ListItem(
        headlineContent = { Text(task.title) },
        leadingContent = {
            Checkbox(
                checked = task.completed,
                onCheckedChange = { onToggle(task.id) }
            )
        },
        trailingContent = {
            IconButton(onClick = { onDelete(task.id) }) {
                Icon(Icons.Default.Delete, contentDescription = "Delete task")
            }
        },
        modifier = modifier,
    )
}

// Stateful wrapper — connects to ViewModel
@Composable
fun TaskListScreen(
    viewModel: TaskListViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    TaskListContent(
        uiState = uiState,
        onToggle = viewModel::toggleTask,
        onDelete = viewModel::deleteTask,
    )
}
```

2. **Component rules:**
   - **Single responsibility** — one composable does one thing
   - **Accept `Modifier` parameter** — always last with default `Modifier`
   - **Hoist state** — push state up, push events down
   - **Stateless by default** — only use `remember` when necessary
   - **Composition over configuration** — slots and lambdas over boolean flags

### Step 2: State Management in Compose

3. **Collect state lifecycle-aware:**

```kotlin
// Always use collectAsStateWithLifecycle (not collectAsState)
val uiState by viewModel.uiState.collectAsStateWithLifecycle()
```

4. **Handle all states:**

```kotlin
@Composable
fun TaskListContent(
    uiState: TaskListUiState,
    onToggle: (String) -> Unit,
    onDelete: (String) -> Unit,
) {
    when (uiState) {
        is TaskListUiState.Loading -> LoadingIndicator()
        is TaskListUiState.Success -> {
            if (uiState.tasks.isEmpty()) {
                EmptyState(message = "No tasks yet")
            } else {
                TaskList(
                    tasks = uiState.tasks,
                    onToggle = onToggle,
                    onDelete = onDelete,
                )
            }
        }
        is TaskListUiState.Error -> ErrorState(
            message = uiState.message,
            onRetry = { /* trigger refresh */ },
        )
    }
}
```

### Step 3: Material 3 Theming

5. **Set up the theme:**

```kotlin
@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context)
            else dynamicLightColorScheme(context)
        }
        darkTheme -> darkColorScheme()
        else -> lightColorScheme()
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        content = content,
    )
}
```

6. **Use Material tokens, not hardcoded values:**

```kotlin
// GOOD: uses theme tokens
Text(
    text = "Title",
    style = MaterialTheme.typography.headlineMedium,
    color = MaterialTheme.colorScheme.onSurface,
)

// BAD: hardcoded values
Text(
    text = "Title",
    fontSize = 24.sp,
    color = Color(0xFF000000),
)
```

### Step 4: Navigation (Navigation 3)

Use **Navigation 3** (`androidx.navigation3:navigation3-runtime` + `navigation3-ui`, stable) for new Compose apps. The back stack is state you own — no opaque `NavController`.

7. **Navigation 3 setup:**

```kotlin
// Routes are serializable Kotlin types — compile-time safe, no route strings
@Serializable data object TaskList : NavKey
@Serializable data class TaskDetail(val taskId: String) : NavKey

@Composable
fun AppNavigation(modifier: Modifier = Modifier) {
    val backStack = rememberNavBackStack(TaskList)

    NavDisplay(
        backStack = backStack,
        onBack = { backStack.removeLastOrNull() },
        entryProvider = entryProvider {
            entry<TaskList> {
                TaskListScreen(
                    onNavigateToDetail = { taskId -> backStack.add(TaskDetail(taskId)) },
                )
            }
            entry<TaskDetail> { key ->
                TaskDetailScreen(
                    taskId = key.taskId,
                    onNavigateBack = { backStack.removeLastOrNull() },
                )
            }
        },
        modifier = modifier,
    )
}
```

8. **Navigation rules:**
   - The back stack (`rememberNavBackStack`) lives in the navigation host; navigate by mutating it (`add`, `removeLastOrNull`) — it is a `SnapshotStateList`, so `NavDisplay` reacts automatically
   - Screens receive navigation callbacks (`onNavigateToDetail`), never the back stack itself
   - Routes are `@Serializable` types, not strings — arguments are constructor parameters
   - Multi-pane layouts use Nav3 **Scenes** via `androidx.compose.material3.adaptive:adaptive-navigation3` (see Step 5) — two destinations can be visible at once, no dual-NavHost workarounds
   - Existing apps on Navigation 2: stay on type-safe routes (`@Serializable` destinations, Nav 2.8+) and migrate with the official Nav2→Nav3 guide (`developer.android.com/guide/navigation/navigation-3/migration-guide`) — see `deprecation-and-migration`
   - **Deep links:** verify HTTPS App Links with `assetlinks.json` + `android:autoVerify="true"`; validate every parameter of an inbound link before acting on it (see `security-and-hardening`)

### Step 5: Adaptive Layouts

9. **Drive layout off window size classes — never orientation or device type.** Targeting API 37, this stops being optional: `screenOrientation`/`resizeableActivity` restrictions are ignored on displays ≥600dp, with no opt-out. Portrait-only apps get letterboxed into windows they never designed for.

```kotlin
// WindowSizeClass with the V2 breakpoints (adds Large ≥1200dp, Extra-large)
val windowSizeClass = currentWindowAdaptiveInfo().windowSizeClass
val useTwoPane = windowSizeClass.isWidthAtLeastBreakpoint(
    WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND  // 840dp
)

// Material 3 adaptive scaffolds do the switching for you:
// - NavigationSuiteScaffold: bottom bar <-> nav rail by window size
// - NavigableListDetailPaneScaffold: list+detail side by side on Expanded+
// (androidx.compose.material3.adaptive:adaptive-layout / adaptive-navigation;
//  pass supportLargeAndXLargeWidth = true to surface the Large/XL classes)
```

10. **Adaptive rules:**
    - Compact (<600dp) and Medium: single pane; Expanded (≥840dp) and up: multi-pane via `ListDetailPaneScaffold`/`SupportingPaneScaffold`
    - Edge-to-edge is the default (enforced targeting Android 15+): call `enableEdgeToEdge()`, consume `WindowInsets` in scaffolds, never rely on `statusBarColor`
    - Predictive back: use `PredictiveBackHandler`/`OnBackPressedDispatcher` — never override `onBackPressed()` (default-on targeting 36+)
    - State survives size changes: `ViewModel` + `rememberSaveable`, not `configChanges` hacks

### Step 6: Recomposition Optimization

11. **Avoid unnecessary recompositions:**

```kotlin
// Use stable types for state (data classes, immutable collections)
// Avoid lambdas that create new instances on every recomposition
// BAD: creates new lambda each recomposition
items(tasks) { task ->
    TaskItem(onToggle = { viewModel.toggle(task.id) })
}

// GOOD: use method reference or remember
items(tasks) { task ->
    TaskItem(onToggle = viewModel::toggleTask)
}

// Use derivedStateOf for computed values
val showFab by remember {
    derivedStateOf { listState.firstVisibleItemIndex == 0 }
}

// Use key() for list items
LazyColumn {
    items(tasks, key = { it.id }) { task ->
        TaskItem(task = task)
    }
}
```

12. **Recomposition debugging:**
    - Enable recomposition counts in Layout Inspector
    - Use `@Stable` annotation for classes that Compose should treat as stable
    - Use `ImmutableList` from `kotlinx.collections.immutable` for list parameters

### Step 7: Previews — and Verify Them

13. **Write previews for every screen and component:**

```kotlin
@Preview(showBackground = true)
@Preview(showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun TaskItemPreview() {
    AppTheme {
        TaskItem(
            task = Task(id = "1", title = "Buy groceries", completed = false),
            onToggle = {},
            onDelete = {},
        )
    }
}

@Preview(showBackground = true, device = Devices.PIXEL_7)
@Composable
private fun TaskListScreenPreview() {
    AppTheme {
        TaskListContent(
            uiState = TaskListUiState.Success(
                tasks = listOf(
                    Task("1", "Buy groceries", false),
                    Task("2", "Walk the dog", true),
                )
            ),
            onToggle = {},
            onDelete = {},
        )
    }
}
```

14. **Previews are verifiable — look at what you built:**

    - **Agent-side rendering:** `android studio render-compose-preview --output-image-file=preview.png <file> <composable>` renders a `@Preview` to PNG without a device, so you can inspect the UI you just wrote instead of assuming it looks right (requires a running Android Studio with Gemini; see `references/android-cli-reference.md`)
    - **Screenshot tests:** lock previews in with Compose Preview Screenshot Testing or Roborazzi so regressions fail CI — patterns in `references/testing-patterns.md`, workflow in `android-device-testing`

### Step 8: XML Interop (Legacy)

15. **Compose in XML:**

```xml
<androidx.compose.ui.platform.ComposeView
    android:id="@+id/compose_view"
    android:layout_width="match_parent"
    android:layout_height="wrap_content" />
```

```kotlin
binding.composeView.setContent {
    AppTheme {
        TaskItem(task = task, onToggle = {}, onDelete = {})
    }
}
```

16. **XML in Compose:**

```kotlin
@Composable
fun LegacyMapView(modifier: Modifier = Modifier) {
    AndroidView(
        factory = { context -> MapView(context).apply { onCreate(null) } },
        update = { mapView -> /* update map */ },
        modifier = modifier,
    )
}
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll add the modifier parameter later" | Every composable consumer will need to add it later. Do it now. |
| "State hoisting is overkill for this screen" | Unhoist state and you can't preview, test, or reuse the composable. |
| "I'll skip the empty/error states" | Users will see a blank screen. Handle all states. |
| "Recomposition optimization is premature" | Only premature if you haven't measured. Profile first, then decide. |
| "Previews are extra work" | Previews catch issues faster than running the app. They pay for themselves. |

## Red Flags

- Composable without `Modifier` parameter
- `collectAsState` instead of `collectAsStateWithLifecycle`
- Back stack (or a NavController) passed directly to screen composables
- String routes or new `NavHost`/`rememberNavController` code in a Nav3 app
- Layout branching on orientation or "isTablet" instead of window size class
- `android:screenOrientation="portrait"` on activities (ignored ≥600dp from API 37)
- Hardcoded colors/sizes instead of Material theme tokens
- Missing loading, empty, or error states
- No `@Preview` functions
- ViewModel instantiated inside composables (use `hiltViewModel()`)
- Mutable state in composable parameters

## Verification

- [ ] All composables accept `Modifier` parameter
- [ ] State hoisted — composables are stateless and testable
- [ ] All UI states handled (loading, success, empty, error)
- [ ] Material 3 theme tokens used (no hardcoded colors/sizes)
- [ ] Navigation callbacks passed to screens (not the back stack/NavController)
- [ ] Routes are `@Serializable` types rendered via `NavDisplay` (Navigation 3)
- [ ] Layout verified at Compact and Expanded window sizes (resizable emulator or `@Preview(device = ...)`)
- [ ] `collectAsStateWithLifecycle` used for Flow collection
- [ ] Previews exist for screens and key components — and rendered/screenshot-tested, not just written
- [ ] `./gradlew assembleDebug` builds successfully
- [ ] Layout Inspector shows reasonable recomposition counts
- [ ] On-device hierarchy inspected via `android layout --pretty` when verifying Compose output against `@Preview` (see `references/android-cli-reference.md`)

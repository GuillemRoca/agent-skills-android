---
name: android-ui-engineering
description: >-
  Use when building UI with Jetpack Compose. Covers component design,
  state hoisting, recomposition optimization, Material 3 theming,
  Navigation Compose, previews, and XML interop.
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

### Step 4: Navigation

7. **Navigation Compose setup:**

```kotlin
@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController(),
) {
    NavHost(
        navController = navController,
        startDestination = "task_list",
    ) {
        composable("task_list") {
            TaskListScreen(
                onNavigateToDetail = { taskId ->
                    navController.navigate("task_detail/$taskId")
                }
            )
        }
        composable(
            route = "task_detail/{taskId}",
            arguments = listOf(navArgument("taskId") { type = NavType.StringType }),
        ) {
            TaskDetailScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
```

8. **Navigation rules:**
   - NavController lives in the navigation host, not in screens
   - Screens receive navigation callbacks (`onNavigateToDetail`), not the NavController
   - Arguments are typed via `navArgument`
   - Deep links declared in the navigation graph

### Step 5: Recomposition Optimization

9. **Avoid unnecessary recompositions:**

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

10. **Recomposition debugging:**
    - Enable recomposition counts in Layout Inspector
    - Use `@Stable` annotation for classes that Compose should treat as stable
    - Use `ImmutableList` from `kotlinx.collections.immutable` for list parameters

### Step 6: Previews

11. **Write previews for every screen and component:**

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

### Step 7: XML Interop (Legacy)

12. **Compose in XML:**

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

13. **XML in Compose:**

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
- NavController passed directly to screen composables
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
- [ ] Navigation callbacks passed to screens (not NavController)
- [ ] `collectAsStateWithLifecycle` used for Flow collection
- [ ] Previews exist for screens and key components
- [ ] `./gradlew assembleDebug` builds successfully
- [ ] Layout Inspector shows reasonable recomposition counts

---
name: android-architecture
description: >-
  Use when designing module structure, choosing architecture patterns
  (MVVM/MVI), setting up dependency injection, or defining layer
  boundaries in an Android project.
---

# Android Architecture

## Overview

Good architecture makes Android apps testable, maintainable, and scalable. This skill guides architectural decisions: module structure, layer separation (UI → Domain → Data), dependency injection with Hilt, state management with Coroutines and Flow, and patterns that survive configuration changes and process death.

## When to Use

- Starting a new Android project or module
- Adding a feature module to an existing multi-module project
- Choosing between MVVM and MVI for a screen
- Setting up or refactoring dependency injection
- Defining boundaries between layers
- Debugging lifecycle or state management issues

**Skip when:** Making a small change within an already-architected feature.

## Core Process

### Step 1: Module Structure

1. **Organize by layer and feature:**

```
:app                          # Application, navigation, DI entry point
:feature:home                 # Home screen (UI + ViewModel)
:feature:profile              # Profile screen (UI + ViewModel)
:feature:settings             # Settings screen (UI + ViewModel)
:core:data                    # Repositories, data sources, API services
:core:domain                  # Use cases, domain models (pure Kotlin)
:core:database                # Room database, entities, DAOs
:core:network                 # Retrofit services, API models, interceptors
:core:ui                      # Shared composables, theme, design tokens
:core:common                  # Utilities, extensions, constants
:core:testing                 # Shared test utilities, fakes
```

2. **Dependency rules:**
   - `:feature:*` depends on `:core:domain`, `:core:ui`, `:core:common`
   - `:core:data` depends on `:core:domain`, `:core:database`, `:core:network`
   - `:core:domain` depends on **nothing** (pure Kotlin module)
   - `:app` depends on all `:feature:*` and `:core:data` (for DI wiring)
   - **Never:** feature → feature, core → feature, domain → data

### Step 2: Layer Separation

3. **Three layers, strict boundaries:**

| Layer | Contains | Depends On |
|-------|----------|-----------|
| **UI** | Composables, ViewModels, UiState | Domain |
| **Domain** | Use cases, domain models, repository interfaces | Nothing |
| **Data** | Repository implementations, data sources, mappers | Domain (interfaces) |

4. **Data flows one direction:** UI ← Domain ← Data

```kotlin
// Domain layer: pure Kotlin, no Android dependencies
interface TaskRepository {
    fun getTasks(): Flow<List<Task>>
    suspend fun addTask(task: Task)
}

data class Task(val id: String, val title: String, val completed: Boolean)

class GetTasksUseCase @Inject constructor(
    private val repository: TaskRepository
) {
    operator fun invoke(): Flow<List<Task>> = repository.getTasks()
}
```

### Step 3: ViewModel and State Management

5. **MVVM with UiState pattern:**

```kotlin
// Sealed interface for exhaustive state handling
sealed interface TaskListUiState {
    data object Loading : TaskListUiState
    data class Success(val tasks: List<Task>) : TaskListUiState
    data class Error(val message: String) : TaskListUiState
}

@HiltViewModel
class TaskListViewModel @Inject constructor(
    private val getTasks: GetTasksUseCase
) : ViewModel() {

    val uiState: StateFlow<TaskListUiState> = getTasks()
        .map<List<Task>, TaskListUiState> { TaskListUiState.Success(it) }
        .catch { emit(TaskListUiState.Error(it.message ?: "Unknown error")) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = TaskListUiState.Loading
        )
}
```

6. **MVI for complex screens** (multiple user actions, side effects):

```kotlin
// Events from UI → ViewModel
sealed interface TaskListEvent {
    data class ToggleTask(val taskId: String) : TaskListEvent
    data class DeleteTask(val taskId: String) : TaskListEvent
    data object RefreshTasks : TaskListEvent
}

// One-time effects (navigation, snackbar)
sealed interface TaskListEffect {
    data class ShowSnackbar(val message: String) : TaskListEffect
    data class NavigateToDetail(val taskId: String) : TaskListEffect
}
```

### Step 4: Dependency Injection with Hilt

7. **Module setup:**

```kotlin
// In :core:data
@Module
@InstallIn(SingletonComponent::class)
abstract class DataModule {
    @Binds
    abstract fun bindTaskRepository(impl: TaskRepositoryImpl): TaskRepository
}

// In :core:network
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL)
        .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
        .build()
}
```

8. **Hilt rules:**
   - Use `@Inject constructor` (not field injection)
   - Scope to the narrowest lifecycle: `@Singleton` only for truly app-wide instances
   - Use `@Binds` for interface→implementation, `@Provides` for third-party classes
   - Test with `@UninstallModules` + `@BindValue` or Hilt test rules

### Step 5: Coroutines and Flow

9. **Structured concurrency:**

```kotlin
// Use viewModelScope — never GlobalScope
viewModelScope.launch {
    repository.syncTasks()
}

// Use withContext for thread switching
suspend fun readFromDisk(): Data = withContext(Dispatchers.IO) {
    file.readText().parseData()
}

// Expose Flow from repositories, collect in ViewModels
fun getTasks(): Flow<List<Task>> = taskDao.observeAll()
    .map { entities -> entities.map { it.toDomain() } }
```

10. **Error handling:**

```kotlin
// Catch in the ViewModel, not in the repository
viewModelScope.launch {
    try {
        repository.syncTasks()
    } catch (e: IOException) {
        _uiState.update { it.copy(error = "Network unavailable") }
    }
}
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "We don't need modules, it's a small app" | Modularization pays off at ~10 screens. Build times and code coupling grow fast. |
| "Use cases are unnecessary boilerplate" | Use cases make ViewModels testable without mocking repositories. They also compose. |
| "I'll put the logic in the ViewModel" | Fat ViewModels become untestable. Domain logic belongs in use cases. |
| "Hilt is too complex, I'll use manual DI" | Manual DI doesn't survive multi-module projects. Hilt scales; manual DI doesn't. |
| "GlobalScope is fine for fire-and-forget" | GlobalScope survives activity destruction, leaking resources. Use structured concurrency. |

## Red Flags

- Feature module depends on another feature module
- Domain layer imports Android framework classes
- ViewModel directly accesses Room DAOs or Retrofit services
- `GlobalScope.launch` anywhere in production code
- Field injection (`@Inject lateinit var`) instead of constructor injection
- Mutable state exposed from ViewModel (`MutableStateFlow` made public)
- Business logic in Composables

## Verification

- [ ] Module dependency graph follows layer rules (no upward dependencies)
- [ ] Domain layer has zero Android dependencies
- [ ] ViewModels expose `StateFlow`, not `MutableStateFlow` or `LiveData`
- [ ] All dependencies provided via Hilt constructor injection
- [ ] No `GlobalScope` usage in production code
- [ ] Repositories return `Flow` for observable data
- [ ] Use cases are independently testable
- [ ] `./gradlew build` succeeds with no circular dependency errors

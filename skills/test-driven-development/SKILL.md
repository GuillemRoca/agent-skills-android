---
name: test-driven-development
description: >-
  Use when implementing new features or fixing bugs. Write tests before
  implementation following Red-Green-Refactor. Covers JUnit5, MockK,
  Compose test rules, and the Prove-It pattern for bugs.
---

# Test-Driven Development

## Overview

Write tests **before** implementation. The Red-Green-Refactor cycle — write a failing test (RED), write minimal code to pass (GREEN), improve the code without changing behavior (REFACTOR) — produces code that is correct by construction and has comprehensive test coverage from the start.

## When to Use

- Implementing any new feature or behavior
- Fixing any bug (use the Prove-It pattern)
- Adding new business logic to ViewModels, use cases, or repositories
- Before refactoring (establish a test safety net first)

**Skip when:** Purely cosmetic UI changes with no behavioral logic.

## Core Process

### Red-Green-Refactor Cycle

#### RED: Write a Failing Test

1. **Write the test first** — describe what the code should do:

```kotlin
class TaskListViewModelTest {
    private val repository = mockk<TaskRepository>()
    private lateinit var viewModel: TaskListViewModel

    @Test
    fun `initial state is Loading`() {
        every { repository.getTasks() } returns flowOf(emptyList())

        viewModel = TaskListViewModel(GetTasksUseCase(repository))

        assertEquals(TaskListUiState.Loading, viewModel.uiState.value)
    }

    @Test
    fun `emits Success with tasks when repository returns data`() = runTest {
        val tasks = listOf(Task("1", "Buy groceries", false))
        every { repository.getTasks() } returns flowOf(tasks)

        viewModel = TaskListViewModel(GetTasksUseCase(repository))
        advanceUntilIdle()

        assertEquals(TaskListUiState.Success(tasks), viewModel.uiState.value)
    }

    @Test
    fun `emits Error when repository throws`() = runTest {
        every { repository.getTasks() } returns flow { throw IOException("Network error") }

        viewModel = TaskListViewModel(GetTasksUseCase(repository))
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertIs<TaskListUiState.Error>(state)
        assertEquals("Network error", state.message)
    }
}
```

2. **Run the test — it must fail** (`./gradlew test`)
   - If it passes immediately, the test doesn't test what you think

#### GREEN: Write Minimal Code to Pass

3. **Implement just enough to make the test pass:**

```kotlin
@HiltViewModel
class TaskListViewModel @Inject constructor(
    getTasks: GetTasksUseCase,
) : ViewModel() {

    val uiState: StateFlow<TaskListUiState> = getTasks()
        .map<List<Task>, TaskListUiState> { TaskListUiState.Success(it) }
        .catch { emit(TaskListUiState.Error(it.message ?: "Unknown error")) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TaskListUiState.Loading)
}
```

4. **Run the test — it must pass**
5. **Don't add code "you'll need later"** — only what the test demands

#### REFACTOR: Improve Without Changing Behavior

6. **Clean up while tests stay green:**
   - Extract common patterns
   - Improve naming
   - Reduce duplication
   - Run tests after every change

### The Prove-It Pattern (Bug Fixes)

7. **For every bug, prove it exists before fixing:**

```kotlin
// Step 1: Write a test that demonstrates the bug
@Test
fun `completed tasks should not appear in active filter`() {
    val tasks = listOf(
        Task("1", "Active task", completed = false),
        Task("2", "Done task", completed = true),
    )
    every { repository.getTasks() } returns flowOf(tasks)

    viewModel = TaskListViewModel(GetTasksUseCase(repository))
    viewModel.setFilter(TaskFilter.ACTIVE)
    advanceUntilIdle()

    val state = viewModel.uiState.value as TaskListUiState.Success
    assertEquals(1, state.tasks.size)
    assertEquals("Active task", state.tasks[0].title)
}

// Step 2: Run it — confirm it FAILS (proves the bug exists)
// Step 3: Fix the code
// Step 4: Run it — confirm it PASSES (proves the fix works)
// Step 5: Run full suite — no regressions
```

### Test Pyramid

```
    /‾‾‾‾‾‾‾‾‾\
   / UI Tests   \        ~5%  — Compose rules, Espresso, Maestro flows
  / (device)     \             see: android-device-testing, android-e2e-verification
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
/ Integration Tests \     ~15% — Room in-memory DB, MockWebServer,
| (local/device)    |           Robolectric
|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
|    Unit Tests       |   ~80% — JUnit5 + MockK
|  (fast, local)      |          ViewModels, UseCases, Repositories
 ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
```

### Testing Patterns by Layer

8. **ViewModel tests:**

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class ViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule() // Sets Dispatchers.Main to TestDispatcher

    @Test
    fun `action updates state correctly`() = runTest {
        // Arrange
        val viewModel = createViewModel()

        // Act
        viewModel.onEvent(TaskListEvent.ToggleTask("1"))
        advanceUntilIdle()

        // Assert
        val state = viewModel.uiState.value
        // ...assertions...
    }
}
```

9. **Repository tests (integration):**

```kotlin
class TaskRepositoryTest {
    private val dao = mockk<TaskDao>()
    private val api = mockk<TaskApi>()
    private val mapper = TaskMapper()
    private val repository = TaskRepositoryImpl(dao, api, mapper)

    @Test
    fun `syncTasks fetches from API and saves to database`() = runTest {
        val apiTasks = listOf(TaskResponse("1", "Test"))
        coEvery { api.getTasks() } returns apiTasks
        coEvery { dao.upsertAll(any()) } just Runs

        repository.syncTasks()

        coVerify { dao.upsertAll(match { it.size == 1 && it[0].id == "1" }) }
    }
}
```

10. **Room DAO tests:**

```kotlin
@RunWith(AndroidJUnit4::class)
class TaskDaoTest {
    private lateinit var db: AppDatabase
    private lateinit var dao: TaskDao

    @Before
    fun setup() {
        db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java,
        ).build()
        dao = db.taskDao()
    }

    @After
    fun teardown() { db.close() }

    @Test
    fun upsert_and_observe_returns_task() = runTest {
        val task = TaskEntity("1", "Test", null, false)
        dao.upsert(task)

        val result = dao.observeAll().first()
        assertEquals(1, result.size)
        assertEquals("Test", result[0].title)
    }
}
```

## Best Practices

- **State over interactions** — assert on outcomes, not method calls
- **DAMP over DRY** — each test should be self-contained and readable
- **Prefer real > fakes > stubs > mocks** — mock only at system boundaries
- **Descriptive names** — test names read like behavior specifications
- **Use `runTest`** — for coroutine testing with `TestDispatcher`
- **Use `advanceUntilIdle()`** — not `delay()` or `Thread.sleep()`

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll write tests after the code works" | You won't. And tests written after are weaker — they verify what you built, not what you intended. |
| "TDD is slow" | TDD prevents debugging. Net time is less. |
| "This is too simple to test" | Simple code becomes complex code. Tests catch the transition. |
| "Mocking is too complex for this" | If it's hard to mock, the design has too many dependencies. TDD surfaces this. |
| "The test passed on the first try, so it's good" | A test that never failed may not test what you think. Make it fail first. |

## Red Flags

- Code written before tests
- Tests that pass immediately (never saw RED)
- `Thread.sleep` or hardcoded delays in tests
- Tests that depend on execution order
- Mocking internal classes (mock boundaries only)
- No tests for error/edge cases
- `@Ignore` or `@Disabled` tests without issue references

## Verification

- [ ] Tests written BEFORE implementation (Red-Green-Refactor)
- [ ] Every test seen failing before passing
- [ ] Bug fixes use the Prove-It pattern
- [ ] `./gradlew test` passes (all unit tests)
- [ ] Test names describe behavior, not implementation
- [ ] No `Thread.sleep` in tests (use `advanceUntilIdle`)
- [ ] Test pyramid proportions reasonable (~80/15/5)
- [ ] Edge cases and error paths covered

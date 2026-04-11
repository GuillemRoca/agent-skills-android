# Testing Patterns — Android Reference

## Core Concepts

### Arrange-Act-Assert (AAA)

```kotlin
@Test
fun `repository returns cached tasks when network unavailable`() {
    // Arrange
    val cachedTasks = listOf(TaskEntity("1", "Cached task", false))
    coEvery { dao.observeAll() } returns flowOf(cachedTasks)
    coEvery { api.getTasks() } throws IOException("No network")

    // Act
    val result = repository.getTasks().first()

    // Assert
    assertEquals(1, result.size)
    assertEquals("Cached task", result[0].title)
}
```

### Naming Convention

```
[unit] [expected behavior] [condition]
```

```kotlin
`viewModel emits Loading initially`
`repository syncs from API when network available`
`dao returns empty list when no tasks exist`
`mapper converts entity to domain correctly`
```

## Common Assertions

```kotlin
// Equality
assertEquals(expected, actual)
assertNotEquals(unexpected, actual)

// Truthiness
assertTrue(condition)
assertFalse(condition)
assertNull(value)
assertNotNull(value)

// Type checking
assertIs<TaskListUiState.Success>(state)
assertIsNot<TaskListUiState.Loading>(state)

// Collections
assertEquals(3, list.size)
assertTrue(list.isEmpty())
assertTrue(list.contains(item))

// Exceptions
assertThrows<IllegalArgumentException> {
    repository.createTask("")
}

// Coroutine-specific
advanceUntilIdle() // Process all pending coroutines
advanceTimeBy(1000) // Advance virtual time
```

## Testing by Layer

### ViewModel Tests (Unit)

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class TaskListViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val repository = mockk<TaskRepository>()

    @Test
    fun `toggleTask updates task completion status`() = runTest {
        val tasks = listOf(Task("1", "Test", false))
        every { repository.getTasks() } returns flowOf(tasks)
        coEvery { repository.updateTask(any()) } just Runs

        val viewModel = TaskListViewModel(GetTasksUseCase(repository))
        viewModel.onEvent(TaskListEvent.ToggleTask("1"))
        advanceUntilIdle()

        coVerify { repository.updateTask(match { it.id == "1" && it.completed }) }
    }
}

// MainDispatcherRule for testing Dispatchers.Main
class MainDispatcherRule(
    private val dispatcher: TestDispatcher = UnconfinedTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(dispatcher)
    }
    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}
```

### Repository Tests (Integration)

```kotlin
class TaskRepositoryImplTest {
    private val dao = mockk<TaskDao>()
    private val api = mockk<TaskApi>()
    private val mapper = TaskMapper()
    private val repository = TaskRepositoryImpl(dao, api, mapper)

    @Test
    fun `syncTasks saves API response to local database`() = runTest {
        val apiResponse = listOf(TaskResponse("1", "Remote task"))
        coEvery { api.getTasks() } returns apiResponse
        coEvery { dao.upsertAll(any()) } just Runs

        repository.syncTasks()

        coVerify {
            dao.upsertAll(match { entities ->
                entities.size == 1 && entities[0].title == "Remote task"
            })
        }
    }

    @Test
    fun `syncTasks handles network error gracefully`() = runTest {
        coEvery { api.getTasks() } throws IOException("timeout")

        assertThrows<IOException> {
            repository.syncTasks()
        }
    }
}
```

### Room DAO Tests (Instrumented)

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
        ).allowMainThreadQueries().build()
        dao = db.taskDao()
    }

    @After
    fun teardown() = db.close()

    @Test
    fun observeAll_emitsUpdates_whenTaskInserted() = runTest {
        val task = TaskEntity("1", "Test", null, false)

        dao.upsert(task)

        val result = dao.observeAll().first()
        assertEquals(1, result.size)
        assertEquals("Test", result[0].title)
    }

    @Test
    fun deleteById_removesCorrectTask() = runTest {
        dao.upsert(TaskEntity("1", "Keep", null, false))
        dao.upsert(TaskEntity("2", "Delete", null, false))

        dao.deleteById("2")

        val result = dao.observeAll().first()
        assertEquals(1, result.size)
        assertEquals("Keep", result[0].title)
    }
}
```

### Compose UI Tests

```kotlin
class TaskListScreenTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun showsLoadingIndicator_whenStateIsLoading() {
        composeTestRule.setContent {
            AppTheme {
                TaskListContent(
                    uiState = TaskListUiState.Loading,
                    onToggle = {},
                    onDelete = {},
                )
            }
        }

        composeTestRule
            .onNodeWithTag("loading_indicator")
            .assertIsDisplayed()
    }

    @Test
    fun showsTasks_whenStateIsSuccess() {
        val tasks = listOf(Task("1", "Buy groceries", false))

        composeTestRule.setContent {
            AppTheme {
                TaskListContent(
                    uiState = TaskListUiState.Success(tasks),
                    onToggle = {},
                    onDelete = {},
                )
            }
        }

        composeTestRule
            .onNodeWithText("Buy groceries")
            .assertIsDisplayed()
    }
}
```

### MockWebServer for API Tests

```kotlin
class TaskApiTest {
    private val mockServer = MockWebServer()
    private lateinit var api: TaskApi

    @Before
    fun setup() {
        mockServer.start()
        api = Retrofit.Builder()
            .baseUrl(mockServer.url("/"))
            .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create<TaskApi>()
    }

    @After
    fun teardown() = mockServer.shutdown()

    @Test
    fun `getTasks returns parsed response`() = runTest {
        mockServer.enqueue(MockResponse()
            .setBody("""[{"id": "1", "title": "Test"}]""")
            .setHeader("Content-Type", "application/json"))

        val result = api.getTasks()

        assertEquals(1, result.size)
        assertEquals("Test", result[0].title)
    }
}
```

## MockK Quick Reference

```kotlin
// Mocking
val repo = mockk<TaskRepository>()

// Stubbing suspend functions
coEvery { repo.syncTasks() } just Runs
coEvery { repo.createTask(any(), any()) } returns Task("1", "Test", false)

// Stubbing Flow
every { repo.getTasks() } returns flowOf(listOf(task))

// Verification
coVerify { repo.syncTasks() }
coVerify(exactly = 1) { repo.createTask("Test", null) }
coVerify { repo.updateTask(match { it.completed }) }

// Argument capture
val slot = slot<TaskEntity>()
coEvery { dao.upsert(capture(slot)) } just Runs
// After call:
assertEquals("Test", slot.captured.title)

// Relaxed mocks (return defaults for unstubbed calls)
val relaxed = mockk<TaskRepository>(relaxed = true)
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Testing implementation details | Breaks on refactor | Test behavior and outcomes |
| Shared mutable state between tests | Order-dependent failures | Fresh setup in `@Before` |
| `Thread.sleep` in tests | Slow, flaky | `advanceUntilIdle()` or `waitUntil` |
| Permanently `@Ignore`d tests | Dead code, false confidence | Fix or delete |
| Mocking everything | Tests nothing real | Mock at boundaries only |
| No assertions | Test always passes | Every test needs at least one assertion |
| Testing private methods | Coupled to implementation | Test via public interface |

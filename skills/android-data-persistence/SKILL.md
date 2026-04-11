---
name: android-data-persistence
description: >-
  Use when implementing local data storage with Room, DataStore, or
  offline-first patterns. Covers entities, DAOs, migrations, Paging3,
  and the repository pattern for data management.
---

# Android Data Persistence

## Overview

Reliable data persistence is critical for Android apps. This skill covers Room (SQLite abstraction), DataStore (key-value and proto), offline-first architecture, Paging3 for large datasets, and the repository pattern that abstracts data sources from the rest of the app.

## When to Use

- Setting up or modifying a Room database
- Writing database migrations
- Implementing offline-first data access
- Adding pagination for large datasets
- Choosing between Room, DataStore, and SharedPreferences
- Implementing the repository pattern

**Skip when:** Data is purely in-memory or comes only from a remote API with no caching.

## Data Storage Decision Guide

| Requirement | Solution |
|------------|----------|
| Structured data with relations | Room |
| User preferences (key-value) | DataStore (Preferences) |
| Typed settings with schema | DataStore (Proto) |
| Large datasets with pagination | Room + Paging3 |
| Simple flags or tokens | DataStore (Preferences) |
| **Never use** | SharedPreferences (for new code) |

## Core Process

### Step 1: Room Setup

1. **Define entities:**

```kotlin
@Entity(
    tableName = "tasks",
    indices = [Index(value = ["created_at"])],
)
data class TaskEntity(
    @PrimaryKey
    val id: String,
    @ColumnInfo(name = "title")
    val title: String,
    @ColumnInfo(name = "description")
    val description: String?,
    @ColumnInfo(name = "completed")
    val completed: Boolean = false,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
)
```

2. **Define DAOs:**

```kotlin
@Dao
interface TaskDao {
    @Query("SELECT * FROM tasks ORDER BY created_at DESC")
    fun observeAll(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :taskId")
    suspend fun getById(taskId: String): TaskEntity?

    @Query("SELECT * FROM tasks WHERE completed = :completed ORDER BY created_at DESC")
    fun observeByStatus(completed: Boolean): Flow<List<TaskEntity>>

    @Upsert
    suspend fun upsert(task: TaskEntity)

    @Upsert
    suspend fun upsertAll(tasks: List<TaskEntity>)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    suspend fun deleteById(taskId: String)

    @Query("DELETE FROM tasks WHERE completed = 1")
    suspend fun deleteCompleted()

    @Transaction
    suspend fun replaceAll(tasks: List<TaskEntity>) {
        deleteAll()
        upsertAll(tasks)
    }

    @Query("DELETE FROM tasks")
    suspend fun deleteAll()
}
```

3. **Define the database:**

```kotlin
@Database(
    entities = [TaskEntity::class],
    version = 1,
    exportSchema = true, // Always export for migration testing
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
}

// Hilt module
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
            .addMigrations(MIGRATION_1_2)
            .build()

    @Provides
    fun provideTaskDao(database: AppDatabase): TaskDao = database.taskDao()
}
```

### Step 2: Migrations

4. **Always write migrations (never `fallbackToDestructiveMigration`):**

```kotlin
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            "ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 0"
        )
    }
}
```

5. **Test migrations:**

```kotlin
@RunWith(AndroidJUnit4::class)
class MigrationTest {
    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        AppDatabase::class.java,
    )

    @Test
    fun migration1To2_addsPriorityColumn() {
        // Create database at version 1
        helper.createDatabase("test-db", 1).apply {
            execSQL("INSERT INTO tasks (id, title, completed, created_at, updated_at) VALUES ('1', 'Test', 0, 0, 0)")
            close()
        }

        // Migrate to version 2
        val db = helper.runMigrationsAndValidate("test-db", 2, true, MIGRATION_1_2)

        // Verify new column has default value
        val cursor = db.query("SELECT priority FROM tasks WHERE id = '1'")
        cursor.moveToFirst()
        assertEquals(0, cursor.getInt(0))
        cursor.close()
    }
}
```

### Step 3: DataStore

6. **Preferences DataStore (key-value):**

```kotlin
// Define keys
object PreferencesKeys {
    val DARK_MODE = booleanPreferencesKey("dark_mode")
    val SORT_ORDER = stringPreferencesKey("sort_order")
    val ONBOARDING_COMPLETE = booleanPreferencesKey("onboarding_complete")
}

// Create DataStore
val Context.settingsDataStore by preferencesDataStore(name = "settings")

// Read
val darkMode: Flow<Boolean> = context.settingsDataStore.data
    .map { preferences -> preferences[PreferencesKeys.DARK_MODE] ?: false }

// Write
suspend fun setDarkMode(enabled: Boolean) {
    context.settingsDataStore.edit { preferences ->
        preferences[PreferencesKeys.DARK_MODE] = enabled
    }
}
```

7. **Proto DataStore (typed schema):**

```kotlin
// Define proto schema (settings.proto)
// syntax = "proto3";
// message AppSettings {
//     bool dark_mode = 1;
//     string sort_order = 2;
//     int32 items_per_page = 3;
// }

object AppSettingsSerializer : Serializer<AppSettings> {
    override val defaultValue: AppSettings = AppSettings.getDefaultInstance()
    override suspend fun readFrom(input: InputStream): AppSettings =
        AppSettings.parseFrom(input)
    override suspend fun writeTo(t: AppSettings, output: OutputStream) =
        t.writeTo(output)
}
```

### Step 4: Repository Pattern

8. **Single source of truth (offline-first):**

```kotlin
class TaskRepositoryImpl @Inject constructor(
    private val taskDao: TaskDao,
    private val taskApi: TaskApi,
    private val mapper: TaskMapper,
) : TaskRepository {

    // Local database is the single source of truth
    override fun getTasks(): Flow<List<Task>> =
        taskDao.observeAll().map { entities ->
            entities.map(mapper::toDomain)
        }

    // Sync: fetch remote → update local → UI observes local
    override suspend fun syncTasks() {
        val remoteTasks = taskApi.getTasks()
        val entities = remoteTasks.map(mapper::toEntity)
        taskDao.upsertAll(entities)
        // No return value — UI observes the Flow from getTasks()
    }

    override suspend fun addTask(task: Task) {
        val entity = mapper.toEntity(task)
        taskDao.upsert(entity)
        // Optionally sync to remote
        try {
            taskApi.createTask(mapper.toNetwork(task))
        } catch (e: IOException) {
            // Queued for retry — local is source of truth
        }
    }
}
```

### Step 5: Paging3

9. **Paginate large datasets:**

```kotlin
// PagingSource from Room (automatic)
@Dao
interface TaskDao {
    @Query("SELECT * FROM tasks ORDER BY created_at DESC")
    fun pagingSource(): PagingSource<Int, TaskEntity>
}

// In ViewModel
val pagedTasks: Flow<PagingData<Task>> = Pager(
    config = PagingConfig(
        pageSize = 20,
        prefetchDistance = 5,
        enablePlaceholders = false,
    ),
    pagingSourceFactory = { taskDao.pagingSource() }
).flow
    .map { pagingData -> pagingData.map(mapper::toDomain) }
    .cachedIn(viewModelScope)

// In Compose
@Composable
fun TaskListPaged(tasks: LazyPagingItems<Task>) {
    LazyColumn {
        items(
            count = tasks.itemCount,
            key = tasks.itemKey { it.id },
        ) { index ->
            val task = tasks[index]
            if (task != null) {
                TaskItem(task = task)
            }
        }

        // Loading states
        when (tasks.loadState.refresh) {
            is LoadState.Loading -> item { LoadingIndicator() }
            is LoadState.Error -> item { ErrorRetry(onRetry = { tasks.retry() }) }
            else -> {}
        }
    }
}
```

### Step 6: Data Mappers

10. **Separate data models per layer:**

```kotlin
// Entity (data layer) — database schema
data class TaskEntity(val id: String, val title: String, ...)

// Domain model (domain layer) — business logic
data class Task(val id: String, val title: String, ...)

// Network model (data layer) — API contract
@Serializable
data class TaskResponse(val id: String, val title: String, ...)

// Mapper
class TaskMapper {
    fun toDomain(entity: TaskEntity): Task = Task(
        id = entity.id,
        title = entity.title,
    )
    fun toEntity(domain: Task): TaskEntity = TaskEntity(
        id = domain.id,
        title = domain.title,
    )
}
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "fallbackToDestructiveMigration is fine for now" | Users lose their data. Write proper migrations from day one. |
| "SharedPreferences works fine" | SharedPreferences isn't type-safe, isn't coroutine-friendly, and has known bugs with apply(). |
| "We don't need offline support" | Users on subways, elevators, and airplanes disagree. Cache early. |
| "One model for all layers is simpler" | Coupling DB schema to UI makes both harder to change. |
| "Paging is overkill" | Loading 10,000 items into memory causes OOM. Paginate datasets over ~100 items. |

## Red Flags

- `fallbackToDestructiveMigration()` in production code
- SharedPreferences in new code
- No migration tests
- Room entities used directly in UI layer
- `suspend` functions where `Flow` should be used (for observable data)
- No error handling in repository sync operations
- Loading entire dataset into memory without pagination

## Verification

- [ ] Room entities, DAOs, and database defined correctly
- [ ] `exportSchema = true` set on `@Database`
- [ ] Migrations written and tested for every schema change
- [ ] DataStore used for preferences (not SharedPreferences)
- [ ] Repository pattern abstracts data sources
- [ ] Offline-first: local DB is single source of truth
- [ ] Paging3 used for large datasets
- [ ] Separate data models per layer (Entity, Domain, Network)
- [ ] `./gradlew test` and `./gradlew connectedAndroidTest` pass

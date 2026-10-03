---
name: api-and-interface-design
description: >-
  Use when designing interfaces between layers (Repository, UseCase, API
  client) or defining data contracts. Covers Retrofit interfaces, Room
  DAOs, Kotlin sealed classes, backward compatibility, and idempotency
  keys for safely retried writes.
---

# API and Interface Design

## Overview

Hyrum's Law: "With a sufficient number of users of an API, all observable behaviors of your system will be depended on by somebody." Design interfaces — Repository contracts, UseCase signatures, Retrofit services, Room DAOs — as deliberate contracts. Everything observable becomes a dependency.

## When to Use

- Defining a new Repository interface
- Creating Retrofit API service interfaces
- Designing Room DAOs
- Defining ViewModel ↔ UI contracts (UiState, Events)
- Changing any public interface in a shared module
- Designing inter-module contracts in multi-module projects
- Sending state-changing requests that can be retried (payments, orders, messages, uploads)

**Skip when:** Modifying internal (private) implementation details.

## Core Process

### Step 1: Contract-First Design

1. **Define the interface before implementing:**

```kotlin
// Repository contract (in :core:domain)
interface TaskRepository {
    fun getTasks(): Flow<List<Task>>
    fun getTaskById(taskId: String): Flow<Task?>
    suspend fun createTask(title: String, description: String?): Task
    suspend fun updateTask(task: Task)
    suspend fun deleteTask(taskId: String)
    suspend fun syncWithRemote()
}
```

2. **Design principles:**
   - Return `Flow` for observable data (not `suspend` for single reads)
   - Use `suspend` for one-shot operations
   - Accept domain types, not framework types (no `Entity` in interfaces)
   - Throw domain-specific exceptions, not framework exceptions

### Step 2: Retrofit Interfaces

3. **Define clean API contracts:**

```kotlin
interface TaskApi {
    @GET("tasks")
    suspend fun getTasks(
        @Query("page") page: Int = 1,
        @Query("per_page") perPage: Int = 20,
    ): TaskListResponse

    @GET("tasks/{id}")
    suspend fun getTask(@Path("id") taskId: String): TaskResponse

    @POST("tasks")
    suspend fun createTask(@Body request: CreateTaskRequest): TaskResponse

    @PUT("tasks/{id}")
    suspend fun updateTask(
        @Path("id") taskId: String,
        @Body request: UpdateTaskRequest,
    ): TaskResponse

    @DELETE("tasks/{id}")
    suspend fun deleteTask(@Path("id") taskId: String)
}
```

4. **API contract rules:**
   - Use `@Serializable` data classes for request/response bodies (Kotlin Serialization)
   - Separate request and response models (even if fields overlap)
   - Use `sealed class` for polymorphic responses
   - Never expose Retrofit internals (no `Response<T>` in Repository interface)

### Step 3: Data Models and Sealed Types

5. **Use the type system to make illegal states unrepresentable:**

```kotlin
// BAD: stringly-typed status
data class Task(
    val id: String,
    val title: String,
    val status: String, // "pending", "in_progress", "completed" — typos possible
)

// GOOD: sealed type
data class Task(
    val id: String,
    val title: String,
    val status: TaskStatus,
)

sealed interface TaskStatus {
    data object Pending : TaskStatus
    data object InProgress : TaskStatus
    data class Completed(val completedAt: Instant) : TaskStatus
}
```

6. **Use value classes for type safety:**

```kotlin
@JvmInline
value class TaskId(val value: String)

@JvmInline
value class UserId(val value: String)

// Prevents accidentally passing a UserId where a TaskId is expected
suspend fun getTask(taskId: TaskId): Task
```

### Step 4: Error Handling Strategy

7. **Define domain-specific errors:**

```kotlin
sealed interface DataError {
    data class Network(val cause: Throwable) : DataError
    data class NotFound(val id: String) : DataError
    data class Validation(val message: String) : DataError
    data object Unauthorized : DataError
    data class Unknown(val cause: Throwable) : DataError
}

// Use Result type for operations that can fail
suspend fun createTask(title: String): Result<Task>

// Or define a custom Result type
sealed interface DataResult<out T> {
    data class Success<T>(val data: T) : DataResult<T>
    data class Error(val error: DataError) : DataResult<Nothing>
}
```

8. **Error handling rules:**
   - Catch specific exceptions, not generic `Exception`
   - Map framework exceptions to domain errors at the boundary
   - Never swallow errors silently
   - Provide actionable error messages for the UI

### Step 5: Backward Compatibility

9. **Extend, don't modify:**

```kotlin
// Version 1
interface TaskRepository {
    fun getTasks(): Flow<List<Task>>
    suspend fun createTask(title: String): Task
}

// Version 2: ADD new methods, don't change existing signatures
interface TaskRepository {
    fun getTasks(): Flow<List<Task>>
    suspend fun createTask(title: String): Task

    // New: added with default implementation for backward compatibility
    fun getTasksByStatus(status: TaskStatus): Flow<List<Task>> =
        getTasks().map { tasks -> tasks.filter { it.status == status } }
}
```

10. **When breaking changes are necessary:**
    - Deprecate with `@Deprecated` and replacement guidance
    - Provide a migration period
    - Update all callers in the same PR
    - See `deprecation-and-migration` for the full process

### Step 6: Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Repository | `get*`, `observe*`, `create*`, `update*`, `delete*` | `getTaskById()` |
| UseCase | Verb phrase, `operator fun invoke()` | `GetTasksUseCase()` |
| Retrofit | HTTP-verb aligned | `@GET`, `@POST`, `@PUT`, `@DELETE` |
| Room DAO | `observe*` for Flow, `get*` for suspend | `observeAll()`, `getById()` |
| UiState | Sealed interface per screen | `TaskListUiState.Success` |
| Events | Past-tense or imperative | `TaskClicked`, `DeleteTask` |
| Request/Response | Suffixed | `CreateTaskRequest`, `TaskResponse` |

### Step 7: Validation at Boundaries

11. **Validate at system boundaries, trust internally:**

```kotlin
// At the API boundary (Retrofit interceptor or repository)
class TaskRepositoryImpl @Inject constructor(
    private val api: TaskApi,
    private val dao: TaskDao,
) : TaskRepository {

    override suspend fun createTask(title: String, description: String?): Task {
        // Validate at boundary
        require(title.isNotBlank()) { "Task title must not be blank" }
        require(title.length <= 200) { "Task title must not exceed 200 characters" }

        val entity = TaskEntity(
            id = UUID.randomUUID().toString(),
            title = title.trim(),
            description = description?.trim(),
        )
        dao.upsert(entity)
        return entity.toDomain()
    }
}
```

### Step 8: Idempotency Keys for Retried Writes

12. **Assume every write is sent more than once.** On Android, duplicates come from OkHttp's `retryOnConnectionFailure`, caller retry loops, WorkManager retries with backoff, double-taps, and process death between sending a request and persisting the response. A timeout means *unknown*, not *failed* — the server may already have applied it. For non-idempotent writes (`POST` that charges, orders, sends), attach an `Idempotency-Key`.

**Key the intent, not the attempt.** Generate a UUID once when the user commits the action, persist it *with* the pending operation (Room outbox row or WorkManager `inputData`), and reuse it on every retry — including after process death:

```kotlin
@Entity data class PendingOrder(@PrimaryKey val idempotencyKey: String, val cartId: String, val payload: String)

suspend fun placeOrder(cart: Cart) {                       // runs once per user intent
    val op = PendingOrder(UUID.randomUUID().toString(), cart.id, json.encodeToString(cart.toRequest()))
    outboxDao.insert(op)                                   // key survives process death
    workManager.enqueue(OneTimeWorkRequestBuilder<SubmitOrderWorker>()
        .setInputData(workDataOf("key" to op.idempotencyKey)).build())
}

interface OrderApi {
    @POST("orders")
    suspend fun createOrder(@Header("Idempotency-Key") key: String, @Body body: CreateOrderRequest): OrderResponse
}

// In SubmitOrderWorker.doWork(): same key on every attempt
val key = inputData.getString("key") ?: return Result.failure()
val op = outboxDao.get(key) ?: return Result.success()     // already submitted
return try {
    api.createOrder(op.idempotencyKey, json.decodeFromString(op.payload))
    outboxDao.delete(op)
    Result.success()
} catch (e: IOException) {
    Result.retry()                                         // outcome unknown: retry with the same key
} catch (e: HttpException) {
    if (e.code() == 409) Result.retry() else Result.failure() // 409 = still in flight (check your server's contract)
}
```

- **Never** generate the key inside an OkHttp interceptor, the Retrofit call, or `doWork()` — that layer runs once per attempt. If you prefer an interceptor over `@Header`, pass the stored key via a Retrofit `@Tag` and read it with `request.tag()`.
- Don't derive the key from content (`"$userId:$amount"`) — two legitimate identical orders would collapse into one.

**Know the server contract** (usually another team's): it stores key + request fingerprint + response, replays the stored response for a repeat, rejects the same key with a *different* body (`422`, sometimes `409`), returns `409` while the first attempt is still in flight, and expires keys after a window. Client consequences: treat a replayed response as success, retry an in-flight `409` with backoff, treat a body-mismatch error as a client bug (never "fix" it with a new key), and keep the outbox retry horizon shorter than the server's key expiry.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll define the interface from the implementation" | Implementation leaks into the contract. Design the contract first. |
| "One model for all layers is simpler" | Coupling DB schema to API to UI makes all three brittle. |
| "Strings are fine for types" | Strings allow typos, have no exhaustiveness checking, and no IDE support. |
| "We don't need backward compatibility yet" | By the time you need it, you have callers you can't easily find. |
| "Duplicate requests are rare" | They're correlated with bad networks and degraded backends — exactly when retries spike and duplicates cost most. |
| "A new key per retry is fine, the server dedupes" | The server dedupes by key. A fresh key per attempt is a fresh charge per attempt. |
| "The key can live in memory" | Process death mid-request is routine on Android. A key that isn't persisted with the operation is lost exactly when a retry is needed. |

## Red Flags

- Room entities exposed to UI layer
- Retrofit `Response<T>` returned from Repository
- Generic `String` where sealed type or enum is appropriate
- No validation at system boundaries
- Breaking interface changes without deprecation
- `Any` or `Object` in public interfaces
- Inconsistent naming across layers
- Non-idempotent `POST` (payment, order, message) retried without an `Idempotency-Key`
- `UUID.randomUUID()` for the key inside an interceptor, API call, or `doWork()`
- Idempotency key held only in memory or a ViewModel, not persisted with the pending operation
- A `409`/`422` on a keyed request "handled" by retrying with a new key

## Verification

- [ ] Interfaces designed before implementation (contract-first)
- [ ] Domain types used at interface boundaries (not framework types)
- [ ] Sealed types used for finite state sets
- [ ] Error handling uses domain-specific error types
- [ ] Validation at system boundaries, trust internally
- [ ] Naming follows project conventions
- [ ] Backward compatibility maintained (or breaking change documented)
- [ ] Tests verify interface contracts
- [ ] Every retryable state-changing request sends an `Idempotency-Key`, or is documented as unsafe to retry
- [ ] Key is generated once per user intent and persisted with the pending operation (test: kill the process mid-request, the retry sends the same key)
- [ ] `409`/`422` and replayed responses are handled per the server contract, and the client retry horizon is shorter than server key expiry

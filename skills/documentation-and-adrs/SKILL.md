---
name: documentation-and-adrs
description: >-
  Use when making architectural trade-offs, changing public APIs, shipping
  user-facing features, or onboarding developers. Guides writing ADRs,
  inline documentation, and API docs.
---

# Documentation and ADRs

## Overview

Document the *why* behind decisions, not just the code. Architecture Decision Records (ADRs) capture the context, alternatives, and consequences of significant decisions so future developers understand why the system is shaped the way it is.

## When to Use

- Making an architectural trade-off (e.g., Room vs DataStore, Compose vs XML)
- Changing a public API or module boundary
- Shipping a user-facing feature with non-obvious implementation choices
- Onboarding new developers to the project
- After a post-mortem or incident that changed the architecture

**Skip when:** The change is self-explanatory from the code and commit message.

## Core Process

### Architecture Decision Records (ADRs)

1. **ADRs live in `docs/decisions/`** with sequential numbering:
   ```
   docs/decisions/
   ├── 0001-use-compose-over-xml.md
   ├── 0002-adopt-mvi-for-complex-screens.md
   ├── 0003-room-migration-strategy.md
   └── 0004-modularization-approach.md
   ```

2. **ADR template:**

```markdown
# ADR-NNNN: Title

## Status
Proposed | Accepted | Deprecated | Superseded by ADR-XXXX

## Context
What is the issue or decision we're facing? What forces are at play?

## Decision
What did we decide to do?

## Alternatives Considered
### Alternative A: [Name]
- Pros: ...
- Cons: ...

### Alternative B: [Name]
- Pros: ...
- Cons: ...

## Consequences
### Positive
- ...

### Negative
- ...

### Risks
- ...
```

3. **Never delete old ADRs** — supersede them with new ones that reference the old decision:
   ```
   ## Status
   Superseded by [ADR-0007](0007-switch-to-kmp.md)
   ```

### Inline Documentation

4. **Document intent, not mechanics:**

```kotlin
// BAD: increments counter by one
counter++

// GOOD: Rate-limit API calls to avoid 429 responses from the backend.
// The backend enforces a 10-request-per-second limit per client.
if (requestCount >= MAX_REQUESTS_PER_SECOND) {
    delay(rateLimitWindow)
}
```

5. **When to add inline comments:**
   - Non-obvious business logic
   - Platform workarounds (`// Workaround for API 28 camera permission bug`)
   - Performance-critical code paths
   - Regex patterns or complex algorithms

6. **When NOT to add comments:**
   - Code that reads clearly (self-documenting)
   - Commented-out code (delete it — git has history)
   - "TODO" without an issue reference (create the issue)

### API Documentation

7. **Public APIs get KDoc:**

```kotlin
/**
 * Fetches the user's profile from the remote API, falling back to
 * the local cache if the network is unavailable.
 *
 * @param userId The unique identifier of the user.
 * @return The user profile, or `null` if not found in cache or remote.
 * @throws NetworkException if the request fails and no cache exists.
 */
suspend fun getUserProfile(userId: String): UserProfile?
```

8. **Document module boundaries** — each module's `README.md` should describe:
   - Purpose of the module
   - Public API surface
   - Dependencies (what it depends on, what depends on it)

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "The code is self-documenting" | Code shows *what*, not *why*. Trade-offs and constraints aren't in the code. |
| "We'll document later" | You won't. Context fades. Document decisions when you make them. |
| "ADRs are bureaucratic overhead" | A 10-minute ADR prevents hours of "why did we do it this way?" conversations. |
| "Everyone knows why we chose this" | Everyone who was in the room. New hires, future maintainers, and your future self don't. |

## Red Flags

- Architectural decisions without ADRs
- Inline comments explain *what* instead of *why*
- Commented-out code blocks
- TODOs without issue references
- Public APIs without KDoc
- Stale documentation that contradicts current implementation
- ADRs deleted instead of superseded

## Verification

- [ ] Significant architectural decisions have ADRs in `docs/decisions/`
- [ ] ADRs include context, alternatives, and consequences
- [ ] Old ADRs are superseded, not deleted
- [ ] Inline comments explain *why*, not *what*
- [ ] No commented-out code
- [ ] Public APIs have KDoc with `@param`, `@return`, `@throws`
- [ ] Module boundaries documented

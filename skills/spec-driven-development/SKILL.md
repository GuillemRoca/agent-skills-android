---
name: spec-driven-development
description: >-
  Use when starting new Android projects, features, or changes with unclear
  requirements. Guides writing a structured spec (SPEC.md) that becomes the
  shared source of truth before any code is written.
---

# Spec-Driven Development

## Overview

Write a structured specification before writing code. The spec becomes the shared source of truth — a development contract that prevents misalignment, scope creep, and wasted effort. Every implementation decision traces back to the spec.

## When to Use

- Starting a new Android project or module
- Adding a feature that spans multiple files or layers
- Requirements are ambiguous or come from multiple stakeholders
- Before writing a `tasks/plan.md`

**Skip when:** Single-line fixes or changes that are unambiguous and self-contained.

## Core Process

### Phase 1: Specify

1. **Ask clarifying questions** before writing anything:
   - What problem does this solve? Who is the user?
   - Which features are in scope? Which are explicitly out?
   - What is the tech stack? (minSdk, target SDK, Compose vs XML, DI framework)
   - What are the boundaries? (offline support? accessibility? tablet?)

2. **Write SPEC.md** with these sections:

```markdown
# Feature Name — Specification

## Objective
What we're building and why. One paragraph.

## Commands
Key Gradle tasks and how to use them:
- `./gradlew assembleDebug` — build debug APK
- `./gradlew test` — run unit tests
- `./gradlew connectedAndroidTest` — run instrumented tests
- `./gradlew lint` — run Android Lint

## Project Structure
Where new code lives in the module hierarchy:
- `:app` — main application module
- `:feature:feature-name` — new feature module
- `:core:data` — data layer (repositories, data sources)
- `:core:domain` — domain layer (use cases, models)

## Code Style
- Kotlin with Jetpack Compose for UI
- MVVM/MVI architecture with ViewModel + StateFlow
- Hilt for dependency injection
- Coroutines + Flow for async operations
- Material 3 design system

## Testing Strategy
- Unit tests: JUnit5 + MockK for ViewModels, use cases, repositories
- UI tests: Compose test rules for screen-level testing
- Integration tests: Room in-memory database, MockWebServer
- Target: critical paths covered, not arbitrary coverage %

## Boundaries
What is explicitly NOT in scope:
- [ ] List exclusions here
```

3. **Save as `SPEC.md`** in the project or module root

### Phase 2: Plan

4. Review spec with human — get explicit approval before continuing
5. Use `planning-and-task-breakdown` to create implementation tasks from the spec

### Phase 3: Tasks

6. Break spec into vertical slices (see `planning-and-task-breakdown`)
7. Each task references the spec section it implements

### Phase 4: Implement

8. Build incrementally (see `incremental-implementation`)
9. Every PR references the spec section it addresses
10. Spec evolves with the project — update it when requirements change

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "The feature is simple, no spec needed" | Simple features have hidden edge cases (configuration changes, process death, deep links). A brief spec still beats none. |
| "We'll figure it out as we go" | Without a spec, each developer builds a different mental model. Alignment costs compound. |
| "The ticket/issue IS the spec" | Tickets describe what to build. Specs describe how it fits into the system, what's excluded, and how to verify. |
| "Writing specs slows us down" | Rework from misalignment costs 3–10x more than a spec. |

## Red Flags

- Implementation started without written spec
- Spec has no "Boundaries" or exclusions section
- Spec doesn't specify testing strategy
- Multiple developers have different understandings of scope
- Spec never updated after requirement changes

## Verification

- [ ] SPEC.md exists in version control
- [ ] All six sections filled in (Objective, Commands, Structure, Style, Testing, Boundaries)
- [ ] Human has reviewed and approved the spec
- [ ] Implementation tasks reference spec sections
- [ ] Spec updated when requirements changed during development

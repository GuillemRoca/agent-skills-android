---
name: spec-driven-development
description: >-
  Use when starting new Android projects, features, or changes with unclear
  requirements. Guides writing a structured spec (SPEC.md) that becomes the
  shared source of truth before any code is written. Also use when one
  request spans several independently testable capabilities and needs a
  capability map of modules before specifying.
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

Four phases, preceded by a scope check (Phase 0) that activates only when one request bundles several independently testable capabilities. Don't advance to the next phase until the current one is approved.

### Phase 0: Scope Check

Most requests describe one capability — skip straight to Specify. Phase 0 is for the exception.

**Detection.** Decompose before specifying when a single requirement bundles several independently testable capabilities:

- It names distinct capabilities with their own consumers or data (e.g. sign-in, checkout, push notifications, order history)
- Acceptance criteria cluster into groups that could ship and be verified separately
- One capability could be cut or replaced without rewriting the others' requirements

**Propose a capability map before writing any spec.** A module table plus a build order — not a project plan. On Android, module ids usually line up with the Gradle modules they will become:

```markdown
# Capability Map: [Initiative Name]

| Module id     | Gradle module            | Responsibility                  | Depends on        |
|---------------|--------------------------|---------------------------------|-------------------|
| auth          | :feature:auth            | Sign-in, session, token refresh | —                 |
| checkout      | :feature:checkout        | Cart, payment, confirmation     | auth              |
| notifications | :core:notifications      | FCM registration, channels      | auth              |
| order-history | :feature:order-history   | Past orders list and detail     | checkout          |

Build order: auth → checkout, notifications → order-history
```

- **Stable module ids.** Kebab-case, chosen once, never renamed mid-initiative. Specs and plans select work by these ids instead of guessing which spec is active.
- **Dependency direction, no cycles.** Arrows point one way — the same rule Gradle enforces between modules. If two modules each need the other, they are one module.
- **Interfaces live at the boundary.** The map records that `checkout` depends on `auth`; the contract between them belongs in the provider module's spec (see `api-and-interface-design`).

**The map is gated like every phase.** The human reviews module boundaries, dependency direction, and build order before any module spec is written. Getting the map wrong is expensive; reviewing ten lines is not.

**Then recurse per module.** Run Specify → Plan → Tasks → Implement for each module in dependency order. Save the approved map at the project root and each module's spec next to it, named by module id (`SPEC-auth.md`, `SPEC-checkout.md`) — the map, not filename guessing, is the index of what exists.

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

4. **Stop after writing the spec.** Once it is saved:
   - Summarize it and list any open questions
   - Ask the human to approve it or request changes
   - **End your turn.** Don't start Phase 2, invoke `planning-and-task-breakdown`, or write code in the same turn. Planning starts only after the human approves the spec in a later turn.

### Phase 2: Plan

5. With the approved spec, use `planning-and-task-breakdown` to create implementation tasks

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
| "It's one big feature; splitting it is overhead" | If acceptance criteria cluster into independently testable groups, a monolithic spec forces every task to reason over the whole contract. A ten-line capability map is the cheap alternative. |
| "I'll decompose during planning" | Planning slices tasks *within* a spec. Module boundaries and dependency direction must be decided before the spec is written, not after. |
| "The spec is obviously fine, I'll start the plan now" | Approval you didn't wait for isn't approval. The human's corrections are cheapest before a plan is built on the spec. |

## Red Flags

- Implementation started without written spec
- Writing the spec and starting the plan or code in the same turn
- One spec whose requirements span several independently testable capabilities
- Module boundaries or build order decided implicitly during implementation
- Spec has no "Boundaries" or exclusions section
- Spec doesn't specify testing strategy
- Multiple developers have different understandings of scope
- Spec never updated after requirement changes

## Verification

- [ ] SPEC.md exists in version control
- [ ] All six sections filled in (Objective, Commands, Structure, Style, Testing, Boundaries)
- [ ] Human has reviewed and approved the spec — the turn ended after saving it; approval came in a later turn
- [ ] If the request bundled several independently testable capabilities, a capability map (module ids, dependency direction, build order) was approved before any module spec was written
- [ ] Implementation tasks reference spec sections
- [ ] Spec updated when requirements changed during development

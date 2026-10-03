---
name: planning-and-task-breakdown
description: >-
  Use when starting implementation of a feature or change that involves
  multiple files or steps. Produces a structured task list with vertical
  slices, acceptance criteria, and verification steps.
---

# Planning and Task Breakdown

## Overview

"The plan *is* the task — 10 minutes upfront prevents hours of rework." Break work into small, ordered, verifiable tasks before writing code. Each task is a vertical slice that leaves the system in a working state.

## When to Use

- Before implementing any feature spanning more than 2–3 files
- After writing a spec (follows `spec-driven-development`)
- When a task feels "too big to start"
- When multiple developers will work on related code

**Skip when:** The change is a single-file fix with obvious scope.

## Core Process

### Step 1: Read-Only Analysis

1. **Read the spec** (SPEC.md) or requirements — do not modify any code
2. **Map the codebase:**
   - Which modules are involved? (`:app`, `:feature:*`, `:core:*`)
   - Which layers? (UI → ViewModel → UseCase → Repository → DataSource)
   - What existing code can be reused?
3. **Identify constraints:**
   - Android API level requirements
   - Existing architecture patterns to follow
   - Library versions and compatibility

### Step 2: Map Dependencies

4. **Draw the dependency graph:**
   - Data models → Repository → UseCase → ViewModel → UI
   - Room entities → DAOs → Database migrations
   - Navigation graph changes → Screen composables → ViewModels
5. **Identify the critical path** — what must exist before other work can start

### Step 3: Vertical Slicing

6. **Slice vertically, not horizontally:**

   **Wrong (horizontal):**
   - Task 1: Create all Room entities
   - Task 2: Create all DAOs
   - Task 3: Create all repositories
   - Task 4: Create all ViewModels
   - Task 5: Create all screens

   **Right (vertical):**
   - Task 1: User can view item list (Entity + DAO + Repo + ViewModel + Screen)
   - Task 2: User can create new item (AddScreen + ViewModel + Repo insert)
   - Task 3: User can edit existing item (EditScreen + ViewModel + Repo update)
   - Task 4: User can delete item (swipe-to-delete + Repo delete + undo)

7. **Each slice must:**
   - Deliver observable functionality
   - Be testable in isolation
   - Leave `./gradlew build` passing

### Step 4: Write Structured Tasks

8. **Check for an incomplete plan first.** If `tasks/plan.md` or `tasks/todo.md` already exists with unchecked tasks:
   - Same work being replanned (the user asked to revise or extend it) → update the files in place
   - Different work → **stop and ask.** The unchecked tasks may be mid-build in another session. Don't delete, overwrite, or rename them; let the user decide (finish the old plan, discard it explicitly, or say where the new plan goes). The same applies to an external tracker: never bulk-close another plan's open items to make room.
9. **Create `tasks/plan.md`** with the dependency graph and approach. Always markdown — design decisions, risks, and open questions don't map onto tracker issues.
10. **Record tasks in the task list target**, in execution order:
    - **Default: `tasks/todo.md`** — the checklist the `/build` command expects
    - **External tracker:** if the project's agent rules (`AGENTS.md`, `CLAUDE.md`) or the user designate one (GitHub Issues, Jira, Linear, …), create one item per task instead of writing `tasks/todo.md`. Put acceptance criteria and verification in the item body, dependencies in the tracker's "blocked by" links, and note the tracker in `tasks/plan.md` with an ordered index of item IDs so future sessions know where to look.

Each task uses this structure, in either target:

```markdown
## Tasks

### Task 1: [Short description]
**Files:** `feature/src/.../ItemListScreen.kt`, `core/data/src/.../ItemDao.kt`
**Acceptance criteria:**
- Item list loads from Room database
- Empty state shown when no items exist
- Loading state shown during fetch
**Verification:**
- [ ] `./gradlew test` passes
- [ ] `./gradlew assembleDebug` succeeds
- [ ] Compose Preview renders correctly
```

### Step 5: Order by Dependencies

11. **Sequence tasks** so each builds on the previous
12. **Add checkpoints** every 2–3 tasks: run full test suite, review with human
13. **Flag risks** on tasks with uncertainty — mark as "spike" if investigation needed

## Task Sizing Guide

| Size | Files | Duration | Action |
|------|-------|----------|--------|
| Small | 1–2 | < 30 min | Execute directly |
| Medium | 3–5 | 30–60 min | Execute with checkpoint |
| Large | 6+ | > 60 min | **Split further** |

Split when: task touches >2 independent subsystems, or acceptance criteria exceed 5 items.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll plan as I go" | Without a task list, you lose track of scope and dependencies. Rework multiplies. |
| "The spec is the plan" | Specs describe *what*. Plans describe *how* and *in what order*. |
| "Planning takes too long" | A 10-minute plan prevents hours of backtracking. |
| "I know this codebase, I don't need a plan" | Plans catch dependency gaps that familiarity masks. |
| "The old `tasks/plan.md` is stale, I'll just replace it" | Unchecked tasks may be mid-build in another session. Overwriting them destroys work state that exists nowhere else. Stop and ask. |

## Red Flags

- Implementing without a written task list
- Overwriting a `tasks/plan.md` or `tasks/todo.md` that still has unchecked tasks for different work, without asking
- Writing `tasks/todo.md` when the project designated an external tracker (or scattering tasks across both)
- Tasks missing acceptance criteria
- No verification steps on tasks
- Tasks spanning >5 files without splitting
- No checkpoints between tasks
- Horizontal slicing (all DAOs, then all repos, then all VMs)

## Verification

- [ ] `tasks/plan.md` exists with dependency graph
- [ ] Ordered tasks recorded in the task list target (default `tasks/todo.md`)
- [ ] No pre-existing incomplete plan was overwritten without explicit user confirmation
- [ ] Every task has acceptance criteria and verification steps
- [ ] Tasks are vertically sliced (each delivers observable functionality)
- [ ] No task exceeds "Large" sizing without justification
- [ ] Checkpoints placed every 2–3 tasks
- [ ] Human has reviewed the plan before implementation starts

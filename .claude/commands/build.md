# /build — Incremental Implementation with TDD

Build the next task incrementally using test-driven development.

## Instructions

Load and follow these skills:
- `incremental-implementation` from `skills/incremental-implementation/SKILL.md`
- `test-driven-development` from `skills/test-driven-development/SKILL.md`

### Per-Task Cycle

For each task in `tasks/todo.md`:

1. **Review** the task's acceptance criteria
2. **Gather examples** — find similar patterns in the codebase
3. **Write a failing test** (RED) — describes the expected behavior
4. **Write minimal code** to pass the test (GREEN)
5. **Run `./gradlew test`** — verify all tests pass
6. **Run `./gradlew assembleDebug`** — verify the build succeeds
7. **Commit** the increment
8. **Repeat** for the next acceptance criterion

### Error Handling

If a test fails unexpectedly or the build breaks:
- Load `debugging-and-error-recovery` skill
- Follow the six-step triage process
- Fix the root cause before proceeding

### Rules

- Each increment leaves the codebase in a working state
- Never skip the build check between increments
- Commits are small and focused (~100 lines)
- Incomplete features go behind feature flags
- Don't mix refactoring with feature work

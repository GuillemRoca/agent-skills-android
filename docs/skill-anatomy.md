# Skill Anatomy

This document describes the structure and conventions for writing skills in the Agent Skills for Android project.

## File Location

Skills live in `skills/{skill-name}/SKILL.md`:

```
skills/
├── test-driven-development/
│   └── SKILL.md
├── android-architecture/
│   └── SKILL.md
└── your-new-skill/
    ├── SKILL.md          # Required
    ├── examples.md       # Optional
    └── scripts/          # Optional
```

## SKILL.md Structure

### YAML Frontmatter (Required)

```yaml
---
name: skill-name-in-kebab-case
description: >-
  Use when [specific trigger conditions]. [What the skill does
  in one sentence]. Keep under 1024 characters.
---
```

**Rules:**
- `name`: lowercase, hyphen-separated, matches directory name exactly
- `description`: starts with "Use when", describes *what* and *when*
- Description is used in system prompts for skill matching — be specific about triggers
- Only the Agent Skills spec keys are allowed at the top level: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Anything host- or model-specific goes under `metadata`
- Keep values YAML-safe: fold long text with `>-`, and quote a single-line value that starts with `` ` ``, `@`, `*`, `%`, `,` or contains `: `. `./scripts/validate-skills.sh` enforces both rules

### Section 1: Overview

The elevator pitch. 2–3 sentences explaining what this skill does and why it matters.

```markdown
## Overview

Write tests **before** implementation. The Red-Green-Refactor cycle
produces code that is correct by construction and has comprehensive
test coverage from the start.
```

### Section 2: When to Use

Specific trigger conditions and explicit exclusions:

```markdown
## When to Use

- Implementing any new feature or behavior
- Fixing any bug (use the Prove-It pattern)
- Before refactoring (establish a test safety net first)

**Skip when:** Purely cosmetic UI changes with no behavioral logic.
```

### Section 3: Core Process

Numbered steps with Kotlin code examples. This is the main content — the workflow the agent follows:

```markdown
## Core Process

### Step 1: Write a Failing Test

1. **Write the test first:**

\```kotlin
@Test
fun `viewModel emits Success when repository returns data`() = runTest {
    // Arrange
    every { repository.getTasks() } returns flowOf(listOf(task))

    // Act
    val viewModel = TaskListViewModel(GetTasksUseCase(repository))
    advanceUntilIdle()

    // Assert
    assertIs<TaskListUiState.Success>(viewModel.uiState.value)
}
\```

2. **Run the test — it must fail** (`./gradlew test`)
```

**Code example rules:**
- All code in **Kotlin** (not Java, TypeScript, or pseudocode)
- Build commands use **`./gradlew`** (not npm, yarn, etc.)
- Use real Android libraries (Compose, Room, Hilt, Retrofit, etc.)
- Show complete, compilable snippets (not fragments)

### Section 4: Common Rationalizations

Table of shortcuts agents attempt and why they fail:

```markdown
## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll write tests after" | You won't. Tests written after verify what you built, not what you intended. |
| "This is too simple to test" | Simple code becomes complex code. Tests catch the transition. |
```

**Why this matters:** Agents are biased toward speed. Rationalizations tables pre-empt the most common shortcuts and provide factual rebuttals.

### Section 5: Red Flags

Observable violations that indicate the skill was applied incorrectly:

```markdown
## Red Flags

- Code written before tests
- Tests that pass immediately (never saw RED)
- `Thread.sleep` in tests
- No tests for error/edge cases
```

### Section 6: Verification

Checklist of tangible evidence. Every item must be verifiable:

```markdown
## Verification

- [ ] Tests written BEFORE implementation
- [ ] Every test seen failing before passing
- [ ] `./gradlew test` passes
- [ ] Test names describe behavior, not implementation
```

**Rules:**
- Use checkboxes (`- [ ]`)
- Each item is a concrete, verifiable action (not "code looks good")
- Include specific commands to run
- Include what to look for in the output

## Design Philosophy

### Workflows, Not Reference Docs

Skills describe step-by-step processes, not encyclopedic knowledge. Each step builds on the previous. Skipping steps has consequences.

### Actionable Over General

```markdown
# BAD (general knowledge)
Tests are important for software quality.

# GOOD (actionable step)
1. Write a test that describes the expected behavior
2. Run `./gradlew test` — confirm it fails
3. Write the minimal code to pass the test
```

### Concrete Verification

```markdown
# BAD (subjective)
- [ ] Code is well-tested

# GOOD (concrete)
- [ ] `./gradlew test` passes with zero failures
- [ ] Every test seen failing before passing
```

### Anticipate Rationalizations

Every skill should include the shortcuts agents are most likely to attempt. The "Common Rationalizations" table is not optional — it's one of the most valuable sections.

### Write the Procedure, Not the Workaround

Skills run on many agents and model generations. A step that exists because one model gets a specific call wrong is a liability on every other model: it constrains agents that would have solved the task directly, and it spends turns stronger models need for the actual work.

**The rule:** if a step can't be justified without naming a model, a model version, or one agent's private tool name, it belongs in an issue, not in a skill. Describe the capability ("run the module's unit tests", "write the file"), not the mechanism one runtime happens to expose.

Two smells to check before proposing skill content:

- **Over-specified mechanics.** Prescribing an exact command form or serialization detail where stating the goal would do. If the justification is "model X gets this wrong otherwise", it's a workaround, not a procedure.
- **Fragmented diagnostics.** A multi-step inspection sequence where one step would confirm the same thing. Every extra step spends turns, and turn budget is finite.

## Shared References

Checklists used by more than one skill (testing, security, performance, accessibility, the Android CLI) live in `references/` at the repository root, not inside any skill. Material used by exactly one skill lives in that skill's own directory (e.g. `skills/constraint-driven-development/references/floor-guard.md`).

Paths resolve from the file that names them. From a `SKILL.md`, a shared checklist is `../../references/<file>.md`; a skill's own file is `references/<file>.md`. Writing `references/security-checklist.md` in a `SKILL.md` points at a file that doesn't exist — the validator fails on it.

The tradeoff is portability: a whole-repo install (the Claude Code plugin) carries `references/` along, but an install that copies only `skills/<name>/` leaves the shared checklists behind.

## Sizing Guide

- Target: **under 500 lines** per SKILL.md
- If a skill exceeds 500 lines, consider:
  - Splitting into two skills
  - Moving detailed examples to `examples.md`
  - Moving reference data to the skill's own `references/` (see [Shared References](#shared-references))
  - Removing redundant sections

## Description Writing Guide

The `description` field appears in system prompts for skill matching. Write it to communicate:

1. **When to trigger** — "Use when implementing new features or fixing bugs"
2. **What it does** — "Guides Red-Green-Refactor with JUnit5 and MockK"

```yaml
# GOOD: specific triggers + clear purpose
description: >-
  Use when building UI with Jetpack Compose. Covers component design,
  state hoisting, recomposition optimization, Material 3 theming,
  Navigation Compose, previews, and XML interop.

# BAD: vague, doesn't help with matching
description: >-
  A skill about Android UI development.
```

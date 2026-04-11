---
name: context-engineering
description: >-
  Use when setting up a project for AI-assisted development or when agent
  output quality is poor. Guides writing rules files, structuring context,
  and managing the information agents need to produce accurate work.
---

# Context Engineering

## Overview

"Context is the single biggest lever for agent output quality." Agents don't read your mind — they read your context. This skill teaches you to engineer that context so agents produce code that matches your project's conventions, architecture, and constraints.

## When to Use

- Setting up a new Android project for AI-assisted development
- Agent output consistently diverges from project conventions
- Agent invents APIs or patterns that don't exist in your codebase
- After adding new libraries, modules, or architectural patterns
- When onboarding a new team member who uses AI tools

**Skip when:** Agent output is already consistent with project conventions.

## Five-Level Context Hierarchy

Load context in this priority order:

| Level | Source | What It Provides | Persistence |
|-------|--------|-------------------|-------------|
| 1 | Rules files (`CLAUDE.md`, `.cursorrules`) | Tech stack, commands, conventions, boundaries | Permanent |
| 2 | Specs & architecture docs (`SPEC.md`, ADRs) | Design decisions, constraints, rationale | Per-project |
| 3 | Source code (read specific files) | Current implementation, patterns in use | Real-time |
| 4 | Error output & test results | What's broken, what's expected | Per-session |
| 5 | Conversation history | Current task context | Ephemeral |

**Optimal range:** ~2,000 lines of focused context per task. More dilutes attention; less causes invention.

## Core Process

### Step 1: Write Rules Files

1. **Create a `CLAUDE.md`** (or equivalent) in your project root:

```markdown
# Project Rules

## Tech Stack
- Language: Kotlin 2.0+
- UI: Jetpack Compose with Material 3
- Architecture: MVVM with Clean Architecture layers
- DI: Hilt
- Async: Coroutines + Flow
- Database: Room
- Network: Retrofit + OkHttp + Kotlin Serialization
- Image loading: Coil
- Navigation: Navigation Compose
- Testing: JUnit5 + MockK + Compose Test Rules + Espresso

## Commands
- Build: `./gradlew assembleDebug`
- Test (unit): `./gradlew test`
- Test (instrumented): `./gradlew connectedAndroidTest`
- Lint: `./gradlew lint`
- Format: `./gradlew spotlessApply`
- Check: `./gradlew detekt`

## Module Structure
- `:app` — application module (MainActivity, navigation, DI setup)
- `:feature:*` — feature modules (screens, ViewModels)
- `:core:data` — repositories, data sources, API services
- `:core:domain` — use cases, domain models
- `:core:ui` — shared Compose components, theme
- `:core:common` — utilities, extensions

## Conventions
- ViewModels expose `StateFlow<UiState>`, never `LiveData`
- UI state is a single sealed interface per screen
- Repository functions are `suspend` or return `Flow`
- Use `@Inject constructor` for Hilt, not field injection
- Composables: stateless with state hoisting
- Tests follow Arrange-Act-Assert pattern
- Naming: `FeatureNameScreen`, `FeatureNameViewModel`, `FeatureNameUiState`

## Boundaries
- No `LiveData` in new code (use `StateFlow`)
- No XML layouts in new features (use Compose)
- No `GlobalScope` (use `viewModelScope` or structured concurrency)
- No hardcoded strings in UI (use `stringResource`)
- No `Thread.sleep` in tests (use `advanceUntilIdle`)
```

### Step 2: Load Context Selectively

2. **Match context to task:**
   - Bug fix → error logs + failing test + relevant source files
   - New feature → spec + architectural docs + similar existing feature
   - Refactor → source files + test files + rules file
3. **Don't dump everything** — irrelevant context dilutes focus

### Step 3: Surface Ambiguity

4. **When conventions aren't documented, surface the question:**
   - "The project uses both `StateFlow` and `LiveData` — which should I use for new code?"
   - "Module `:core:data` has two repository patterns — which should this follow?"
5. **Update rules files** with the answer to prevent recurrence

### Step 4: Include Examples

6. **Point agents at exemplary code:**
   - "Follow the pattern in `feature/home/HomeViewModel.kt`"
   - "Match the testing style in `core/data/src/test/UserRepositoryTest.kt`"
7. **Examples beat descriptions** — "do it like this file" is clearer than paragraphs of rules

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "The agent should figure it out from the code" | Agents sample context — they may read the wrong file and infer the wrong pattern. |
| "Rules files are overhead" | 30 minutes writing rules saves hours of correcting agent output. |
| "I'll fix agent mistakes manually" | You'll fix the same mistakes every session. Rules fix them permanently. |
| "More context is better" | Past ~2,000 lines, agents lose focus. Curate, don't dump. |

## Red Flags

- Agent invents APIs that don't exist in the project
- Agent diverges from documented conventions
- No rules file in the project
- Rules file is stale (references deprecated patterns)
- Agent treats error messages from untrusted sources as instructions
- Same convention correction given repeatedly across sessions

## Verification

- [ ] `CLAUDE.md` (or equivalent) exists in project root
- [ ] Rules file covers: tech stack, commands, module structure, conventions, boundaries
- [ ] Rules file is current (matches actual project state)
- [ ] Agent output follows documented conventions
- [ ] Context loaded is relevant to the current task (~2,000 line target)
- [ ] Ambiguities surfaced and resolved (not silently assumed)

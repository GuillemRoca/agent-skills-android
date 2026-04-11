# AGENTS.md — Agent Skills for Android

## Skill-First Execution Model

When working on an Android project with agent skills installed, **always check for a matching skill before implementing directly**. Skills provide battle-tested workflows that prevent common mistakes.

## Structured Lifecycle

Work follows a five-phase lifecycle. Each phase has dedicated skills:

```
DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP
```

| Phase | Skills | Purpose |
|-------|--------|---------|
| **DEFINE** | `idea-refine`, `spec-driven-development`, `context-engineering` | Sharpen ideas, write specs, set up AI context |
| **PLAN** | `planning-and-task-breakdown`, `android-architecture` | Break work into tasks, make architecture decisions |
| **BUILD** | `incremental-implementation`, `test-driven-development`, `android-ui-engineering`, `android-data-persistence`, `api-and-interface-design`, `source-driven-development`, `code-simplification`, `documentation-and-adrs` | Implement incrementally with TDD |
| **VERIFY** | `android-device-testing`, `android-accessibility`, `debugging-and-error-recovery`, `performance-optimization` | Test, debug, and validate |
| **REVIEW** | `code-review-and-quality`, `security-and-hardening` | Review quality and security |
| **SHIP** | `ci-cd-and-automation`, `git-workflow-and-versioning`, `shipping-and-launch`, `deprecation-and-migration` | Automate, version, and release |

## Skill Directory Structure

Skills live in `skills/{skill-name}/SKILL.md`:

```
skills/
├── idea-refine/SKILL.md
├── spec-driven-development/SKILL.md
├── planning-and-task-breakdown/SKILL.md
├── android-architecture/SKILL.md
├── android-ui-engineering/SKILL.md
├── android-data-persistence/SKILL.md
├── android-accessibility/SKILL.md
├── android-device-testing/SKILL.md
├── test-driven-development/SKILL.md
├── incremental-implementation/SKILL.md
├── code-review-and-quality/SKILL.md
├── debugging-and-error-recovery/SKILL.md
├── api-and-interface-design/SKILL.md
├── performance-optimization/SKILL.md
├── security-and-hardening/SKILL.md
├── ci-cd-and-automation/SKILL.md
├── deprecation-and-migration/SKILL.md
├── git-workflow-and-versioning/SKILL.md
├── shipping-and-launch/SKILL.md
├── code-simplification/SKILL.md
├── context-engineering/SKILL.md
├── documentation-and-adrs/SKILL.md
├── source-driven-development/SKILL.md
└── using-agent-skills/SKILL.md
```

## SKILL.md Anatomy

Each skill follows this structure:

```yaml
---
name: skill-name-in-kebab-case
description: Brief description. Use when [trigger conditions].
---
```

Sections:
1. **Overview** — what and why
2. **When to Use** — trigger conditions and exclusions
3. **Core Process** — numbered steps with Kotlin code examples
4. **Common Rationalizations** — excuses agents use to skip steps + rebuttals
5. **Red Flags** — observable violations during review
6. **Verification** — exit checklist requiring tangible evidence

Target: each SKILL.md stays under 500 lines.

## Agent Personas

Three reusable agent personas in `agents/`:

| Agent | Role | Use When |
|-------|------|----------|
| `code-reviewer.md` | Five-axis code review (Correctness, Readability, Architecture, Security, Performance) | Reviewing PRs or self-reviewing |
| `test-engineer.md` | Test design, coverage analysis, quality evaluation | Designing test suites, finding coverage gaps |
| `security-auditor.md` | OWASP Mobile Top 10, vulnerability assessment | Security review before release |

## Slash Commands

Seven commands map to development phases:

| Command | Phase | Skills Used |
|---------|-------|-------------|
| `/spec` | DEFINE | `spec-driven-development` |
| `/plan` | PLAN | `planning-and-task-breakdown` |
| `/build` | BUILD | `incremental-implementation` + `test-driven-development` |
| `/test` | VERIFY | `test-driven-development` + `android-device-testing` |
| `/review` | REVIEW | `code-review-and-quality` + `security-and-hardening` + `performance-optimization` |
| `/code-simplify` | BUILD | `code-simplification` + `code-review-and-quality` |
| `/ship` | SHIP | `shipping-and-launch` |

## Reference Checklists

Detailed checklists in `references/`:

- `testing-patterns.md` — JUnit5, MockK, Espresso, Compose tests, MockWebServer
- `security-checklist.md` — OWASP Mobile, Network Security Config, cert pinning, secrets
- `performance-checklist.md` — Android Vitals, Baseline Profiles, Macrobenchmark, APK size
- `accessibility-checklist.md` — TalkBack, Accessibility Scanner, touch targets, contrast

## Installation

### Claude Code

```bash
# 1. Add the marketplace (one-time setup)
claude plugin marketplace add GuillemRoca/agent-skills-android

# 2. Install the plugin
claude plugin install agent-skills-android
```

Restart Claude Code after installation.

### Manual Setup

1. Clone this repo alongside your project
2. Reference skills in your `CLAUDE.md`:
   ```
   See ../agent-skills-android/skills/ for Android engineering workflow skills.
   ```

## Core Principles

1. **Skills are workflows, not suggestions** — follow steps in order, never skip verification
2. **Anti-rationalizations are real** — check the "Common Rationalizations" table before skipping steps
3. **Evidence over assertions** — "it looks right" is not verification
4. **Assumption surfacing** — state assumptions explicitly before implementing
5. **Scope discipline** — only modify what's requested

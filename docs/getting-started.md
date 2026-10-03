# Getting Started with Agent Skills for Android

## What Are Skills?

Skills are Markdown files (`SKILL.md`) that describe engineering workflows for AI coding agents. Unlike general advice, skills provide:

- **Step-by-step processes** with numbered actions
- **Kotlin code examples** for Android patterns
- **Anti-rationalizations** — rebuttals for common shortcuts
- **Verification checklists** requiring tangible evidence

Agents don't just read skills — they **implement** complete workflows including verification and anti-pattern detection.

## Quick Start

### 1. Install

```bash
# As a Claude Code plugin (recommended)
claude plugin marketplace add GuillemRoca/claude-plugins
claude plugin install agent-skills-android@guillemroca

# Or clone alongside your project
git clone https://github.com/GuillemRoca/agent-skills-android.git
```

Restart Claude Code after plugin installation.

### 2. Start with These Three Skills

If you're new, start with the foundational three:

| Skill | Why |
|-------|-----|
| `spec-driven-development` | Write specs before code — prevents misalignment |
| `test-driven-development` | Write tests before implementation — prevents regressions |
| `code-review-and-quality` | Systematic review — catches issues before merge |

### 3. Use Slash Commands

The fastest way to invoke a workflow:

```
/spec    → Write a specification for your feature
/constraints → Set the project's quality bar (CONSTRAINTS.md) once
/plan    → Break the spec into implementation tasks
/build   → Implement the next task with TDD
/test    → Write tests for new features or bug fixes
/review  → Review code across five axes
/ship    → Pre-launch checklist before release
```

## How Skills Work

### Skill Loading

Skills are loaded contextually — only the skill relevant to your current task is active:

1. **Discovery:** Hosts that route skills natively (Claude Code, Codex CLI) activate skills from their descriptions — including `using-agent-skills` and its discovery flowchart — so nothing is injected at session start. On hosts without native routing, load `using-agent-skills` up front (see [Hooks](#hooks-hooks))
2. **Task matching:** Based on your request, the agent selects the appropriate skill
3. **Workflow execution:** The agent follows the skill's process step by step
4. **Verification:** Each skill ends with a checklist — no step is "done" without evidence

### Skill Anatomy

Every skill follows the same structure:

```yaml
---
name: skill-name
description: Use when [trigger]. [What it does].
---

# Skill Title

## Overview
## When to Use
## Core Process
## Common Rationalizations
## Red Flags
## Verification
```

See [skill-anatomy.md](skill-anatomy.md) for the full specification.

## Supporting Infrastructure

### Agent Personas (`agents/`)

Three reusable personas for specialized reviews:

- **code-reviewer.md** — evaluates Correctness, Readability, Architecture, Security, Performance
- **test-engineer.md** — designs test suites, finds coverage gaps
- **security-auditor.md** — OWASP Mobile Top 10 vulnerability assessment

### Reference Checklists (`references/`)

Detailed checklists for deep-dive reviews:

- `testing-patterns.md` — test framework patterns and anti-patterns
- `security-checklist.md` — comprehensive Android security checklist
- `performance-checklist.md` — Android Vitals targets and optimization
- `accessibility-checklist.md` — TalkBack, contrast, touch targets

### Hooks (`hooks/`)

Opt-in automation hooks. The plugin registers none of them; wire the ones you want into your host's hook settings:

- `session-start.sh` — injects the `using-agent-skills` meta-skill at session start. Only for hosts **without** native skill routing: on Claude Code or Codex CLI it would run a second router on top of the native one, so don't wire it there. Emits the standard `hookSpecificOutput.additionalContext` SessionStart envelope; `session-start-test.sh` checks it
- `simplify-ignore.sh` — protects annotated code blocks from `/code-simplify`

If your host already discovers skills from their descriptions, don't paste `using-agent-skills` into an always-on system prompt or rules file either — that creates the same two-routers problem.

## Development Lifecycle

Skills map to a structured lifecycle. Use the skill discovery flowchart in `using-agent-skills` to find the right skill for your task:

```
DEFINE: idea-refine → spec-driven-development
  ↓
PLAN: planning-and-task-breakdown → android-architecture
  ↓
BUILD: incremental-implementation + test-driven-development
       android-ui-engineering, android-data-persistence
  ↓
VERIFY: android-device-testing, android-accessibility
        debugging-and-error-recovery, performance-optimization
  ↓
REVIEW: code-review-and-quality, security-and-hardening
  ↓
SHIP: ci-cd-and-automation → git-workflow-and-versioning → shipping-and-launch
```

## Tips

1. **Load skills contextually** — don't load all 29 at once. Load the one for your current task.
2. **Follow the process** — skills are workflows, not suggestions. Follow steps in order.
3. **Don't skip verification** — every skill ends with a checklist. Complete it.
4. **Check rationalizations** — before skipping a step, check the "Common Rationalizations" table.
5. **Surface assumptions** — state assumptions explicitly before implementing.

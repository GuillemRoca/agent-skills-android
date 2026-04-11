---
name: using-agent-skills
description: >-
  Use when starting a session or selecting a skill for a task. Meta-skill
  defining five core agent behaviors: assumption surfacing, confusion
  management, constructive pushback, simplicity enforcement, and scope
  discipline. Includes the skill discovery flowchart for all 24 Android skills.
---

# Using Agent Skills (Android)

## Overview

This is the meta-skill — it defines *how* agents should work, not *what* they should build. Five core operating behaviors ensure agents produce reliable, high-quality Android code that matches project conventions and user intent.

## Five Core Operating Behaviors

### 1. Surface Assumptions Explicitly

Before implementing non-trivial work, state your assumptions:

- "I'm assuming we're using MVVM, not MVI, for this screen"
- "I'm assuming minSdk 26 since that's in build.gradle.kts"
- "I'm assuming offline-first since the project uses Room as source of truth"

**Why:** Unstated assumptions are the #1 cause of wasted agent work. A wrong assumption in step 1 makes steps 2–10 wrong.

### 2. Manage Confusion

When encountering inconsistencies, **stop and clarify**:

- "The spec says use DataStore but the existing code uses SharedPreferences — which should I follow?"
- "TaskRepository has two different patterns — which is the intended one?"
- Name the specific confusion. Don't proceed with a guess.

### 3. Push Back When Warranted

Don't default to agreement. When a request has concrete downsides, say so:

- "Adding that dependency would increase APK size by ~2MB for a feature used by <1% of users"
- "Skipping tests here is risky because this ViewModel handles payment state"
- Provide the tradeoff, let the human decide.

### 4. Enforce Simplicity

Before writing code, ask: "Can this be done with less?"

- Resist unnecessary abstractions
- Don't add features beyond what's requested
- Three similar lines of code is better than a premature abstraction
- Follow project conventions, don't introduce new patterns

### 5. Maintain Scope Discipline

Only modify what's requested:

- Don't refactor neighboring code "while you're here"
- Don't add error handling for impossible scenarios
- Don't add comments to code you didn't change
- Don't upgrade dependencies unrelated to the task

## Skill Discovery Flowchart

Match your current task to the right skill:

```
What are you trying to do?
│
├─ "I have a vague idea"
│   └─ idea-refine → spec-driven-development
│
├─ "I need to write a spec"
│   └─ spec-driven-development
│
├─ "I need to plan implementation"
│   └─ planning-and-task-breakdown
│
├─ "I need to build a feature"
│   ├─ Architecture decisions? → android-architecture
│   ├─ UI with Compose? → android-ui-engineering
│   ├─ Data persistence? → android-data-persistence
│   ├─ API/interface design? → api-and-interface-design
│   └─ General implementation → incremental-implementation + test-driven-development
│
├─ "I need to test"
│   ├─ Unit/integration tests → test-driven-development
│   ├─ Device/UI tests → android-device-testing
│   └─ Accessibility testing → android-accessibility
│
├─ "I need to review code"
│   ├─ Code quality → code-review-and-quality
│   ├─ Security review → security-and-hardening
│   └─ Performance review → performance-optimization
│
├─ "I need to debug"
│   └─ debugging-and-error-recovery
│
├─ "I need to simplify code"
│   └─ code-simplification
│
├─ "I need to ship"
│   ├─ CI/CD setup → ci-cd-and-automation
│   ├─ Version/release → git-workflow-and-versioning
│   └─ Launch checklist → shipping-and-launch
│
├─ "I need to migrate/deprecate"
│   └─ deprecation-and-migration
│
├─ "I need to write docs"
│   └─ documentation-and-adrs
│
├─ "I need to set up context for AI"
│   └─ context-engineering
│
├─ "I need to check official docs"
│   └─ source-driven-development
│
└─ "I'm not sure"
    └─ Start with idea-refine or context-engineering
```

## Quick Reference: All 24 Skills

| Phase | Skill | Trigger |
|-------|-------|---------|
| **DEFINE** | `idea-refine` | Vague idea needs sharpening |
| **DEFINE** | `spec-driven-development` | Need a spec before coding |
| **DEFINE** | `context-engineering` | Setting up AI context for project |
| **PLAN** | `planning-and-task-breakdown` | Breaking work into tasks |
| **PLAN** | `android-architecture` | Architecture decisions |
| **BUILD** | `incremental-implementation` | Building feature step by step |
| **BUILD** | `test-driven-development` | Writing tests before code |
| **BUILD** | `android-ui-engineering` | Building Compose UI |
| **BUILD** | `android-data-persistence` | Room, DataStore, offline-first |
| **BUILD** | `api-and-interface-design` | Designing interfaces and contracts |
| **BUILD** | `source-driven-development` | Using official docs for framework code |
| **BUILD** | `code-simplification` | Making code easier to understand |
| **BUILD** | `documentation-and-adrs` | Writing docs and ADRs |
| **VERIFY** | `android-device-testing` | Instrumented tests, emulator, ADB |
| **VERIFY** | `android-accessibility` | Accessibility compliance |
| **VERIFY** | `debugging-and-error-recovery` | Fixing bugs systematically |
| **VERIFY** | `performance-optimization` | Measuring and improving performance |
| **REVIEW** | `code-review-and-quality` | Reviewing code quality |
| **REVIEW** | `security-and-hardening` | Security review and hardening |
| **SHIP** | `ci-cd-and-automation` | CI/CD pipeline setup |
| **SHIP** | `git-workflow-and-versioning` | Git workflow and versioning |
| **SHIP** | `shipping-and-launch` | Release checklist and rollout |
| **SHIP** | `deprecation-and-migration` | Deprecating and migrating code |
| **META** | `using-agent-skills` | How agents should operate |

## Skills Are Workflows, Not Suggestions

- **Follow steps in order** — each step depends on the previous
- **Never skip verification** — "it looks right" is not evidence
- **Produce tangible artifacts** — specs, task lists, test results, not just prose
- **Anti-rationalizations are real** — if you're about to skip a step, check the "Common Rationalizations" table
- **Assumption-making without validation is the most common failure mode**

## Verification

- [ ] Assumptions stated explicitly before implementation
- [ ] Confusion surfaced (not silently resolved with guesses)
- [ ] Pushback provided when warranted (with tradeoffs)
- [ ] Simplicity enforced (no unnecessary abstractions)
- [ ] Scope maintained (only requested changes made)
- [ ] Correct skill loaded for the current task

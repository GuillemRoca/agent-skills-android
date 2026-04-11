# OpenCode Setup

## Overview

OpenCode uses a prompt-driven architecture with three components working together:

1. **AGENTS.md** — system prompt guiding agent behavior and skill selection
2. **Skills directory** — `skills/` folder with individual skill definitions
3. **Automatic skill routing** — the agent selects skills based on your intent

## Setup

```bash
# Clone the repo alongside your project
git clone https://github.com/GuillemRoca/agent-skills-android.git

# Copy the essentials into your project
cp agent-skills-android/AGENTS.md your-project/AGENTS.md
cp -r agent-skills-android/skills your-project/skills
cp -r agent-skills-android/agents your-project/agents
cp -r agent-skills-android/references your-project/references
```

Ensure `AGENTS.md` and the `skills/` directory are at your project root.

## How It Works

Skills are selected automatically based on intent — you don't invoke them manually:

| Your Request | Skills Selected |
|-------------|----------------|
| "Add a task list feature" | `spec-driven-development` → `planning-and-task-breakdown` → `incremental-implementation` |
| "Fix this crash" | `debugging-and-error-recovery` → `test-driven-development` (Prove-It pattern) |
| "Review this code" | `code-review-and-quality` → `security-and-hardening` |
| "Build the settings screen" | `android-ui-engineering` → `android-architecture` |
| "Set up Room database" | `android-data-persistence` → `test-driven-development` |
| "Prepare for release" | `shipping-and-launch` → `ci-cd-and-automation` |

The lifecycle is encoded implicitly through skill selection:

```
DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP
```

## Best Practices

- Communicate needs naturally — the agent handles skill selection
- The agent must comply with rules in `AGENTS.md`
- Skills are workflows the agent follows, not reference docs it reads
- The agent checks skill applicability before acting and refuses to bypass required phases (specification, testing)

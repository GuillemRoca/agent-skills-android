# Gemini CLI Setup

## Skills Directory (Recommended)

Copy skills into Gemini's auto-discovery directory:

```bash
# Clone the repo
git clone https://github.com/GuillemRoca/agent-skills-android.git

# Copy skills into Gemini's directory
mkdir -p your-project/.gemini/skills
cp -r agent-skills-android/skills/* your-project/.gemini/skills/
```

Skills in `.gemini/skills/` activate on-demand when relevant to the task.

Verify installation:

```bash
/skills list
```

Reference skills explicitly in prompts with `@skills/[name]/SKILL.md`.

## GEMINI.md (Persistent Context)

For skills you want loaded in every session, add them to your project's `GEMINI.md`:

```markdown
# Android Development Rules

## Always Active
<!-- Paste content from incremental-implementation/SKILL.md -->
<!-- Paste content from code-review-and-quality/SKILL.md -->

## Reference
See .gemini/skills/ for additional Android engineering workflow skills.
Load the appropriate skill for your current task.
```

## Recommended Setup

| Loading Strategy | Skills | Reason |
|-----------------|--------|--------|
| **Persistent** (GEMINI.md) | `incremental-implementation`, `code-review-and-quality` | Used in every session |
| **On-demand** (.gemini/skills/) | `test-driven-development` | Logic and bug fixes |
| **On-demand** | `spec-driven-development` | New projects or features |
| **On-demand** | `android-ui-engineering` | Compose UI work |
| **On-demand** | `android-architecture` | Architecture decisions |
| **On-demand** | `security-and-hardening` | Security reviews |
| **On-demand** | `performance-optimization` | Performance work |

## Key Distinction

Skills are on-demand expertise that activate only when relevant, keeping your context window clean. `GEMINI.md` provides persistent context loaded for every prompt. Use both strategically — persistent for core practices, on-demand for specialized workflows.

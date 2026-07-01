# Contributing to Agent Skills Android

Thank you for contributing! This guide ensures consistency across skills.

## Adding a New Skill

### 1. Create the directory

```bash
mkdir skills/your-skill-name
```

Use **kebab-case** for the directory name.

### 2. Write SKILL.md

Create `skills/your-skill-name/SKILL.md` with this structure:

```yaml
---
name: your-skill-name
description: >-
  Use when [specific trigger conditions]. [What the skill does in one sentence].
---
```

**Required sections:**

1. **Overview** — elevator pitch (2–3 sentences)
2. **When to Use** — specific trigger conditions + explicit exclusions ("Skip when:")
3. **Core Process** — numbered steps with Kotlin code examples
4. **Common Rationalizations** — table of shortcuts agents attempt + why they fail
5. **Red Flags** — observable violations during review
6. **Verification** — checklist of tangible evidence (not "looks correct")

> **Meta-skill exemption:** `using-agent-skills` is the one deliberate exception to
> this anatomy. It documents *how agents operate across all skills* (operating
> behaviors + skill routing), so it keeps only **Overview** and **Verification**.
> Every other skill — including new ones — must carry all six sections.

### 3. Follow these rules

**YAML Frontmatter:**
- `name`: lowercase, hyphen-separated, matches directory name
- `description`: starts with "Use when", under 1024 characters, explains *what* and *when*

**Content Quality:**
- **Specific** — actionable steps, not general advice
- **Verifiable** — every process ends with tangible evidence
- **Battle-tested** — patterns that work in production, not theory
- **Minimal** — under 500 lines per SKILL.md

**Code Examples:**
- All code examples in **Kotlin** (not Java, not JavaScript)
- Build commands use `./gradlew` (not `npm`, `yarn`, etc.)
- Frameworks: Jetpack Compose, Room, Hilt, Coroutines/Flow, Material 3
- Test frameworks: JUnit5, MockK, Espresso, Compose test rules

**Cross-references:**
- Reference related skills by name: "see `android-device-testing`"
- Don't duplicate content — link to the related skill instead
- Reference checklists in `references/` for detailed lists

## Modifying an Existing Skill

1. Read the entire SKILL.md first
2. Maintain the existing section structure
3. Keep code examples current with latest library versions
4. Verify the description still matches the content
5. Update cross-references if skill names changed

## Supporting Files

Skills can include optional supporting files:

```
skills/your-skill-name/
├── SKILL.md          # Required
├── examples.md       # Optional: worked examples
├── scripts/          # Optional: automation scripts
└── templates/        # Optional: template files
```

Keep supporting files minimal. Most skills need only SKILL.md.

## Testing Your Skill

Run the validator first — it enforces the structural rules automatically and runs in CI on every PR:

```bash
./scripts/validate-skills.sh
```

It checks: frontmatter (`name` matches the kebab-case directory, ≤64 chars; `description` starts with "Use when", ≤1024 chars), the six required sections (meta-skill exempt), the 500-line cap, and that `AGENTS.md`/`README.md` skill tables list exactly the skills on disk.

Then review by hand:

1. **Description trigger** — does it clearly state when to use?
2. **Code examples compile** — Kotlin syntax is correct
3. **Verification checklist** — are items tangible and verifiable?
4. **Anti-rationalizations** — do rebuttals address real shortcuts?

## Style Guide

- Use imperative voice: "Write the test" not "The test should be written"
- Use Kotlin code blocks with type annotations where helpful
- Use tables for comparisons and mappings
- Use checklists (`- [ ]`) for verification sections
- No emojis unless they add clarity
- No marketing language — be direct and technical

## Pull Request Process

1. Create a branch: `skill/your-skill-name` or `fix/skill-name-issue`
2. Follow the structure and quality standards above
3. Ensure no web-specific language leaks (no npm, React, Playwright, etc.)
4. Submit a PR with a description of what the skill covers and when to use it

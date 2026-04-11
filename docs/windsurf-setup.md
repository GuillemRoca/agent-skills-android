# Windsurf Setup

## Project-Level Rules (Recommended)

Create a `.windsurfrules` file at your project root combining the most critical skills:

```bash
# Clone the repo
git clone https://github.com/GuillemRoca/agent-skills-android.git

# Combine 2-3 essential skills into .windsurfrules
cat agent-skills-android/skills/test-driven-development/SKILL.md > your-project/.windsurfrules
echo -e "\n---\n" >> your-project/.windsurfrules
cat agent-skills-android/skills/incremental-implementation/SKILL.md >> your-project/.windsurfrules
echo -e "\n---\n" >> your-project/.windsurfrules
cat agent-skills-android/skills/code-review-and-quality/SKILL.md >> your-project/.windsurfrules
```

## Global Rules

For skills you want across all projects:

1. Open Windsurf Settings → AI → Global Rules
2. Paste the content of your most-used skills (e.g., `test-driven-development`, `code-review-and-quality`)

## Best Practices

- Keep `.windsurfrules` to 2–3 skills — Windsurf's context is limited
- Prioritize skills that address your biggest quality gaps
- Reference additional skills contextually during relevant phases:
  - Paste `security-and-hardening` content when building authentication
  - Paste `android-ui-engineering` content when working on Compose screens
  - Paste `performance-optimization` content when profiling
- Use reference checklists by asking Windsurf to validate against `references/*.md`

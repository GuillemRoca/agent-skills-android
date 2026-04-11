# GitHub Copilot Setup

## Skills Directory

Organize skills in your repository:

```bash
# Clone the repo
git clone https://github.com/GuillemRoca/agent-skills-android.git

# Copy skills into your project
mkdir -p your-project/.github/skills
cp -r agent-skills-android/skills/* your-project/.github/skills/
```

## Copilot Instructions

Create `.github/copilot-instructions.md` with your project's coding standards:

```markdown
# Android Development Standards

## Architecture
- MVVM with Clean Architecture layers (UI → Domain → Data)
- Hilt for dependency injection (constructor injection only)
- ViewModels expose StateFlow, never MutableStateFlow or LiveData

## Testing
- Write tests before implementation (Red-Green-Refactor)
- JUnit5 + MockK for unit tests
- Compose test rules for UI tests
- No Thread.sleep in tests — use advanceUntilIdle()

## Code Quality
- Kotlin idioms: when expressions, sealed classes, extension functions
- Functions under 40 lines
- Handle all UI states: loading, success, error, empty

## Build Commands
- Build: ./gradlew assembleDebug
- Test: ./gradlew test
- Lint: ./gradlew lint

## Reference
See .github/skills/ for detailed workflow skills.
```

## Agent Personas

Use agent personas for targeted reviews in Copilot Chat:

- Reference `agents/code-reviewer.md` for five-axis code review
- Reference `agents/test-engineer.md` for test design and coverage analysis
- Reference `agents/security-auditor.md` for OWASP Mobile Top 10 auditing

## Best Practices

- Keep instructions concise — focus on rules, not explanations
- Leverage agent personas for specialized review workflows
- Reference specific skill content when working on particular development phases
- Integrate Copilot reviews into your existing PR process

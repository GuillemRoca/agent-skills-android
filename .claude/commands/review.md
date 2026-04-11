# /review — Code Review

Review code across five axes with categorized findings.

## Instructions

Load and follow these skills:
- `code-review-and-quality` from `skills/code-review-and-quality/SKILL.md`
- `security-and-hardening` from `skills/security-and-hardening/SKILL.md`
- `performance-optimization` from `skills/performance-optimization/SKILL.md`

### Five-Axis Review

#### 1. Correctness
- All UI states handled? (loading, success, error, empty)
- Nulls handled safely? (no `!!`, proper safe calls)
- Coroutines structured correctly? (scope, cancellation)
- Room queries match schema? Migrations correct?

#### 2. Readability
- Kotlin idioms used? (when, sealed classes, extension functions)
- Clear naming? Functions < 40 lines?
- Consistent with existing codebase patterns?

#### 3. Architecture
- Layer boundaries respected? (UI → Domain → Data)
- StateFlow exposed (not MutableStateFlow)?
- Constructor injection (not field injection)?
- No business logic in Composables?

#### 4. Security
- No hardcoded secrets?
- Input validated at boundaries?
- Exported components permission-protected?
- No sensitive data in logs?

#### 5. Performance
- No N+1 queries?
- Heavy work off main thread?
- Compose recompositions optimized?
- Large datasets paginated?

### Finding Categories

| Category | Action |
|----------|--------|
| **Critical** | Must fix before merge |
| **Important** | Should fix before merge |
| **Suggestion** | Optional improvement |
| **Nit** | Formatting preference |
| **FYI** | Context, no action needed |

### Verification

Run before approving:
```bash
./gradlew test
./gradlew assembleDebug
./gradlew lint
```

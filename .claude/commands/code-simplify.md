# /code-simplify — Code Simplification

Simplify code incrementally while preserving behavior exactly.

## Instructions

Load and follow these skills:
- `code-simplification` from `skills/code-simplification/SKILL.md`
- `code-review-and-quality` from `skills/code-review-and-quality/SKILL.md`

### Before Starting

1. Read `CLAUDE.md` (if it exists) to understand project conventions
2. Read the target file and its tests
3. Check git blame for context on complex sections
4. Respect `/* simplify-ignore-start */` blocks — skip them

### Common Simplifications

| Pattern | Kotlin Simplification |
|---------|----------------------|
| Deep nesting | Early returns, `when` expressions |
| Long functions | Extract well-named private functions |
| Complex conditionals | `when` expression or sealed class |
| Nullable chains | `?.let { }`, `?:`, safe calls |
| Manual null checks | `requireNotNull()`, `checkNotNull()` |
| Mutable state | `val` over `var`, immutable collections |
| Callback nesting | Coroutines / Flow |
| Type casting chains | `is` smart casts, sealed hierarchies |

### Process

For each simplification:
1. Make one change
2. Run `./gradlew test` — must pass
3. If tests fail, **revert immediately**
4. Commit the change
5. Repeat

### Rules

- Preserve behavior exactly (change form, not function)
- One simplification per commit
- Don't simplify code you don't understand (Chesterton's Fence)
- Don't mix simplification with feature changes
- Simpler means easier to understand, not necessarily shorter

### Final Check

After all simplifications:
```bash
./gradlew test
./gradlew assembleDebug
./gradlew lint
```

Review the full diff — does it only change form, not behavior?

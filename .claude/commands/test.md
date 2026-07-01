# /test — Test-Driven Development

Write tests before implementation using Red-Green-Refactor.

## Instructions

Load and follow these skills:
- `test-driven-development` from `skills/test-driven-development/SKILL.md`
- `android-device-testing` from `skills/android-device-testing/SKILL.md` (for instrumented tests)
- `android-e2e-verification` from `skills/android-e2e-verification/SKILL.md` (for end-to-end acceptance flows)

### New Feature Testing

1. **Write failing test** describing the expected behavior
2. **Run test** — confirm it FAILS (RED)
3. **Write minimal code** to make it pass (GREEN)
4. **Run full suite** — `./gradlew test`
5. **Refactor** while tests stay green
6. **Repeat** for next behavior

### Bug Fix Testing (Prove-It Pattern)

1. **Write a test** that demonstrates the bug
2. **Run test** — confirm it FAILS (proves bug exists)
3. **Fix the code**
4. **Run test** — confirm it PASSES (proves fix works)
5. **Run full suite** — `./gradlew test` (no regressions)

### Test Types

| Type | Framework | Command |
|------|-----------|---------|
| Unit tests | JUnit5 + MockK | `./gradlew test` |
| Compose UI tests | Compose test rules | `./gradlew connectedAndroidTest` |
| Espresso tests | Espresso | `./gradlew connectedAndroidTest` |
| Room DAO tests | In-memory Room | `./gradlew connectedAndroidTest` |
| Screenshot tests | Preview Screenshot Testing / Roborazzi | `./gradlew validateDebugScreenshotTest` |
| E2E acceptance flows | Maestro | `maestro test .maestro/` |

### Rules

- Tests BEFORE implementation (always)
- Every test must be seen failing before passing
- No `Thread.sleep` — use `advanceUntilIdle()` or `waitUntil`
- Mock at boundaries only (DAO, API), not internal classes
- Descriptive test names that read like behavior specs

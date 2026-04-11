# /spec — Spec-Driven Development

Write a structured specification before writing any code.

## Instructions

Load and follow the `spec-driven-development` skill from `skills/spec-driven-development/SKILL.md`.

### Clarifying Questions

Before writing the spec, ask:
1. **What problem** does this solve? Who is the user?
2. **Which features** are in scope? Which are explicitly excluded?
3. **What stack?** (minSdk, Compose vs XML, Hilt, Room, Retrofit, etc.)
4. **What boundaries?** (offline support? tablet? accessibility? deep links?)

### Spec Structure

Document these sections in `SPEC.md`:

1. **Objective** — what and why (1 paragraph)
2. **Commands** — key Gradle tasks (`./gradlew assembleDebug`, `./gradlew test`, etc.)
3. **Project Structure** — module hierarchy (`:app`, `:feature:*`, `:core:*`)
4. **Code Style** — Kotlin, Compose, MVVM/MVI, Hilt, Coroutines, etc.
5. **Testing Strategy** — JUnit5 + MockK, Compose test rules, Espresso
6. **Boundaries** — what is explicitly NOT in scope

### Output

Save as `SPEC.md` in the project root. This becomes the development contract — review with the human before implementation begins.

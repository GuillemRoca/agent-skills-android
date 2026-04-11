# Agent Skills for Android

Production-grade Android engineering skills for AI coding agents. 24 specialized workflows covering the full development lifecycle from spec to Play Store — built for Kotlin, Jetpack Compose, Gradle, and the Android ecosystem.

## What Are Skills?

Skills are structured Markdown files that teach AI coding agents **how** to work, not just what to build. Each skill provides:

- **Step-by-step workflows** — not vague advice, but numbered processes
- **Kotlin code examples** — real Android patterns, not pseudocode
- **Anti-rationalizations** — rebuttals for common shortcuts agents attempt
- **Verification checklists** — tangible evidence, not "looks correct"

## Development Lifecycle

Skills map to a structured lifecycle:

```
DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP
```

Seven slash commands provide quick access:

| Command | Phase | What It Does |
|---------|-------|-------------|
| `/spec` | DEFINE | Write a structured specification |
| `/plan` | PLAN | Break work into ordered tasks |
| `/build` | BUILD | Implement incrementally with TDD |
| `/test` | VERIFY | Test-driven development workflow |
| `/review` | REVIEW | Five-axis code review |
| `/code-simplify` | BUILD | Simplify code preserving behavior |
| `/ship` | SHIP | Pre-launch checklist and rollout |

## All 24 Skills

### DEFINE Phase
| Skill | Description |
|-------|-------------|
| `idea-refine` | Sharpen vague ideas into focused, actionable directions |
| `spec-driven-development` | Write structured specs before coding |
| `context-engineering` | Set up project context for AI-assisted development |

### PLAN Phase
| Skill | Description |
|-------|-------------|
| `planning-and-task-breakdown` | Break work into vertical slices with acceptance criteria |
| `android-architecture` | MVVM/MVI, Clean Architecture, Hilt DI, module structure |

### BUILD Phase
| Skill | Description |
|-------|-------------|
| `incremental-implementation` | Build in small, verifiable increments |
| `test-driven-development` | Red-Green-Refactor with JUnit5 + MockK |
| `android-ui-engineering` | Jetpack Compose, Material 3, Navigation, state hoisting |
| `android-data-persistence` | Room, DataStore, offline-first, Paging3, repository pattern |
| `api-and-interface-design` | Retrofit interfaces, sealed types, contract-first design |
| `source-driven-development` | Every framework decision backed by official docs |
| `code-simplification` | Simplify code without changing behavior |
| `documentation-and-adrs` | Architecture Decision Records and documentation |

### VERIFY Phase
| Skill | Description |
|-------|-------------|
| `android-device-testing` | Espresso, UI Automator, Compose tests, ADB, emulators |
| `android-accessibility` | TalkBack, content descriptions, touch targets, semantics |
| `debugging-and-error-recovery` | Systematic debugging with Logcat, profilers, LeakCanary |
| `performance-optimization` | Android Vitals, Macrobenchmark, APK size, recomposition |

### REVIEW Phase
| Skill | Description |
|-------|-------------|
| `code-review-and-quality` | Five-axis review: Correctness, Readability, Architecture, Security, Performance |
| `security-and-hardening` | OWASP Mobile Top 10, Network Security Config, cert pinning |

### SHIP Phase
| Skill | Description |
|-------|-------------|
| `ci-cd-and-automation` | GitHub Actions, Gradle caching, emulator testing in CI |
| `git-workflow-and-versioning` | Trunk-based dev, atomic commits, versionCode/versionName |
| `shipping-and-launch` | Pre-launch checklist, staged rollout, Play Store requirements |
| `deprecation-and-migration` | minSdk bumps, library migrations, strangler pattern |

### META
| Skill | Description |
|-------|-------------|
| `using-agent-skills` | How agents should operate: assumptions, scope, simplicity |

## Additional Resources

### Agent Personas (`agents/`)
- **code-reviewer.md** — Five-axis code review specialist
- **test-engineer.md** — Test design and coverage analysis
- **security-auditor.md** — OWASP Mobile Top 10 auditor

### Reference Checklists (`references/`)
- **testing-patterns.md** — JUnit5, MockK, Espresso, Compose tests, MockWebServer
- **security-checklist.md** — Data storage, network, auth, components, secrets, ProGuard
- **performance-checklist.md** — Android Vitals, startup, rendering, memory, APK size
- **accessibility-checklist.md** — TalkBack, touch targets, contrast, semantics, testing

## Quick Start

Skills are plain Markdown — they work with any AI coding agent. Pick your tool:

### Claude Code

```bash
# 1. Add the marketplace (one-time setup)
claude plugin marketplace add GuillemRoca/agent-skills-android

# 2. Install the plugin
claude plugin install agent-skills-android
```

Restart Claude Code. Skills, slash commands (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/ship`), and hooks are available immediately.

### Cursor

Copy skills into `.cursor/rules/` or combine into a single `.cursorrules` file. See [Cursor setup guide](docs/cursor-setup.md).

```bash
mkdir -p .cursor/rules
cp agent-skills-android/skills/test-driven-development/SKILL.md .cursor/rules/
cp agent-skills-android/skills/code-review-and-quality/SKILL.md .cursor/rules/
cp agent-skills-android/skills/incremental-implementation/SKILL.md .cursor/rules/
```

### Windsurf

Combine 2–3 core skills into `.windsurfrules`. See [Windsurf setup guide](docs/windsurf-setup.md).

```bash
cat agent-skills-android/skills/test-driven-development/SKILL.md > .windsurfrules
echo -e "\n---\n" >> .windsurfrules
cat agent-skills-android/skills/code-review-and-quality/SKILL.md >> .windsurfrules
```

### Gemini CLI

Copy skills into `.gemini/skills/` for on-demand activation. See [Gemini CLI setup guide](docs/gemini-cli-setup.md).

```bash
mkdir -p .gemini/skills
cp -r agent-skills-android/skills/* .gemini/skills/
```

### GitHub Copilot

Add skills to `.github/skills/` and create a `copilot-instructions.md`. See [Copilot setup guide](docs/copilot-setup.md).

### OpenCode

Copy `AGENTS.md` and the `skills/` directory into your project root. The agent selects skills automatically. See [OpenCode setup guide](docs/opencode-setup.md).

### Manual / Other Agents

Skills are Markdown files — any AI agent that reads project context can use them:

```bash
git clone https://github.com/GuillemRoca/agent-skills-android.git
```

Point your agent at `skills/*/SKILL.md` or copy them into your project. Reference in your rules file:

```markdown
See skills/ for Android engineering workflow skills.
Load the appropriate skill for your current task.
```

## Tech Stack

These skills are designed for:

- **Language:** Kotlin
- **UI:** Jetpack Compose + Material 3
- **Architecture:** MVVM / MVI + Clean Architecture
- **DI:** Hilt
- **Async:** Coroutines + Flow
- **Database:** Room + DataStore
- **Network:** Retrofit + OkHttp + Kotlin Serialization
- **Testing:** JUnit5 + MockK + Espresso + Compose Test Rules
- **Build:** Gradle (Kotlin DSL)
- **CI:** GitHub Actions
- **Distribution:** Play Store + Firebase App Distribution

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding or modifying skills.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Based on [agent-skills](https://github.com/addyosmani/agent-skills) by Addy Osmani, adapted for the Android ecosystem.

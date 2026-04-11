# Agent Skills for Android

**Production-grade Android engineering skills for AI coding agents.**

24 specialized workflows covering the full development lifecycle from spec to Play Store — built for Kotlin, Jetpack Compose, Gradle, and the Android ecosystem.

## What Are Skills?

Skills are structured Markdown files that teach AI coding agents **how** to work, not just what to build. Each skill provides:

- **Step-by-step workflows** — not vague advice, but numbered processes
- **Kotlin code examples** — real Android patterns, not pseudocode
- **Anti-rationalizations** — rebuttals for common shortcuts agents attempt
- **Verification checklists** — tangible evidence, not "looks correct"

## Development Lifecycle

```
  DEFINE         PLAN          BUILD        VERIFY        REVIEW         SHIP
 ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ Spec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  PRD │      │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────┘      └──────┘      └──────┘      └──────┘      └──────┘
  /spec          /plan        /build        /test         /review       /ship
```

Seven slash commands provide quick access:

| Phase | Command | What It Does |
|-------|---------|-------------|
| DEFINE | `/spec` | Write a structured specification |
| PLAN | `/plan` | Break work into ordered tasks |
| BUILD | `/build` | Implement incrementally with TDD |
| BUILD | `/code-simplify` | Simplify code preserving behavior |
| VERIFY | `/test` | Test-driven development workflow |
| REVIEW | `/review` | Five-axis code review |
| SHIP | `/ship` | Pre-launch checklist and rollout |

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

## Installation

<details>
<summary><b>Claude Code (recommended)</b></summary>

**Marketplace install:**

```bash
claude plugin marketplace add GuillemRoca/agent-skills-android
claude plugin install agent-skills-android
```

Restart Claude Code. Skills, slash commands (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/ship`), and hooks are available immediately.

To update later:

```bash
claude plugin update agent-skills-android
```

> **SSH errors?** The marketplace clones repos via SSH. If you don't have SSH keys set up on GitHub, either [add your SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) or switch to HTTPS for fetches only:
> ```bash
> git config --global url."https://github.com/".insteadOf "git@github.com:"
> ```

</details>

<details>
<summary><b>Cursor</b></summary>

Copy any `SKILL.md` into `.cursor/rules/`, or combine into a single `.cursorrules` file. See [docs/cursor-setup.md](docs/cursor-setup.md).

```bash
mkdir -p .cursor/rules
cp agent-skills-android/skills/test-driven-development/SKILL.md .cursor/rules/
cp agent-skills-android/skills/code-review-and-quality/SKILL.md .cursor/rules/
cp agent-skills-android/skills/incremental-implementation/SKILL.md .cursor/rules/
```

</details>

<details>
<summary><b>Gemini CLI</b></summary>

Install skills for auto-discovery, or add to `GEMINI.md` for persistent context. See [docs/gemini-cli-setup.md](docs/gemini-cli-setup.md).

```bash
mkdir -p .gemini/skills
cp -r agent-skills-android/skills/* .gemini/skills/
```

</details>

<details>
<summary><b>Windsurf</b></summary>

Combine 2–3 core skills into `.windsurfrules`. See [docs/windsurf-setup.md](docs/windsurf-setup.md).

</details>

<details>
<summary><b>OpenCode</b></summary>

Uses agent-driven skill execution via `AGENTS.md` and the `skill` tool. See [docs/opencode-setup.md](docs/opencode-setup.md).

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

Use agent definitions from `agents/` as Copilot personas and skill content in `.github/copilot-instructions.md`. See [docs/copilot-setup.md](docs/copilot-setup.md).

</details>

<details>
<summary><b>Kiro IDE</b></summary>

Copy skills into `.kiro/skills/` at the project or global level. Kiro also supports `AGENTS.md`. See [Kiro docs](https://kiro.dev/docs/skills/).

</details>

<details>
<summary><b>Other Agents</b></summary>

Skills are plain Markdown — they work with any agent that accepts system prompts or instruction files:

```bash
git clone https://github.com/GuillemRoca/agent-skills-android.git
```

Copy skills into your project and point your agent at them. See [docs/getting-started.md](docs/getting-started.md).

</details>

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

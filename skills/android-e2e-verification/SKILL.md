---
name: android-e2e-verification
description: >-
  Use when a feature slice needs proof it works end-to-end on a device, or
  when closing the implement → run → assert loop for any UI-facing change.
  Maestro YAML flows turn acceptance criteria into executable checks that
  run against release builds locally, in CI, and via MCP from the agent.
---

# Android E2E Verification (Maestro)

## Overview

"It compiles and the unit tests pass" is not proof that a feature works. This skill closes the loop: every feature slice gets a Maestro flow — a YAML file of user actions and assertions derived from the spec's acceptance criteria — that runs black-box against the installed app. Implement, build, run the flow, watch it pass (or fix and re-run). The flow is committed next to the code, so the acceptance criterion stays executable forever.

Maestro drives the app over adb with no app-code changes, no test hooks, and no build instrumentation — it works on release builds and survives refactors that would break selector-heavy tests.

## When to Use

- Completing any feature slice with a user-visible flow (see `incremental-implementation`)
- Turning a spec's acceptance criteria into executable checks (see `spec-driven-development`)
- Verifying a bug fix actually fixes the user-facing behavior, not just the unit under test
- Regression-protecting critical journeys (login, checkout, sync) in CI
- Smoke-testing release candidates before rollout (see `shipping-and-launch`)

**Skip when:** The change has no runtime UI surface (pure data-layer refactor, build config) — unit/integration tests are the right layer. Don't use Maestro to test in-app logic permutations; that's what ViewModel and repository tests are for (see `test-driven-development`).

## Core Process

### Step 1: Install and Probe

1. **Install Maestro** (single binary, Java 17+):

```bash
# Pin the version so CI and local runs agree
export MAESTRO_VERSION=2.6.1
curl -fsSL "https://get.maestro.mobile.dev" | bash
# or: brew install mobile-dev-inc/tap/maestro

maestro --version   # probe availability
```

If Maestro is unavailable in the environment, say so explicitly and fall back to Compose/Espresso tests plus `android screen capture` verification — never silently skip E2E verification.

### Step 2: Write the Flow From Acceptance Criteria — Before Implementing

2. **Translate each acceptance criterion into a flow** under `.maestro/`, named after the slice:

```yaml
# .maestro/create-task.yaml
# Acceptance: "User can create a task and sees it in the list"
appId: com.example.tasks
---
- launchApp:
    clearState: true
- tapOn: "Add task"
- inputText: "Buy groceries"
- tapOn: "Save"
- assertVisible: "Buy groceries"
```

3. **Flow rules:**
   - One flow per acceptance criterion; compose shared steps with `runFlow`:

     ```yaml
     - runFlow: subflows/login.yaml
     ```
   - `clearState: true` on `launchApp` for deterministic starts
   - Assert on user-visible text or content descriptions — the same things a user sees
   - Wrap genuinely async steps in `retry` blocks instead of sprinkling waits:

     ```yaml
     - retry:
         maxRetries: 3
         commands:
           - tapOn: "Sync"
           - assertVisible: "Synced"
     ```
   - Deterministic selectors first. `assertWithAI: "the task list shows one completed item"` is allowed only where a selector cannot express the assertion (visual patterns, dynamic third-party content) — AI assertions cost more and can flake

### Step 3: Run the Loop

4. **Implement → build/install → run → fix → re-run:**

```bash
./gradlew installDebug          # or: android run --apks=...
maestro test .maestro/create-task.yaml
```

A failing flow is the signal to keep working; a passing flow is the tangible evidence the slice is done. Capture evidence for the PR when useful:

```bash
maestro record .maestro/create-task.yaml   # video of the run
```

5. **Agent-driven loop (MCP):** when the harness supports MCP, run `maestro mcp` to expose the device to the agent directly — the agent can tap, assert, and inspect live (Maestro Viewer) instead of shelling out per command. In headless/CI contexts, plain `maestro test` is the fallback. For ad-hoc exploration without Maestro, use `android screen capture --annotate` + `android screen resolve` (see `references/android-cli-reference.md`).

### Step 4: Wire Into CI

6. **Run flows in the emulator job** (see `ci-cd-and-automation`):

```yaml
- name: E2E flows
  uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: 36
    arch: x86_64
    script: |
      ./gradlew installDebug
      maestro test .maestro/
```

`maestro test .maestro/` runs every committed flow — the acceptance criteria of all shipped slices become the regression suite. For device-farm scale, `maestro cloud` runs the same flows on hosted devices.

### Step 5: Choose the Right E2E Layer

7. **Maestro is one layer, not the only one:**

| Layer | Nature | Reach for it when |
|-------|--------|-------------------|
| Compose/Espresso tests | White-box, in-process, Android-only | Screen logic, state permutations, fastest feedback |
| **Maestro flows** | Black-box YAML over adb, release builds | Acceptance criteria per slice, cross-screen journeys, CI regression |
| Journeys (`android` CLI / Studio) | AI vision + natural language | Exploratory coverage where maintaining selectors isn't worth it |

Deterministic YAML sits between fully-scripted in-process tests and fully-AI Journeys: resilient like AI, repeatable like code.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "The unit tests pass, the feature works" | Unit tests prove the pieces work in isolation. The user experiences the assembled flow — DI wiring, navigation, and manifest bugs live in the gaps. |
| "I'll write the flow after the feature is done" | Written after, the flow describes what you built, not what was asked. Written first, it's the acceptance criterion made executable. |
| "Maestro isn't installed, I'll just say it works" | "It works" without a run is an assertion, not evidence. Say the tool is unavailable and verify another way — never claim an unrun check. |
| "I'll use assertWithAI everywhere, it's easier" | AI assertions are slower, cost tokens, and can flake on ambiguity. Selectors are free and deterministic — AI is the escape hatch, not the default. |
| "E2E tests are flaky, not worth it" | Flakiness comes from timing hacks and shared state. `clearState`, `retry` blocks, and user-visible assertions make flows boringly stable. |

## Red Flags

- A completed feature slice with no flow under `.maestro/`
- Flows that only `launchApp` and assert nothing
- `assertWithAI` used where `assertVisible` would do
- Sleep-style waits instead of `retry` blocks
- Flows passing locally but not wired into the CI emulator job
- "Verified manually" in a PR description with no recorded or committed flow
- Maestro testing logic permutations that belong in ViewModel unit tests

## Verification

- [ ] Every acceptance criterion of the slice has a flow in `.maestro/`
- [ ] `maestro test .maestro/<slice>.yaml` passes against the current build (paste the output)
- [ ] Flows start from `clearState: true` (or document why not)
- [ ] Assertions target user-visible text/content descriptions
- [ ] `assertWithAI` only where a selector cannot express the assertion
- [ ] CI runs `maestro test .maestro/` in the emulator job
- [ ] If Maestro was unavailable, the fallback verification used is stated explicitly

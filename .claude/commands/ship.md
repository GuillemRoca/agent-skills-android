---
description: Run the Android pre-launch checklist via parallel fan-out to specialist personas, then synthesize a go/no-go decision with rollback and staged rollout plan.
---

# /ship — Shipping and Launch (Android)

Invoke the `shipping-and-launch` skill from `skills/shipping-and-launch/SKILL.md`.

`/ship` is a **fan-out orchestrator**. It runs three specialist personas in parallel against the current change, then merges their reports into a single go/no-go decision with a rollback plan and staged Play Store rollout. The personas operate independently — no shared state, no ordering — which is what makes parallel execution safe and useful here.

## Phase A — Parallel fan-out

Spawn three subagents concurrently using the Agent tool. **Issue all three Agent tool calls in a single assistant turn so they execute in parallel** — sequential calls defeat the purpose of this command.

In Claude Code, each call passes `subagent_type` matching the persona's `name` field:

1. **`code-reviewer`** — Run a five-axis review (correctness, readability, architecture, security, performance) on the staged changes or recent commits. Output the standard review template.
2. **`security-auditor`** — Run a vulnerability and threat-model pass against OWASP Mobile Top 10. Check secrets, exported components, deep links, Network Security Config, cert pinning, dependency CVEs, ProGuard/R8 config. Output the standard audit report.
3. **`test-engineer`** — Analyze test coverage for the change. Identify gaps in happy path, edge cases, error paths, and concurrency (coroutines, Flow). Cover ViewModel state transitions, Repository boundaries, Room DAO behavior, and Compose UI states. Output the standard coverage analysis.

In other harnesses without an Agent tool, invoke each persona's system prompt sequentially and treat their outputs as if returned in parallel — the merge phase still works.

Constraints (from Claude Code's subagent model):
- Subagents cannot spawn other subagents — do not let one persona delegate to another.
- Each subagent gets its own context window and returns only its report to this main session.
- If you need teammates that talk to each other instead of just reporting back, use Claude Code Agent Teams and reference these personas as teammate types (see `references/orchestration-patterns.md`).

**Persona resolution.** If you've defined your own `code-reviewer`, `security-auditor`, or `test-engineer` in `.claude/agents/` or `~/.claude/agents/`, those take precedence over this plugin's versions — `/ship` picks up your customizations automatically. This is intentional: plugin subagents sit at the bottom of Claude Code's scope priority table, so user-level definitions win by design.

### Skip-fan-out threshold

Skip Phase A and run a single-pass review **only if all of the following are true:**

- The change touches **2 files or fewer**
- The diff is **under 50 lines**
- It does **not** touch any of: auth, payments, data persistence (Room/DataStore/SharedPreferences), `gradle.properties`, signing config, build flavors, ProGuard/R8 rules, AndroidManifest permissions or exported components

Otherwise, default to fan-out. `/ship` is designed for production-bound changes — when the blast radius is non-trivial, run the parallel review even if the diff looks small.

## Phase B — Merge in main context

Once all three reports are back, the main agent (not a sub-persona) synthesizes them. Run these checks directly — do not delegate them back to subagents.

### 1. Code Quality
- Aggregate Critical/Important findings from `code-reviewer`
- Resolve duplicates between reviewers
- Run and verify:
  ```bash
  ./gradlew test                 # Unit tests
  ./gradlew connectedAndroidTest # Instrumented tests
  ./gradlew bundleRelease        # Release build
  ./gradlew lint                 # Lint
  ./gradlew spotlessCheck        # Formatting
  ./gradlew detekt               # Static analysis
  ```
- Check for stragglers: no `TODO`/`FIXME` without issue links, no `Log.d()`/`Log.v()` in production code, no hardcoded strings in UI, feature flags for incomplete features OFF.

### 2. Security
- Promote any Critical/High `security-auditor` findings to launch blockers
- Cross-reference with `code-reviewer`'s security axis
- Verify directly: no secrets in source, Network Security Config enforces HTTPS, cert pinning configured, ProGuard/R8 enabled for release, `android:debuggable` not set in release manifest, dependency vulnerability scan clean.

### 3. Performance — Android Vitals
Verify against `references/performance-checklist.md`. Targets to meet:
- **Cold startup** p50 < 500 ms, p90 < 1200 ms (Android Vitals "Excessive startup time" thresholds)
- **Slow rendering** (jank) < 5% of frames > 16 ms (Android Vitals threshold)
- **Frozen frames** < 0.1% of frames > 700 ms
- **ANR rate** < 0.47% of users
- **Crash-free users** > 99.5%
- **APK/AAB size** within budget; deltas vs. previous release flagged
- **Baseline Profiles** included and current for the modules touched
- No new main-thread blocking patterns (network, disk I/O, large allocations)

### 4. Accessibility
Verify against `references/accessibility-checklist.md`:
- TalkBack tested on all touched screens
- Accessibility Scanner: zero critical issues
- Touch targets ≥ 48dp
- Content descriptions on all meaningful elements
- Color contrast meets WCAG AA

### 5. Infrastructure
- Signing configuration correct (release keystore, key alias)
- Environment configs correct (API URLs, feature flag remote keys)
- Crashlytics / monitoring configured for the new code paths
- Analytics events fire as expected (verify in Play Console / DebugView)
- ProGuard/R8 rules cover any new reflection / Gson / Retrofit interfaces

### 6. Documentation
- Release notes written
- Play Store listing updated if user-visible features changed
- ADRs written for any significant architectural decisions
- README and `AGENTS.md` updated if developer workflow changed

## Phase C — Decision and rollback

Produce a single output:

```markdown
## Ship Decision: GO | NO-GO

### Blockers (must fix before ship)
- [Source persona: Critical finding + file:line]

### Recommended fixes (should fix before ship)
- [Source persona: Important finding + file:line]

### Acknowledged risks (shipping anyway)
- [Risk + mitigation]

### Rollback plan
- Trigger conditions: [crash-free users drop below 99%, ANR spike, Crashlytics new-issue volume, user-review sentiment, specific Vitals threshold breach]
- Rollback procedure (in order of fastest):
  1. **Feature flag kill switch** — disable via Remote Config / Firebase Config (seconds; preferred for any flag-gated feature)
  2. **Halt staged rollout** — Play Console → Release → Halt rollout (minutes; stops further percentage growth but doesn't pull the build from users who already have it)
  3. **Emergency hotfix** — branch from release tag, fast-track fix through internal/closed-alpha to production at higher rollout percentage (hours)
- Recovery time objective (RTO): [target time from trigger to user-visible recovery]

### Staged rollout plan
```
Internal Testing → Closed Alpha → Open Beta →
Production: 1% → 5% → 25% → 50% → 100%
```

After each expansion, monitor for at least 24h (longer for low-traffic apps) before promoting:
- Crashlytics: any new crash signatures? Spike in existing ones?
- Android Vitals: ANR rate, slow rendering, startup time
- Play Console reviews: negative sentiment spike?
- Feature analytics: expected events firing at expected volumes?

Halt criteria — promote only when ALL of: crash-free users > 99.5%, ANR rate within threshold, no new P0/P1 Crashlytics issues, no review sentiment regression.

### Specialist reports (full)
- [code-reviewer report]
- [security-auditor report]
- [test-engineer report]
```

## Rules

1. The three Phase A personas run in parallel — never sequentially.
2. Personas do not call each other. The main agent merges in Phase B.
3. The rollback plan is mandatory before any GO decision.
4. If any persona returns a Critical finding, the default verdict is NO-GO unless the user explicitly accepts the risk.
5. Skip the fan-out only when all three skip-fan-out conditions hold (≤2 files, <50 lines, no sensitive surfaces). Otherwise default to fan-out — `/ship` is designed for production-bound Android releases where blast radius justifies parallel review.

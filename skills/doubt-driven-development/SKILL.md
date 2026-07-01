---
name: doubt-driven-development
description: >-
  Use when a decision is high-stakes and hard to reverse — architecture
  choices, data migrations, dependency adoption, public API contracts.
  Adversarial self-review that attacks the chosen approach before the
  code does, instead of defending the first idea that worked.
---

# Doubt-Driven Development

## Overview

The first workable idea gets defended; a better second idea never gets considered. This skill institutionalizes doubt at the moments it pays: before committing to a decision that is expensive to reverse, deliberately attack it — enumerate failure modes, steelman one alternative, and try to break the plan on paper where breaking is free. Doubt is a tool applied at decision points, not a mood applied to everything.

## When to Use

- Architecture decisions: module boundaries, offline/sync model, state management approach (see `android-architecture`)
- Data migrations: Room schema changes, DataStore format changes — anything touching persisted user data (see `android-data-persistence`)
- Adopting or replacing a dependency the codebase will grow around
- Public or cross-team API contracts (see `api-and-interface-design`)
- minSdk/targetSdk bumps and platform-behavior migrations (see `deprecation-and-migration`)

**Skip when:** The decision is cheap to reverse (naming, private helpers, a screen's internal layout). Applying this to every choice is procrastination with extra steps.

## Core Process

### Step 1: Write the Decision Down First

1. **One paragraph, falsifiable:** what is being decided, what it optimizes for, what it deliberately gives up. If it can't be written down, it can't be attacked.

```markdown
Decision: store sync state in a Room table per entity (not a global
DataStore flag). Optimizes for per-item retry and conflict tracking.
Gives up: simpler global "is syncing" UI state.
```

### Step 2: Attack It

2. **Enumerate concrete failure modes** — Android-specific ones first:

```markdown
- Process death mid-sync: is a row ever stuck in SYNCING forever?
- Migration: what happens to existing rows when the enum gains a value?
- Doze: WorkManager retry backoff vs. per-row retry counts — double retry?
- 10k tasks: does the per-row model create N WorkRequests?
```

3. **Steelman exactly one alternative.** Argue *for* it as its best advocate would — not a strawman you can dismiss:

```markdown
Alternative: single sync journal table (append-only ops log).
Best case for it: trivially answers "what happened", replay-safe after
process death, one WorkRequest drains the log. Our chosen model has to
reinvent ordering; the journal gets it for free.
```

4. **Try to kill your plan on paper:** for each failure mode, either show why it can't happen, change the design, or accept it explicitly with a mitigation. "Probably fine" is not one of the three options.

### Step 3: Decide and Record

5. **Make the call and record it as an ADR** (see `documentation-and-adrs`) — including the failure modes considered and why the steelmanned alternative lost. The doubt is only worth its cost if the reasoning survives for the next person.

6. **Convert surviving risks into checks:** each accepted failure mode becomes a test, an assertion, or a monitored metric (see `observability-and-instrumentation`) — doubt that doesn't turn into a check evaporates.

```kotlin
// Failure mode "row stuck in SYNCING after process death" → a test
@Test
fun `rows in SYNCING older than timeout are reset to PENDING on start`() { ... }
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I already thought about the tradeoffs" | Thinking about tradeoffs while defending a choice is advocacy. The steelman forces the perspective switch advocacy avoids. |
| "We don't have time for this ceremony" | The ceremony is an hour. Reversing a shipped Room migration or a published API contract is weeks. |
| "The alternative is obviously worse" | If it's obvious, the steelman takes five minutes and costs nothing. "Obviously worse" usually means "not actually considered". |
| "Doubt everything, ship nothing" | Inverted failure: this skill applies to hard-to-reverse decisions only. Cheap decisions get made, not doubted. |
| "The team lead already approved it" | Approval of an unattacked plan transfers blame, not correctness. Bring the failure-mode list to the approval. |

## Red Flags

- An ADR whose "alternatives considered" section is one dismissive sentence
- Room schema migration merged with no process-death or downgrade discussion
- New dependency adopted with no note on its abandonment/replacement cost
- Failure modes listed but none converted into tests or metrics
- The steelman reads like a strawman (weakest version of the alternative)
- Doubt applied to a trivial reversible choice while a migration ships unexamined

## Verification

- [ ] Decision written down in falsifiable form (optimizes for / gives up)
- [ ] Concrete failure modes enumerated, including process death, migration, and background-limits cases where relevant
- [ ] Exactly one alternative steelmanned in writing
- [ ] Every failure mode: refuted, designed away, or accepted with mitigation
- [ ] ADR recorded with the losing alternative's best case (see `documentation-and-adrs`)
- [ ] Surviving risks exist as tests, assertions, or monitored metrics — point to them

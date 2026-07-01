---
name: interview-me
description: >-
  Use when requirements are vague, contradictory, or thinner than the work
  deserves — before writing a spec or starting implementation. Iterative
  questioning that raises requirement confidence to ~95% instead of
  guessing and building the wrong thing.
---

# Interview Me

## Overview

The cheapest bug is the one never written because the right question was asked first. This skill replaces assumption-stacking with a structured interview: ask targeted questions in small batches, feed each answer into the next round, and stop only when you could write the spec's acceptance criteria without inventing anything. It front-loads the conversation that otherwise happens as review rework.

## When to Use

- The request is one or two sentences for something clearly bigger ("add offline support")
- Requirements contradict each other or the existing app's behavior
- Multiple plausible interpretations exist and picking wrong is expensive
- Before `spec-driven-development` when the input idea is fuzzy
- A stakeholder says "you know what I mean" — you don't

**Skip when:** The task is small and unambiguous (rename, obvious bug fix), or a spec with acceptance criteria already exists — go build. Don't interview to avoid starting.

## Core Process

### Step 1: State What You Think You Know

1. **Write down the current understanding and confidence level** before asking anything:

```markdown
## Understanding: offline support for tasks
- Users can view cached tasks offline — confident (stated)
- Users can CREATE tasks offline — assumed, not stated
- Conflict resolution strategy — unknown
- Sync trigger (foreground only? WorkManager?) — unknown
Confidence: ~40%
```

Unknowns and assumptions become the question list. If nothing lands in those rows, you didn't need the interview.

### Step 2: Ask in Small, Targeted Batches

2. **3–5 questions per round, highest-leverage first.** One decision per question, concrete options over open prompts:

```markdown
1. When a task is edited offline on two devices, which wins — last write,
   or surface a conflict to the user?
2. Should offline creation work, or is offline read-only for v1?
3. Sync on app-open only, or background sync via WorkManager?
4. What happens to offline changes if the user logs out?
```

3. **Question rules:**
   - Ask about *behavior users see*, not implementation ("which wins?", not "OT or CRDT?")
   - Offer defaults: "I'd propose last-write-wins for v1 — acceptable?" — easy to confirm, easy to correct
   - Surface Android realities the stakeholder may not know: background limits (Doze, see `android-background-work`), permission prompts, Play policy constraints (see `shipping-and-launch`)
   - Never re-ask what an earlier answer already settled

### Step 3: Feed Answers Back and Iterate

4. **After each round, update the understanding document** — restate answers in your own words, mark resolved items, and let new questions emerge from the answers:

```markdown
Resolved: offline read + create for v1; last-write-wins; sync on app-open.
New question raised by "last-write-wins": is silent data loss on conflict
acceptable, or should we log it for support?
Confidence: ~80%
```

### Step 4: Stop at ~95% and Convert

5. **Exit when you could write every acceptance criterion without inventing.** Perfect certainty is not the bar — the remaining 5% gets written down as explicit assumptions:

```markdown
Assumptions (proceeding unless corrected):
- Conflicts are rare enough that silent last-write-wins is acceptable for v1
```

6. **Hand off to `spec-driven-development`** with the understanding document as input. The interview output is the spec's raw material, not a substitute for the spec.

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I'll make reasonable assumptions and note them" | Ten stacked "reasonable" assumptions produce an unreasonable result. Assumptions are for the last 5%, not the first 50%. |
| "Asking questions makes me look incapable" | Building the wrong thing looks worse. Good questions demonstrate understanding of the problem space. |
| "The stakeholder is busy, I shouldn't bother them" | Five minutes of their time now beats a week of rework and a harder conversation later. |
| "I'll figure it out as I build" | Structural decisions (offline model, conflict strategy) are cheap to change in conversation and expensive to change in code. |
| "One big questionnaire is more efficient" | Twenty questions at once get skimmed. Small batches get real answers, and answers change the next questions. |

## Red Flags

- Implementation started while the understanding doc still lists "unknown" on core behavior
- Questions about implementation details instead of user-visible behavior
- The same question asked twice because answers weren't recorded
- Zero assumptions documented on a task that had ambiguity (they were made silently)
- A twenty-question wall dumped in one message
- "Interviewing" continuing past the point where acceptance criteria are writable — stalling, not clarifying

## Verification

- [ ] Understanding document exists with resolved / assumed / unknown items
- [ ] Every core user-visible behavior is resolved or explicitly assumed (no silent gaps)
- [ ] Remaining assumptions are written down and shared, not private
- [ ] Acceptance criteria can be drafted without inventing behavior
- [ ] Android platform constraints (background, permissions, Play policy) surfaced where relevant
- [ ] Output handed to `spec-driven-development` (or the task was re-scoped/rejected)

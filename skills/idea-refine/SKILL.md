---
name: idea-refine
description: >-
  Use when a feature idea, project concept, or product direction is vague
  and needs sharpening before spec or implementation. Guides divergent
  exploration, convergent evaluation, and a final one-pager.
---

# Idea Refinement

## Overview

Turn a vague idea into a focused, actionable direction. This skill uses structured divergent-convergent thinking: first expand possibilities, then evaluate and converge on the strongest direction, then sharpen into a one-pager ready for spec writing.

**Philosophy:** "Simplicity is the ultimate sophistication." Say no to 1,000 things to focus on the one that matters.

## When to Use

- A feature request or product idea is unclear or overly broad
- You need to explore multiple directions before committing
- Stakeholders have different interpretations of "what we're building"
- Before writing a spec (feeds into `spec-driven-development`)

**Skip when:** The requirement is already specific and unambiguous.

## Core Process

### Phase 1: Understand & Expand (Divergent)

1. **Restate as "How Might We"** — Convert the idea into an open question
   - "Add offline support" → "How might we ensure users can accomplish core tasks without connectivity?"

2. **Ask sharpening questions** (answer or surface for human input):
   - Who specifically benefits? (persona, not "users")
   - What does success look like? (measurable outcome)
   - What constraints exist? (timeline, tech debt, API limitations, minSdk)
   - What has been tried before?

3. **Generate 5–8 variations** using these lenses:
   - **Inversion:** What if we solved the opposite problem?
   - **Constraint removal:** What if we had no legacy code / no backward compatibility?
   - **Simplification:** What is the absolute minimum version?
   - **Combination:** What if we merged this with another planned feature?
   - **Analogy:** How do other Android apps solve this? (study Play Store top apps)

### Phase 2: Evaluate & Converge

4. **Cluster into 2–3 directions** — group related variations
5. **Stress-test each direction:**
   - Technical feasibility (existing modules, Android API levels, library support)
   - User impact (who benefits, how much)
   - Effort estimate (small / medium / large)
   - Risk profile (what could go wrong)
6. **Surface hidden assumptions** — list every assumption with a validation strategy
   - "Assumption: Room migrations will handle schema changes → Validate: write migration test"

### Phase 3: Sharpen & Ship

7. **Write a one-pager** with:
   - **Problem statement** (1–2 sentences)
   - **Recommended direction** (with rationale)
   - **Key assumptions** (with validation plan)
   - **MVP scope** (what's in the first slice)
   - **"Not Doing" list** (explicit exclusions — critical for scope discipline)

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "The idea is obvious, skip to coding" | Obvious ideas have hidden assumptions. Shipping the wrong thing wastes more time than 30 minutes of refinement. |
| "We explored enough in the meeting" | Verbal exploration is lossy. Written exploration catches gaps. |
| "Let's just build an MVP and see" | An unfocused MVP tests nothing. Define what you're testing first. |
| "We don't have time to explore" | Exploration prevents rework. 30 minutes now saves days later. |

## Red Flags

- No "Not Doing" list (scope will creep)
- Single direction explored (confirmation bias)
- Assumptions listed without validation strategies
- MVP scope includes "and also…" additions
- No measurable success criteria

## Verification

Before moving to spec:

- [ ] Problem restated as "How Might We" question
- [ ] At least 5 variations generated using different lenses
- [ ] 2–3 directions evaluated with feasibility, impact, effort, risk
- [ ] All assumptions listed with validation strategies
- [ ] One-pager written with problem, direction, assumptions, MVP scope, exclusions
- [ ] Human has reviewed and approved the direction

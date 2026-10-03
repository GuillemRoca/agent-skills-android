---
name: shipping-and-launch
description: >-
  Use when preparing to release an Android app to production. Pre-launch
  checklist covering code quality, security, performance, accessibility,
  Play Store requirements, staged rollout, and rollback planning.
---

# Shipping and Launch

## Overview

"Ship with confidence. Deploy safely, with monitoring, rollback plan ready." Shipping isn't just uploading an AAB — it's verifying that everything is production-ready, staging the rollout, monitoring for issues, and having a rollback plan if things go wrong.

## When to Use

- Before any release to Play Store (internal, alpha, beta, production)
- Before any release via Firebase App Distribution
- When promoting from one release track to another
- After a hotfix that needs expedited release

**Skip when:** Not releasing (local development only).

## Core Process

### Step 1: Pre-Launch Checklist

1. **Code Quality:**

```bash
# All tests pass
./gradlew test
./gradlew connectedAndroidTest

# Build succeeds
./gradlew bundleRelease

# No lint errors
./gradlew lint

# Formatting is consistent
./gradlew spotlessCheck

# Static analysis passes
./gradlew detekt
```

2. **Manual code checks:**
   - [ ] No `TODO` or `FIXME` without issue references
   - [ ] No `Log.d()` or `Log.v()` calls in production code (use ProGuard to strip)
   - [ ] No hardcoded strings in UI (use `stringResource`)
   - [ ] No `BuildConfig.DEBUG`-gated features shipping to production
   - [ ] Feature flags for incomplete features are OFF

3. **Security** (see `security-and-hardening`):
   - [ ] No secrets in source code
   - [ ] Network Security Config enforces HTTPS
   - [ ] Certificate pinning configured
   - [ ] ProGuard/R8 enabled for release build
   - [ ] `android:debuggable` not set in release manifest
   - [ ] Dependency vulnerability scan clean

4. **Performance** (see `performance-optimization`):
   - [ ] Android Vitals targets met (startup < 500ms, jank < 5%)
   - [ ] APK/AAB size within budget
   - [ ] Baseline Profiles included
   - [ ] No ANR-prone patterns (main thread blocking)
   - [ ] Images optimized (WebP, proper sizing)

5. **Accessibility** (see `android-accessibility`):
   - [ ] TalkBack tested on all screens
   - [ ] Accessibility Scanner reports zero critical issues
   - [ ] Touch targets >= 48dp
   - [ ] Color contrast meets standards
   - [ ] Content descriptions on all meaningful elements

6. **Infrastructure:**
   - [ ] Signing configuration correct (release keystore)
   - [ ] Environment-specific configs correct (API URLs, feature flags)
   - [ ] Crashlytics/error monitoring configured
   - [ ] Firebase Performance Monitoring enabled
   - [ ] Analytics events verified

7. **Documentation:**
   - [ ] Release notes written
   - [ ] Play Store listing updated (screenshots, description)
   - [ ] ADRs written for significant changes
   - [ ] Internal changelog updated

### Step 2: Staged Rollout

8. **Rollout progression:**

```
Internal Testing (Play Store internal track)
  → Verified by team
    ↓
Closed Alpha (Play Store alpha track)
  → Verified by internal testers + QA
    ↓
Open Beta (Play Store beta track)
  → Verified by beta users (wider audience)
    ↓
Production (staged rollout)
  → 1% → 5% → 25% → 50% → 100%
```

9. **Staged rollout with Play Store:**

```
Day 0: Release to 1% of users
  → Monitor Crashlytics, ANR rate, user feedback
Day 1: If clean → expand to 5%
  → Check Play Console Android Vitals
Day 3: If clean → expand to 25%
  → Review user reviews and ratings
Day 5: If clean → expand to 50%
Day 7: If clean → expand to 100%
```

10. **Decision thresholds:**

| Metric | Action |
|--------|--------|
| Crash rate > 2x previous version | **Halt rollout**, investigate |
| ANR rate > 0.47% | **Halt rollout**, investigate |
| Negative reviews spike > 2x | **Halt rollout**, investigate |
| Error rate > 0.1% new errors | Investigate, consider halt |
| Startup time regression > 20% | Investigate, consider halt |

#### Error Budget Release Gate

The thresholds above decide whether *this* rollout continues; the error budget decides whether you should be starting a rollout at all. Set a stability SLO — typically crash-free users (e.g. 99.5%) plus user-perceived crash and ANR rates below the Play bad-behavior thresholds (1.09% / 0.47%, see `observability-and-instrumentation`). The budget is the gap between the SLO and reality over a 28-day window, the same window Play Vitals uses:

```kotlin
// SLO 99.5% crash-free users → 0.5% of users may crash in 28 days
fun budgetRemaining(sloCrashFree: Double, actualCrashFree28d: Double): Double {
    val allowed = 1.0 - sloCrashFree          // 0.005
    val consumed = 1.0 - actualCrashFree28d   // e.g. 0.003 at 99.7% crash-free
    return ((allowed - consumed) / allowed).coerceAtLeast(0.0)  // 0.4 → 40% left
}
```

Use it as an objective gate, not a negotiation:

```
Budget remaining > 20%   →  Normal staged rollout (1% → 5% → 25% → 50% → 100%)
Budget remaining 0–20%   →  Slow rollouts only: smaller steps, longer bake per step,
                            no high-risk changes (migrations, SDK upgrades, rewrites)
Budget exhausted         →  Freeze feature releases; ship only stability fixes
Play Vitals threshold    →  Treat as exhausted — Play may already be reducing
  breached                  store visibility, so every release must lower the rate
Budget recovers          →  Resume normal pace; keep the fix that recovered it
```

**Burn rate during rollout:** a crash or ANR rate on the newest version that is rising faster than the previous version's baseline is a **halt** signal (Play Console → Halt rollout), even while every row in the thresholds table is still green. The mobile twist makes the gate stricter than on a server: you cannot roll back an installed binary. Remediation is halt plus hotfix forward, or a Remote Config kill switch (see Step 4) — so budget spent at 25% rollout stays spent until users take the next update.

### Step 3: Feature Flag Management

11. **Feature flag lifecycle:**

```
Created (disabled) → Enabled (internal) → Canary (5%) →
Expanded (25%) → Full (100%) → Removed (cleanup)
```

12. **Before shipping:**
    - Verify all feature flags are in expected state
    - Remove flags for fully-rolled-out features (tech debt)
    - Document flag state in release notes

### Step 4: Rollback Plan

13. **Always have a rollback strategy:**

```markdown
## Rollback Plan

### Option 1: Halt Staged Rollout
- In Play Console → Release → Production → Halt rollout
- Users who haven't updated keep the old version
- Already-updated users keep the new version (no downgrade)

### Option 2: Emergency Hotfix
- Create `hotfix/1.2.1` branch from `release/1.2.0`
- Apply minimal fix
- Fast-track through CI → Internal → Production (100%)

### Option 3: Feature Flag Kill Switch
- Disable the problematic feature via Firebase Remote Config
- Users get the update but broken feature is hidden
- Fastest response time (no new build needed)
```

### Step 5: Post-Launch Monitoring

14. **First 24 hours after launch:**
    - [ ] Crashlytics — new crash types?
    - [ ] ANR rate — within threshold?
    - [ ] Firebase Performance — startup time, network latency?
    - [ ] Play Console — user reviews, ratings?
    - [ ] Error monitoring — new error patterns?
    - [ ] Critical user flows — working end-to-end?

15. **First 7 days:**
    - [ ] Android Vitals in Play Console — all green?
    - [ ] Staged rollout expanded on schedule?
    - [ ] Feature flag cleanup scheduled?
    - [ ] Retro/post-mortem if issues occurred

### Step 6: Play Store Requirements

16. **Play Store checklist:**
    - [ ] Target SDK meets Play Store requirements (the latest stable API level — new apps and updates must target API 36+ from Aug 31, 2026; check the current deadline at developer.android.com/google/play/requirements/target-sdk)
    - [ ] 16 KB page-size compliance verified if the app ships native libraries (required since Nov 2025 for apps targeting Android 15+; needs NDK r28+ / AGP 8.5.1+)
    - [ ] Edge-to-edge rendering verified (enforced for apps targeting Android 15+; no `statusBarColor`/`navigationBarColor` reliance)
    - [ ] Privacy policy URL set
    - [ ] Data safety form completed
    - [ ] Content rating questionnaire completed
    - [ ] App signing by Google Play enabled
    - [ ] AAB format (not APK) for new apps
    - [ ] Deobfuscation mapping file uploaded (R8/ProGuard)
    - [ ] Release notes in all supported languages

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "We'll skip staged rollout, the tests pass" | Tests don't catch device-specific bugs, carrier issues, or user-facing performance. |
| "Rollback plan isn't needed, it's a small change" | Small changes can have outsized impact. A 1-line change can cause a crash. |
| "We'll monitor tomorrow" | The first few hours are critical. Issues compound overnight. |
| "Let's ship 100% — we're confident" | Confidence without staged rollout is hope, not engineering. |
| "The crash rate is under the halt threshold, keep expanding" | Check the burn rate, not just the current rate. A newest-version crash/ANR rate climbing faster than baseline is a halt signal while every threshold is still green — and installed binaries can't be rolled back. |
| "The budget is gone, but this feature is already done" | An exhausted budget means stability fixes only. Shipping features on top of a burning release spends budget you don't have and risks Play visibility. |

## Red Flags

- No staged rollout (0% to 100% in one step)
- No rollback plan documented
- No monitoring configured before launch
- `Log.d` calls in release builds
- Hardcoded debug URLs shipping to production
- Feature flags in unknown state
- No Play Store compliance check
- Missing deobfuscation mapping file upload
- Launching on Friday (no monitoring over weekend)
- Error budget exhausted (or a Vitals threshold breached) but feature releases continue unchanged
- No stability SLO defined, so "is it safe to ship?" is decided by mood

## Verification

- [ ] Pre-launch checklist complete (quality, security, performance, accessibility)
- [ ] Release build signed with production keystore
- [ ] Staged rollout plan defined
- [ ] Error budget checked against the 28-day stability SLO, and the rollout pace matches the gate (normal / slow / stability-fixes-only)
- [ ] Rollback strategy documented
- [ ] Monitoring configured (Crashlytics, Performance, Analytics)
- [ ] Play Store requirements met
- [ ] Release notes written
- [ ] Team aware of launch timeline
- [ ] Post-launch monitoring plan in place

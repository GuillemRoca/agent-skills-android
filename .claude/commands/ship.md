# /ship — Shipping and Launch

Pre-launch checklist and release preparation.

## Instructions

Load and follow the `shipping-and-launch` skill from `skills/shipping-and-launch/SKILL.md`.

### Pre-Launch Checklist

#### Code Quality
```bash
./gradlew test                    # All unit tests pass
./gradlew connectedAndroidTest    # All instrumented tests pass
./gradlew bundleRelease           # Release build succeeds
./gradlew lint                    # No lint errors
./gradlew spotlessCheck           # Formatting consistent
./gradlew detekt                  # Static analysis passes
```

- [ ] No `TODO`/`FIXME` without issue references
- [ ] No `Log.d()`/`Log.v()` in production code
- [ ] No hardcoded strings in UI
- [ ] Feature flags for incomplete features are OFF

#### Security
- [ ] No secrets in source code
- [ ] Network Security Config enforces HTTPS
- [ ] Certificate pinning configured
- [ ] ProGuard/R8 enabled for release
- [ ] `android:debuggable` not set in release manifest
- [ ] Dependency vulnerability scan clean

#### Performance
- [ ] Android Vitals targets met (startup < 500ms, jank < 5%)
- [ ] APK/AAB size within budget
- [ ] Baseline Profiles included
- [ ] No main-thread blocking patterns

#### Accessibility
- [ ] TalkBack tested on all screens
- [ ] Accessibility Scanner: zero critical issues
- [ ] Touch targets >= 48dp
- [ ] Content descriptions on all meaningful elements

#### Infrastructure
- [ ] Signing configuration correct (release keystore)
- [ ] Environment configs correct (API URLs, feature flags)
- [ ] Crashlytics/monitoring configured
- [ ] Analytics events verified

#### Documentation
- [ ] Release notes written
- [ ] Play Store listing updated
- [ ] ADRs written for significant changes

### Rollback Strategy

Document the rollback plan:
1. **Halt staged rollout** — Play Console → Release → Halt
2. **Emergency hotfix** — branch from release, fast-track fix
3. **Feature flag kill switch** — disable via Remote Config (fastest)

### Staged Rollout

```
Internal Testing → Closed Alpha → Open Beta →
Production: 1% → 5% → 25% → 50% → 100%
```

Monitor after each expansion:
- Crashlytics (new crash types?)
- ANR rate (within threshold?)
- User reviews (negative spike?)

Resolve all failing checks before promoting to production.

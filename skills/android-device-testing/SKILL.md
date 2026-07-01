---
name: android-device-testing
description: >-
  Use when writing or debugging instrumented tests (Espresso, UI Automator,
  Compose test rules), using ADB, managing emulators, or inspecting UI
  with Layout Inspector.
---

# Android Device Testing

## Overview

Test your app on real or emulated Android devices. This skill covers instrumented testing frameworks (Espresso, UI Automator, Compose testing), device management (ADB, emulators), UI inspection (Layout Inspector), and debugging tools for on-device behavior.

## When to Use

- Writing instrumented tests (UI tests that run on a device/emulator)
- Debugging behavior that only reproduces on-device
- Setting up emulators for CI or local testing
- Inspecting UI hierarchy, accessibility, or layout issues
- Verifying behavior across API levels or screen sizes

**Skip when:** Writing unit tests that don't need a device (use JUnit5 + MockK instead).

## Core Process

### Step 1: Compose UI Testing

1. **Set up Compose test dependencies:**

```kotlin
// build.gradle.kts
androidTestImplementation("androidx.compose.ui:ui-test-junit4")
debugImplementation("androidx.compose.ui:ui-test-manifest")
```

2. **Write Compose UI tests:**

```kotlin
@get:Rule
val composeTestRule = createComposeRule()

@Test
fun taskItem_displaysTitle() {
    composeTestRule.setContent {
        AppTheme {
            TaskItem(
                task = Task("1", "Buy groceries", false),
                onToggle = {},
                onDelete = {},
            )
        }
    }

    composeTestRule
        .onNodeWithText("Buy groceries")
        .assertIsDisplayed()
}

@Test
fun taskItem_toggleCallsCallback() {
    var toggledId: String? = null

    composeTestRule.setContent {
        AppTheme {
            TaskItem(
                task = Task("1", "Buy groceries", false),
                onToggle = { toggledId = it },
                onDelete = {},
            )
        }
    }

    composeTestRule
        .onNodeWithContentDescription("Buy groceries")
        .performClick()

    assertEquals("1", toggledId)
}

@Test
fun taskList_showsEmptyState_whenNoTasks() {
    composeTestRule.setContent {
        AppTheme {
            TaskListContent(
                uiState = TaskListUiState.Success(tasks = emptyList()),
                onToggle = {},
                onDelete = {},
            )
        }
    }

    composeTestRule
        .onNodeWithText("No tasks yet")
        .assertIsDisplayed()
}
```

3. **Compose test selectors (prefer this order):**
   - `onNodeWithText("visible text")` — most readable
   - `onNodeWithContentDescription("description")` — for icons, images
   - `onNodeWithTag("test_tag")` — last resort, add `Modifier.testTag("tag")`
   - **Avoid:** index-based selection, parent traversal

### Step 2: Espresso (View-based UI)

4. **Espresso for XML views or hybrid apps:**

```kotlin
@Test
fun settingsScreen_displaysVersionNumber() {
    onView(withId(R.id.version_text))
        .check(matches(withText(containsString("1.0"))))
}

@Test
fun loginButton_disabled_whenFieldsEmpty() {
    onView(withId(R.id.login_button))
        .check(matches(not(isEnabled())))
}
```

5. **Espresso with RecyclerView:**

```kotlin
onView(withId(R.id.recycler_view))
    .perform(
        RecyclerViewActions.actionOnItemAtPosition<ViewHolder>(
            0, click()
        )
    )
```

### Step 3: UI Automator (Cross-app testing)

6. **UI Automator for system-level interactions:**

```kotlin
@Test
fun notification_opensApp_whenTapped() {
    val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    // Open notification shade
    device.openNotification()

    // Find and click notification
    val notification = device.findObject(
        UiSelector().textContains("New task")
    )
    notification.click()

    // Verify app screen
    composeTestRule
        .onNodeWithText("Task Detail")
        .assertIsDisplayed()
}
```

### Step 4: ADB Commands

7. **Essential ADB commands:**

```bash
# List connected devices
adb devices

# Install APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Run instrumented tests
./gradlew connectedAndroidTest

# Run specific test class
./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.example.TaskListTest

# Take screenshot
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png

# Clear app data
adb shell pm clear com.example.app

# View logs
adb logcat -s TAG_NAME:D

# Simulate process death
adb shell am kill com.example.app

# Simulate low memory
adb shell am send-trim-memory com.example.app RUNNING_CRITICAL

# Grant/revoke permissions
adb shell pm grant com.example.app android.permission.CAMERA
adb shell pm revoke com.example.app android.permission.CAMERA

# Simulate no network
adb shell svc wifi disable
adb shell svc data disable
```

### Step 5: Emulator Management

8. **Create emulators for testing matrix:**

```bash
# List available system images
sdkmanager --list | grep system-images

# Create emulator
avdmanager create avd \
    --name "Pixel_7_API_35" \
    --package "system-images;android-35;google_apis;x86_64" \
    --device "pixel_7"

# Start emulator
emulator -avd Pixel_7_API_35 -no-snapshot-load

# Start headless (for CI)
emulator -avd Pixel_7_API_35 -no-window -no-audio -gpu swiftshader_indirect
```

9. **Test across API levels:**
   - minSdk (verify compatibility)
   - Target SDK (verify new behavior)
   - Latest stable (verify forward compatibility)
   - Key breakpoints: API 26 (minSdk common), API 31 (S changes), API 33 (notification permission), API 34 (photo picker, foreground service types), API 35 (edge-to-edge enforced, 16 KB page sizes), API 36 (predictive back on by default), API 37 (adaptive-by-default: orientation/resizability restrictions ignored on ≥600dp displays; `ACCESS_LOCAL_NETWORK` permission)

### Step 6: `android` CLI for Deploy and Layout Assertions

10. **Use `android` CLI as a thin wrapper around `adb` + `avdmanager` + `emulator` when available** (probe with `android --version`; fall back to step 4/5 commands if absent):

    ```bash
    # Lifecycle: emulator → install → run → inspect
    android emulator list
    android emulator start --name Pixel_7_API_35
    android run --apks=app/build/outputs/apk/debug/app-debug.apk
    android describe                              # locate built artifacts (JSON)
    ```

    `android run` accepts a comma-separated APK list and an `--activity` flag; preferable to `adb install -r` + `am start` when you want a single deploy step that resolves the launcher activity automatically.

11. **Use `android layout` for state-change assertions** (faster than re-running an instrumented test for one-off checks):

    ```bash
    # Snapshot before action, then diff after to see only what changed
    android layout --pretty --output=before.json
    adb shell input tap 540 1200       # perform the action
    android layout --diff               # only nodes added/changed/removed since last snapshot
    ```

    Useful during test authoring: lets you discover the exact `resource-id`, `text`, and `bounds` of the elements your test should assert on, without guessing from a screenshot. See `references/android-cli-reference.md`.

### Step 7: Screenshot Tests

12. **Lock UI in with JVM screenshot tests** — no device, fast enough to run on every PR:

    - **Compose Preview Screenshot Testing** (official `com.android.compose.screenshot` plugin): reuses your `@Preview` composables. Record goldens with `./gradlew updateDebugScreenshotTest`, fail CI on diffs with `./gradlew validateDebugScreenshotTest`.
    - **Roborazzi** (Robolectric-based): `captureRoboImage()` inside any Compose/Robolectric test — use when you need interactions before capture or non-Preview cases.

    Use Preview Screenshot Testing by default (zero extra test code); reach for Roborazzi when a state can't be expressed as a preview. Keep goldens deterministic (fixed locale, font scale, time inputs) and commit them — a diff is a review artifact. Patterns in `references/testing-patterns.md`.

### Step 8: Journeys and Black-Box E2E

13. **Choose the right end-to-end layer:**

    | Tool | Nature | Use for |
    |------|--------|---------|
    | Compose/Espresso tests | White-box, in-process | Screen and flow logic within the app; fastest feedback |
    | **Maestro** (see `android-e2e-verification`) | Black-box YAML over adb | Deterministic acceptance flows per feature slice; release builds; CI |
    | **Journeys** (`android` CLI / Android Studio) | AI vision + reasoning from natural-language steps | Exploratory E2E where maintaining selectors isn't worth it; resilient to layout churn but slower and less deterministic |

    When driving the device ad hoc (reproducing a bug, verifying a fix), use the CLI's see-and-drive loop: `android screen capture --annotate` labels every element with `#n`, then `android screen resolve --screenshot=... --string="input tap #5"` translates the label into `adb shell input` coordinates. See `references/android-cli-reference.md`.

### Step 9: Layout Inspector

14. **Use Layout Inspector to debug:**
    - Open via Android Studio → Tools → Layout Inspector
    - Inspect Compose hierarchy and recomposition counts
    - Verify accessibility properties (content descriptions, roles)
    - Check padding, margins, and alignment
    - Compare with design specs

### Step 10: Test Organization

15. **Test pyramid on Android:**

```
    /‾‾‾‾‾‾‾‾‾\
   / UI Tests   \        ~5%  — Espresso, UI Automator, Compose
  / (connected)  \             (slow, flaky, but catch integration bugs)
 /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
/ Integration Tests \     ~15% — Robolectric, Room in-memory,
| (local or device) |           MockWebServer
|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
|    Unit Tests       |   ~80% — JUnit5 + MockK
|  (local, fast)      |          (ViewModels, UseCases, Repos)
 ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "I tested manually, that's enough" | Manual testing doesn't catch regressions. Automated tests do. |
| "Instrumented tests are too slow" | Slow tests that catch real bugs beat fast tests that miss them. Run in CI. |
| "I'll just test on my device" | Your device is one API level, one screen size. The matrix matters. |
| "Compose tests are flaky" | Flaky tests usually have timing issues. Use `waitUntil` and proper assertions. |

## Red Flags

- No instrumented tests for critical user flows
- Tests only run on one API level
- Hardcoded delays (`Thread.sleep`) instead of idling resources or `waitUntil`
- Tests depend on device state (network, locale, permissions)
- No Compose test rules for Compose-based screens
- Emulator setup not documented or automated

## Verification

- [ ] Critical user flows have instrumented tests
- [ ] `./gradlew connectedAndroidTest` passes
- [ ] Tests use proper waiting mechanisms (no `Thread.sleep`)
- [ ] Compose tests use semantic selectors (text, content description)
- [ ] Test matrix covers minSdk and targetSdk
- [ ] CI runs instrumented tests on emulator
- [ ] Screenshot tests exist for key screens and pass (`./gradlew validateDebugScreenshotTest` or Roborazzi)
- [ ] Layout Inspector shows expected hierarchy and accessibility info

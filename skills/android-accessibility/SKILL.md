---
name: android-accessibility
description: >-
  Use when building or reviewing Android UI for accessibility. Covers
  TalkBack, content descriptions, touch targets, Compose semantics,
  focus order, and Accessibility Scanner testing.
---

# Android Accessibility

## Overview

Accessibility is not optional — it's a requirement for reaching all users. This skill covers building accessible Android UIs with Jetpack Compose semantics, proper content descriptions, touch target sizing, TalkBack compatibility, and systematic testing with Accessibility Scanner.

## When to Use

- Building new UI screens or components
- Reviewing existing UI for accessibility compliance
- Fixing accessibility issues flagged by Accessibility Scanner or users
- Before shipping any user-facing feature

**Skip when:** Working on non-UI code (repositories, use cases, networking).

## Core Standards

| Requirement | Standard |
|------------|----------|
| Touch targets | Minimum 48dp x 48dp |
| Color contrast (text) | >= 4.5:1 (normal), >= 3:1 (large 18sp+) |
| Color contrast (UI components) | >= 3:1 against adjacent colors |
| Content descriptions | All meaningful visual elements |
| Focus order | Logical reading order |
| No color-only information | Additional indicators required |

## Core Process

### Step 1: Content Descriptions

1. **Every meaningful visual element needs a description:**

```kotlin
// Icons that convey information
Icon(
    imageVector = Icons.Default.Delete,
    contentDescription = "Delete task", // Descriptive, not "delete icon"
)

// Decorative elements — explicitly null
Icon(
    imageVector = Icons.Default.Circle,
    contentDescription = null, // Decorative, TalkBack skips it
)

// Images
Image(
    painter = painterResource(R.drawable.user_avatar),
    contentDescription = "Profile photo of ${user.name}",
)

// IconButtons — the button gets the description
IconButton(
    onClick = onDelete,
) {
    Icon(
        imageVector = Icons.Default.Delete,
        contentDescription = "Delete task", // On the Icon, read by TalkBack
    )
}
```

2. **Description rules:**
   - Describe the **action or meaning**, not the visual appearance
   - "Delete task" not "red trash can icon"
   - "Search" not "magnifying glass"
   - Use `null` for purely decorative elements
   - Include dynamic content: "Profile photo of John" not just "profile photo"

### Step 2: Touch Targets

3. **Enforce minimum 48dp touch targets:**

```kotlin
// Compose handles this automatically for clickable elements,
// but verify small elements:
IconButton(
    onClick = onToggle,
    modifier = Modifier.size(48.dp), // At least 48dp
) {
    Icon(
        imageVector = Icons.Default.Check,
        contentDescription = "Mark complete",
        modifier = Modifier.size(24.dp), // Icon can be smaller
    )
}

// For custom clickable elements, ensure minimum touch area:
@Composable
fun SmallChip(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        onClick = onClick,
        modifier = modifier.defaultMinSize(minHeight = 48.dp, minWidth = 48.dp),
    ) {
        Text(label, modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp))
    }
}
```

### Step 3: Compose Semantics

4. **Use semantics for rich accessibility information:**

```kotlin
// Merge child semantics for a single TalkBack announcement
@Composable
fun TaskItem(
    task: Task,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .semantics(mergeDescendants = true) {
                // Custom state description
                stateDescription = if (task.completed) "Completed" else "Not completed"
                // Custom action
                customActions = listOf(
                    CustomAccessibilityAction("Toggle completion") {
                        onToggle()
                        true
                    }
                )
            }
            .clickable(onClick = onToggle),
    ) {
        Checkbox(checked = task.completed, onCheckedChange = null)
        Text(task.title)
    }
}

// Headings for navigation
Text(
    text = "My Tasks",
    style = MaterialTheme.typography.headlineMedium,
    modifier = Modifier.semantics { heading() },
)

// Live regions for dynamic content
Text(
    text = "3 items remaining",
    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
)
```

5. **Semantics rules:**
   - `mergeDescendants = true` for compound components (card with title + subtitle)
   - `heading()` for section titles (enables TalkBack heading navigation)
   - `liveRegion` for content that updates dynamically (counters, status)
   - `stateDescription` for custom state (not just "checked/unchecked")
   - `Role` for custom interactive elements

### Step 4: Focus Order

6. **Ensure logical focus order:**

```kotlin
// Default: top-to-bottom, start-to-end (matches visual order)
// Override when visual order differs from reading order:

@Composable
fun HeaderWithAction(
    title: String,
    onAction: () -> Unit,
) {
    Row {
        // TalkBack reads title first, then action button
        Text(
            text = title,
            modifier = Modifier
                .weight(1f)
                .semantics { heading() },
        )
        IconButton(onClick = onAction) {
            Icon(Icons.Default.Settings, contentDescription = "Settings")
        }
    }
}

// Focus management for dialogs and sheets:
@Composable
fun TaskDialog(onDismiss: () -> Unit) {
    val focusRequester = remember { FocusRequester() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Delete Task?",
                modifier = Modifier.focusRequester(focusRequester),
            )
        },
        // Request focus when dialog appears
        confirmButton = { /* ... */ },
    )

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }
}
```

### Step 5: Color and Contrast

7. **Don't rely on color alone:**

```kotlin
// BAD: only color distinguishes status
Text(
    text = task.title,
    color = if (task.overdue) Color.Red else Color.Black,
)

// GOOD: color + icon + text
Row {
    if (task.overdue) {
        Icon(
            Icons.Default.Warning,
            contentDescription = null, // Read as part of merged semantics
            tint = MaterialTheme.colorScheme.error,
        )
    }
    Text(
        text = task.title,
        color = if (task.overdue) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurface,
    )
    if (task.overdue) {
        Text(
            text = "Overdue",
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.labelSmall,
        )
    }
}
```

8. **Use Material theme colors** — they're designed for contrast compliance:
   - `onSurface` on `surface` — guaranteed contrast
   - `onPrimary` on `primary` — guaranteed contrast
   - `error` and `onError` — guaranteed contrast

### Step 6: Testing

9. **TalkBack testing (manual):**
   - Enable TalkBack: Settings → Accessibility → TalkBack
   - Swipe right to move to next element
   - Verify announcements make sense without seeing the screen
   - Check that all interactive elements are reachable
   - Verify no elements are skipped or read in wrong order

10. **Accessibility Scanner (automated):**
    - Install from Play Store: "Accessibility Scanner" by Google
    - Run on every screen before shipping
    - Fixes: touch target size, contrast ratio, content descriptions

11. **`android layout` for scriptable accessibility assertions:**

    `android layout --pretty` returns JSON with `content-desc`, `role`, and `bounds` per node — turn it into automated scans you can run from a script or CI step.

    ```bash
    # Fail the build if any Button is missing content-desc
    android layout --pretty \
      | jq -e '.nodes[] | select(.role=="Button" and ((.["content-desc"] // "") == ""))' \
      && echo "FAIL: unlabeled button" && exit 1

    # Flag touch targets smaller than 48dp (assuming density-converted bounds)
    android layout --pretty \
      | jq '.nodes[] | select(.role=="Button") | {id: .["resource-id"], bounds}' \
      | review_target_sizes.sh
    ```

    Use `android layout --diff` after an interaction to inspect only what changed — keeps assertions tight when verifying live regions, error toasts, or focus shifts. When `layout` returns nothing useful (WebView, animation), fall back to `android screen capture --annotate -o screen.png` and visually verify focus order. See `references/android-cli-reference.md`.

    **No device needed for composables:** `android studio render-compose-preview --print-semantics <file> <composable>` emits the accessibility semantics tree of a `@Preview` as JSON — assert on `contentDescription`, `role`, and heading semantics straight from the preview, before anything is installed (requires a running Android Studio with Gemini; see `references/android-cli-reference.md`).

12. **Compose UI tests for accessibility:**

```kotlin
@Test
fun taskItem_hasContentDescription() {
    composeTestRule.setContent {
        TaskItem(task = Task("1", "Buy groceries", false), onToggle = {})
    }

    composeTestRule
        .onNodeWithContentDescription("Buy groceries")
        .assertExists()
}

@Test
fun deleteButton_hasMeaningfulDescription() {
    composeTestRule.setContent {
        TaskItem(task = sampleTask, onToggle = {}, onDelete = {})
    }

    composeTestRule
        .onNodeWithContentDescription("Delete task")
        .assertExists()
        .assertHasClickAction()
}
```

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "We'll add accessibility later" | Retrofitting is 5-10x harder than building accessible from the start. |
| "Our users don't use TalkBack" | 15% of the world's population has a disability. You don't know your users. |
| "ContentDescription is visual boilerplate" | It's the only way screen reader users interact with your app. |
| "Material components handle accessibility" | Material provides a foundation. You still need content descriptions, focus order, and semantic grouping. |
| "Touch targets look too big" | The visual element can be 24dp. The touch target must be 48dp. They're independent. |

## Red Flags

- Images or icons without content descriptions
- Touch targets smaller than 48dp
- Color as the only differentiator
- Missing heading semantics on section titles
- No `mergeDescendants` on compound components
- Hardcoded colors that may not meet contrast ratios
- No TalkBack or Accessibility Scanner testing before release
- `contentDescription = ""` (should be `null` for decorative)

## Verification

- [ ] All meaningful images/icons have descriptive `contentDescription`
- [ ] Decorative elements use `contentDescription = null`
- [ ] All touch targets >= 48dp x 48dp
- [ ] Color is never the only differentiator
- [ ] Section headings use `semantics { heading() }`
- [ ] Compound components use `mergeDescendants = true`
- [ ] Dynamic content uses `liveRegion`
- [ ] Focus order matches logical reading order
- [ ] TalkBack tested on all screens
- [ ] Accessibility Scanner reports zero critical issues
- [ ] Compose tests verify content descriptions exist

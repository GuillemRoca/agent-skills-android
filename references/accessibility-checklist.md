# Accessibility Checklist — Android Reference

## Content Descriptions

- [ ] **All meaningful images/icons** have `contentDescription`
- [ ] **Decorative elements** use `contentDescription = null`
- [ ] **Descriptions are functional**, not visual ("Delete task", not "red trash can")
- [ ] **Dynamic descriptions** include relevant context ("Profile photo of John")
- [ ] **No empty strings** for content descriptions (use `null` for decorative)
- [ ] **IconButtons** — description on the Icon child, not the button

```kotlin
// Meaningful icon
Icon(Icons.Default.Delete, contentDescription = "Delete task")

// Decorative icon
Icon(Icons.Default.Circle, contentDescription = null)

// Dynamic description
Image(
    painter = painterResource(R.drawable.avatar),
    contentDescription = "Profile photo of ${user.name}",
)
```

## Touch Targets

- [ ] **All interactive elements** >= 48dp x 48dp
- [ ] **Visual size can differ** from touch target (icon 24dp, target 48dp)
- [ ] **Spacing between targets** sufficient to prevent mis-taps

```kotlin
IconButton(
    onClick = onAction,
    modifier = Modifier.size(48.dp), // Touch target
) {
    Icon(
        imageVector = Icons.Default.Star,
        contentDescription = "Favorite",
        modifier = Modifier.size(24.dp), // Visual size
    )
}

// For custom clickable elements:
Modifier.defaultMinSize(minHeight = 48.dp, minWidth = 48.dp)
```

## Color & Contrast

- [ ] **Text contrast** >= 4.5:1 (normal text) or >= 3:1 (large text, 18sp+)
- [ ] **UI component contrast** >= 3:1 against adjacent colors
- [ ] **No color-only information** — use icons, text, or patterns as additional cues
- [ ] **Material theme tokens** used (they guarantee contrast compliance)
- [ ] **Both light and dark themes** tested for contrast

```kotlin
// BAD: color-only status
Text(color = if (error) Color.Red else Color.Black)

// GOOD: color + icon + text
Row {
    if (error) Icon(Icons.Default.Error, contentDescription = null)
    Text(
        text = if (error) "Error: $message" else message,
        color = if (error) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurface,
    )
}
```

## Compose Semantics

- [ ] **Section headings** use `semantics { heading() }`
- [ ] **Compound components** use `semantics(mergeDescendants = true)`
- [ ] **Dynamic content** uses `liveRegion = LiveRegionMode.Polite`
- [ ] **Custom states** use `stateDescription` (not just checked/unchecked)
- [ ] **Custom actions** provided via `customActions` where appropriate

```kotlin
// Heading
Text(
    "Tasks",
    modifier = Modifier.semantics { heading() },
)

// Merged component
Row(modifier = Modifier.semantics(mergeDescendants = true) { }) {
    Icon(Icons.Default.Task, contentDescription = null)
    Column {
        Text("Task title")
        Text("Due tomorrow")
    }
}

// Live region
Text(
    "$count items remaining",
    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
)
```

## Focus & Navigation

- [ ] **Focus order** matches logical reading order (top-to-bottom, start-to-end)
- [ ] **No focus traps** — user can navigate away from every element
- [ ] **Dialog focus** — focus moves to dialog when opened, returns on dismiss
- [ ] **Bottom sheet focus** — focus contained within sheet when open
- [ ] **Scrollable content** reachable via TalkBack swipe navigation

```kotlin
// Focus management for dialogs
val focusRequester = remember { FocusRequester() }
LaunchedEffect(Unit) { focusRequester.requestFocus() }

AlertDialog(
    title = {
        Text("Confirm", modifier = Modifier.focusRequester(focusRequester))
    },
    // ...
)
```

## Forms & Input

- [ ] **Text fields** have visible labels (not just placeholder text)
- [ ] **Error messages** associated with the field they describe
- [ ] **Required fields** indicated (not by color alone)
- [ ] **Input types** set correctly (`keyboardType`, `imeAction`)
- [ ] **Auto-fill** supported where appropriate

```kotlin
OutlinedTextField(
    value = title,
    onValueChange = onTitleChange,
    label = { Text("Task title") }, // Accessible label
    isError = titleError != null,
    supportingText = titleError?.let { { Text(it) } },
    keyboardOptions = KeyboardOptions(
        keyboardType = KeyboardType.Text,
        imeAction = ImeAction.Done,
    ),
)
```

## Testing

### TalkBack (Manual)

- [ ] **Enable** TalkBack: Settings → Accessibility → TalkBack
- [ ] **Navigate** through every screen by swiping right
- [ ] **Verify** all announcements make sense without seeing the screen
- [ ] **Check** all interactive elements are reachable
- [ ] **Verify** no elements are skipped or read in wrong order
- [ ] **Test** custom actions (double-tap, long-press)

### Accessibility Scanner (Automated)

- [ ] **Install** Accessibility Scanner from Play Store
- [ ] **Run** on every screen
- [ ] **Fix** all "Error" findings
- [ ] **Review** "Warning" findings

### Compose UI Tests

```kotlin
@Test
fun deleteButton_hasAccessibleDescription() {
    composeTestRule.setContent {
        TaskItem(task = sampleTask, onToggle = {}, onDelete = {})
    }

    composeTestRule
        .onNodeWithContentDescription("Delete task")
        .assertExists()
        .assertHasClickAction()
}

@Test
fun heading_hasSemanticsRole() {
    composeTestRule.setContent {
        Text("Tasks", modifier = Modifier.semantics { heading() })
    }

    composeTestRule
        .onNodeWithText("Tasks")
        .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
}

@Test
fun touchTargets_meetMinimumSize() {
    composeTestRule.setContent {
        IconButton(onClick = {}) {
            Icon(Icons.Default.Add, contentDescription = "Add task")
        }
    }

    composeTestRule
        .onNodeWithContentDescription("Add task")
        .assertTouchHeightIsAtLeast(48.dp)
        .assertTouchWidthIsAtLeast(48.dp)
}
```

## Common Violations

| Violation | Impact | Fix |
|-----------|--------|-----|
| Missing content description | Screen reader skips element | Add descriptive `contentDescription` |
| Touch target < 48dp | Hard to tap for motor disabilities | `Modifier.defaultMinSize(48.dp)` |
| Color-only information | Invisible to color-blind users | Add icon, text, or pattern |
| Missing heading semantics | Can't navigate by headings | `semantics { heading() }` |
| No live region | Dynamic changes not announced | `liveRegion = LiveRegionMode.Polite` |
| Focus trap in overlay | Can't navigate away | Proper dismiss handling |
| Placeholder as label | Label disappears on input | Use `label` parameter |
| Low contrast text | Unreadable for low vision | Use Material theme tokens |

# Android CLI — Reference

Minimal reference for the two `android` CLI capabilities this repo actually prescribes. Everything else is convenience over existing `adb`/`gradlew` workflows and is not prescribed here — see the upstream docs at https://developer.android.com/tools/agents/android-cli.

## Install & Probe

```bash
# Install from https://developer.android.com/tools/agents
android --version       # probe availability
android update          # keep current (CLI is under active development)
android init            # one-time agent setup
```

If `android --version` fails, skills that mention the CLI fall back to their existing `adb`/`developer.android.com` paths. The CLI is never a hard requirement.

## `android layout` — UI Hierarchy as JSON

Returns a structured JSON tree of the current on-device UI. Replaces ad-hoc parsing of `uiautomator dump` XML.

```bash
android layout --pretty --output=hierarchy.json
android layout --diff              # only nodes changed since last snapshot
```

### Node fields agents can depend on

| Field | Meaning | Use for |
|-------|---------|---------|
| `resource-id` | Android view id (e.g. `app:id/btn_send`) | Locating specific views |
| `content-desc` | TalkBack announcement | Accessibility assertions |
| `role` | Semantic role (`Button`, `Image`, `Heading`, …) | Accessibility assertions |
| `bounds` | `[left, top, right, bottom]` in device px | Touch-target size checks (≥ 48dp after density conversion) |
| `text` | Displayed text | Text-based assertions |

### Example: accessibility assertion

```bash
android layout --pretty \
  | jq '.nodes[] | select(.role=="Button" and (.["content-desc"] // "") == "")'
# Emits every unlabeled button → fail accessibility check.
```

## `android docs` — Cite-able Documentation

Returns stable `kb://` URIs that can be cited in code comments and PRs. Satisfies `source-driven-development`'s requirement that every framework API be backed by an official source.

```bash
android docs search "compose recomposition"
# → returns one or more kb:// URIs

android docs fetch kb://android/topic/compose/performance/recomposition
# → returns the document text
```

### Citing a `kb://` source

```kotlin
// Per kb://android/topic/compose/state/remember
val state = remember { mutableStateOf(0) }
```

`kb://` URIs are accepted at priority 1 in the `source-driven-development` source authority hierarchy, alongside `developer.android.com/...` URLs.

## Other CLI Commands (not prescribed)

The CLI also provides `run`, `emulator`, `sdk`, `create`, `describe`, `screen`, and `skills` subcommands. This repo does not prescribe them — existing `adb`, `gradlew`, `sdkmanager`, `avdmanager`, `emulator`, and `reactivecircus/android-emulator-runner` workflows remain canonical in `android-device-testing`, `debugging-and-error-recovery`, and `ci-cd-and-automation`.

See https://developer.android.com/tools/agents/android-cli for the full surface.

## Known Limitations

- `android emulator` is disabled on Windows. Use the `emulator` fallback documented in `android-device-testing`.
- The CLI is actively developed; command flags may shift. Run `android update` before depending on a specific flag.

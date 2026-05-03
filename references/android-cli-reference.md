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

## `android skills` — Discover Catalog Skills

Browse and install skills from the official Android skills catalog at https://github.com/android/skills. `android init` plants the `android-cli` skill into every detected agent harness (`~/.claude/skills/`, `~/.gemini/skills/`, `~/.codex/skills/`, `~/.copilot/skills/`, `~/.junie/skills/`, `~/.config/opencode/skills/`); `android skills` is how you discover and add the rest.

```bash
android skills list                   # installed skills
android skills find <keyword>         # search the catalog by keyword
android skills add <name>             # install a catalog skill (lands in each harness dir)
android skills remove <name>          # uninstall
```

Catalog skills install user-globally per harness. To vendor one into *this* repo so other contributors get it via `claude plugin install`, copy from the harness directory into `skills/`:

```bash
android skills add <name>
cp -r ~/.claude/skills/<name> skills/<name>
```

Then register in `AGENTS.md` (skill directory tree) and `README.md` (phase table). Validate the SKILL.md against the anatomy in `CONTRIBUTING.md` before merging — upstream catalog skills don't always follow this repo's six-section structure and may need adaptation.

## Other CLI Commands (not prescribed)

The CLI also provides `run`, `emulator`, `sdk`, `create`, `describe`, and `screen` subcommands. This repo does not prescribe them as standalone — instead, the relevant skills (`android-device-testing`, `debugging-and-error-recovery`, `ci-cd-and-automation`) reference them where they earn their keep alongside existing `adb`/`gradlew`/`sdkmanager`/`avdmanager`/`emulator`/`reactivecircus/android-emulator-runner` workflows.

See https://developer.android.com/tools/agents/android-cli for the full surface.

## Known Limitations

- `android emulator` is disabled on Windows. Use the `emulator` fallback documented in `android-device-testing`.
- The CLI is actively developed; command flags may shift. Run `android update` before depending on a specific flag.

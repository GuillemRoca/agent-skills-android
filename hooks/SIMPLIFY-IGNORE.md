# Simplify-Ignore Hook

## Purpose

Protects annotated code blocks from modification during `/code-simplify` runs. Some code is intentionally complex — performance-critical paths, platform workarounds, or algorithm implementations that should not be "simplified."

## Annotations

Wrap protected blocks with:

```kotlin
/* simplify-ignore-start */
fun performanceCriticalPath() {
    // This code is intentionally structured for performance
    // and should not be simplified
}
/* simplify-ignore-end */
```

## How It Works

1. **Before simplification** (`protect`): Scans annotated blocks, replaces them with `/* BLOCK_<sha1> */` placeholders, caches originals in `.claude/.simplify-ignore-cache/`
2. **After simplification** (`restore`): Reads placeholders, restores original blocks from cache

## Lifecycle

| Phase | Action |
|-------|--------|
| Before file read | `simplify-ignore.sh protect <file>` |
| After edits | `simplify-ignore.sh restore <file>` |
| Session end | Cleanup cache |

## Requirements

- `jq`, `shasum` or `sha1sum`, Bash 3.2+

## Limitations

- Single-line annotations hide the full line they're on
- Non-standard comment syntaxes (e.g., KDoc inside annotation blocks) may cause issues
- Potential cosmetic whitespace artifacts after restore

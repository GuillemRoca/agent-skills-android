#!/usr/bin/env bash
# simplify-ignore.sh — Protect annotated code blocks from /code-simplify
# Annotations: /* simplify-ignore-start */ and /* simplify-ignore-end */
#
# Usage:
#   simplify-ignore.sh protect <file>   — replace blocks with placeholders
#   simplify-ignore.sh restore <file>   — restore original blocks
#
# Requires: jq, shasum or sha1sum, Bash 3.2+
set -euo pipefail

CACHE_DIR="${CLAUDE_PLUGIN_ROOT:-.}/.claude/.simplify-ignore-cache"
mkdir -p "$CACHE_DIR"

hash_cmd() {
  if command -v shasum &>/dev/null; then
    shasum -a 1 | awk '{print $1}'
  else
    sha1sum | awk '{print $1}'
  fi
}

protect() {
  local file="$1"
  [[ -f "$file" ]] || { echo "File not found: $file" >&2; exit 1; }

  local content
  content=$(cat "$file")
  local modified="$content"
  local changed=false

  while IFS= read -r start_line; do
    local block_start block_end block hash placeholder
    block_start=$(echo "$content" | grep -n '/\* simplify-ignore-start \*/' | head -1 | cut -d: -f1)
    block_end=$(echo "$content" | grep -n '/\* simplify-ignore-end \*/' | head -1 | cut -d: -f1)

    [[ -n "$block_start" && -n "$block_end" ]] || break
    [[ "$block_end" -gt "$block_start" ]] || break

    block=$(echo "$content" | sed -n "${block_start},${block_end}p")
    hash=$(echo "$block" | hash_cmd)
    placeholder="/* BLOCK_${hash} */"

    echo "$block" > "$CACHE_DIR/$hash"
    modified=$(echo "$modified" | sed "${block_start},${block_end}c\\${placeholder}")
    content="$modified"
    changed=true
  done < <(echo "$content" | grep -n '/\* simplify-ignore-start \*/')

  if $changed; then
    echo "$modified" > "$file"
    echo "Protected blocks in $file"
  fi
}

restore() {
  local file="$1"
  [[ -f "$file" ]] || { echo "File not found: $file" >&2; exit 1; }

  local content
  content=$(cat "$file")
  local modified="$content"
  local changed=false

  while IFS= read -r line; do
    local hash
    hash=$(echo "$line" | sed 's|.*/\* BLOCK_\([a-f0-9]*\) \*/.*|\1|')
    [[ -f "$CACHE_DIR/$hash" ]] || continue

    local original
    original=$(cat "$CACHE_DIR/$hash")
    modified=$(echo "$modified" | sed "s|/\* BLOCK_${hash} \*/|$(echo "$original" | sed 's|/|\\/|g; s|&|\\&|g')|")
    rm "$CACHE_DIR/$hash"
    changed=true
  done < <(echo "$content" | grep '/\* BLOCK_[a-f0-9]* \*/')

  if $changed; then
    echo "$modified" > "$file"
    echo "Restored blocks in $file"
  fi
}

case "${1:-}" in
  protect) protect "${2:?Missing file argument}" ;;
  restore) restore "${2:?Missing file argument}" ;;
  *) echo "Usage: $0 {protect|restore} <file>" >&2; exit 1 ;;
esac

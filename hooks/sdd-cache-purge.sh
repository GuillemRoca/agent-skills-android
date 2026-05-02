#!/bin/bash
# sdd-cache-purge.sh — remove a single cache entry by URL, or list/clear all.
#
# Usage:
#   bash hooks/sdd-cache-purge.sh <url>   # remove the entry for this URL
#   bash hooks/sdd-cache-purge.sh --list  # list cached URLs (one per line)
#   bash hooks/sdd-cache-purge.sh --all   # remove every cached entry
#
# The hook itself never deletes entries (except when an origin stops
# emitting validators). This helper is for the "I just discovered the
# cached reading is wrong for my angle" case from SDD-CACHE.md known
# limitations.

set -euo pipefail

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"

usage() {
  cat >&2 <<'USAGE'
sdd-cache-purge.sh <url>     remove the entry for this URL
sdd-cache-purge.sh --list    list cached URLs
sdd-cache-purge.sh --all     remove every entry
USAGE
  exit 1
}

[ "$#" -eq 1 ] || usage

hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

case "$1" in
  --list)
    [ -d "$CACHE_DIR" ] || { echo "(empty)"; exit 0; }
    command -v jq >/dev/null 2>&1 || { echo "jq required for --list" >&2; exit 1; }
    found=0
    for f in "$CACHE_DIR"/*.json; do
      [ -f "$f" ] || continue
      jq -r '.url' "$f" 2>/dev/null && found=1
    done
    [ "$found" -eq 0 ] && echo "(empty)"
    ;;
  --all)
    if [ -d "$CACHE_DIR" ]; then
      rm -f "$CACHE_DIR"/*.json
      echo "purged all entries"
    fi
    ;;
  --*)
    usage
    ;;
  *)
    KEY=$(hash_key "$1")
    FILE="$CACHE_DIR/$KEY.json"
    if [ -f "$FILE" ]; then
      rm -f "$FILE"
      echo "purged: $1"
    else
      echo "no entry for: $1" >&2
      exit 1
    fi
    ;;
esac

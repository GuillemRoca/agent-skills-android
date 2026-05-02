#!/bin/bash
# sdd-cache-selftest.sh — verify the post hook's tool_response shape
# extractor still matches Claude Code's WebFetch output schema.
#
# The post hook depends on a specific JSON shape that Claude Code may
# evolve between releases. Run this script after upgrading Claude Code,
# or in CI, to fail loudly when the extractor stops matching.
#
# Usage:
#   bash hooks/sdd-cache-selftest.sh
#
# Exits 0 on pass, non-zero on any failure. Does not touch the real cache.

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
POST="$HOOKS_DIR/sdd-cache-post.sh"

# Run the post hook in a sandbox so we never write to the project's cache.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
export CLAUDE_PROJECT_DIR="$TMP_DIR"

pass=0
fail=0
report() {
  local status="$1" name="$2" detail="$3"
  if [ "$status" = "pass" ]; then
    printf '  ok    %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s — %s\n' "$name" "$detail"
    fail=$((fail + 1))
  fi
}

# Each test pipes a synthetic stdin payload to the post hook and asserts
# either (a) an entry was written under .claude/sdd-cache/, or (b) no
# entry was written. We compare on file count rather than content so
# transient origin behavior (no validators emitted) doesn't false-fail
# the *extractor* test — the test is "did extraction succeed", not "did
# the origin happen to return Last-Modified".
#
# We can't observe extraction success directly without instrumenting the
# hook. Instead we set SDD_CACHE_DEBUG=1 and grep the debug log for the
# "extracted content bytes=N" line emitted only when extraction worked.

run_case() {
  local name="$1" stdin="$2" expect="$3"  # expect: "extract" | "no-extract"
  rm -rf "$TMP_DIR/.claude"
  printf '%s' "$stdin" | SDD_CACHE_DEBUG=1 bash "$POST" >/dev/null 2>&1 || true
  local log="$TMP_DIR/.claude/sdd-cache/.debug.log"
  if [ ! -f "$log" ]; then
    report fail "$name" "no debug log produced"
    return
  fi
  if grep -q "extracted content bytes=" "$log"; then
    if [ "$expect" = "extract" ]; then
      report pass "$name" ""
    else
      report fail "$name" "extracted but expected no-extract"
    fi
  else
    if [ "$expect" = "no-extract" ]; then
      report pass "$name" ""
    else
      report fail "$name" "extractor missed (debug log: $(tail -1 "$log"))"
    fi
  fi
}

echo "Running sdd-cache extractor self-test..."

# The host MUST be on the allowlist for the post hook to reach the
# extraction stage. Use kotlinlang.org which is on the default list.
URL_OK="https://kotlinlang.org/docs/coroutines-overview.html"

# Shape 1: object with .result (current Claude Code WebFetch shape, 2026-04)
run_case "object.result" \
  "{\"tool_input\":{\"url\":\"$URL_OK\",\"prompt\":\"x\"},\"tool_response\":{\"bytes\":12,\"code\":200,\"result\":\"hello world\"}}" \
  extract

# Shape 2: object with only .output (defensive fallback)
run_case "object.output" \
  "{\"tool_input\":{\"url\":\"$URL_OK\",\"prompt\":\"x\"},\"tool_response\":{\"output\":\"hello world\"}}" \
  extract

# Shape 3: top-level string (older / custom integrations)
run_case "string" \
  "{\"tool_input\":{\"url\":\"$URL_OK\",\"prompt\":\"x\"},\"tool_response\":\"hello world\"}" \
  extract

# Shape 4: object with no recognizable content key — must NOT extract
run_case "object.unknown" \
  "{\"tool_input\":{\"url\":\"$URL_OK\",\"prompt\":\"x\"},\"tool_response\":{\"unrecognized\":\"hello\"}}" \
  no-extract

# Shape 5: missing .tool_input.url — must NOT extract
run_case "no-url" \
  "{\"tool_input\":{\"prompt\":\"x\"},\"tool_response\":\"hello\"}" \
  no-extract

# Shape 6: oversized content — must NOT cache
big=$(printf '%*s' 1100000 ' ')   # > 1 MiB cap
run_case "oversize-content" \
  "{\"tool_input\":{\"url\":\"$URL_OK\",\"prompt\":\"x\"},\"tool_response\":\"$big\"}" \
  no-extract

# Shape 7: private host — must NOT cache (SSRF guard fires before extract)
run_case "private-host" \
  "{\"tool_input\":{\"url\":\"https://localhost:9200/_cat\",\"prompt\":\"x\"},\"tool_response\":\"hello\"}" \
  no-extract

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

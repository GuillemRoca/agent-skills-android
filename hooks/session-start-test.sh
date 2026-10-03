#!/bin/bash
# session-start-test.sh - Tests for the SessionStart hook JSON payload.
# Covers the meta-skill, missing-meta-skill, and missing-jq paths, and checks
# the plugin does not auto-register the hook. Needs jq to validate payloads.
#
# Usage: bash hooks/session-start-test.sh

set -euo pipefail

cd "$(dirname "$0")/.."
HOOK="hooks/session-start.sh"
BASH_BIN="$(command -v bash)"
failures=0

empty_root="$(mktemp -d)"
no_jq_bin="$(mktemp -d)"
trap 'rm -rf "$empty_root" "$no_jq_bin"' EXIT

fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }

# assert_payload <label> <payload> <expected substring of additionalContext>
assert_payload() {
  local label="$1" payload="$2" expected="$3" ctx
  if ! jq -e . >/dev/null 2>&1 <<<"$payload"; then
    fail "$label: payload is not valid JSON"; return
  fi
  if [ "$(jq -r '.hookSpecificOutput.hookEventName // empty' <<<"$payload")" != "SessionStart" ]; then
    fail "$label: missing hookSpecificOutput.hookEventName == SessionStart (hosts reject other shapes)"; return
  fi
  ctx="$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$payload")"
  if [ -z "${ctx//[[:space:]]/}" ]; then
    fail "$label: additionalContext must be a non-empty string"; return
  fi
  if [[ "$ctx" != *"$expected"* ]]; then
    fail "$label: additionalContext is missing '$expected'"; return
  fi
  echo "ok: $label"
}

assert_payload "meta-skill injected" \
  "$(CLAUDE_PLUGIN_ROOT="$PWD" bash "$HOOK")" "# Using Agent Skills (Android)"

assert_payload "meta-skill missing" \
  "$(CLAUDE_PLUGIN_ROOT="$empty_root" bash "$HOOK")" "meta-skill not found"

# PATH holds only the external tools the script needs, minus jq.
for tool in cat dirname; do ln -s "$(command -v "$tool")" "$no_jq_bin/$tool"; done
assert_payload "jq missing" \
  "$(PATH="$no_jq_bin" CLAUDE_PLUGIN_ROOT="$PWD" "$BASH_BIN" "$HOOK")" "jq is required"

# Claude Code routes skills natively; auto-injecting the meta-skill adds a second router.
if [ -f hooks/hooks.json ] && jq -e '.hooks.SessionStart' hooks/hooks.json >/dev/null 2>&1; then
  fail "hooks/hooks.json registers SessionStart — the plugin must not auto-inject the meta-skill"
else
  echo "ok: plugin does not register SessionStart"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "session-start hook tests passed"

#!/usr/bin/env bash
# Session-start hook: injects the using-agent-skills meta-skill into context
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
META_SKILL="$PLUGIN_ROOT/skills/using-agent-skills/SKILL.md"

if [[ -f "$META_SKILL" ]]; then
  CONTENT=$(cat "$META_SKILL")
  cat <<EOF
{
  "message": "Agent Skills (Android) loaded. Use the skill discovery flowchart below to find the right skill for your task.\n\n$CONTENT"
}
EOF
else
  cat <<EOF
{
  "message": "Agent Skills (Android) plugin active but meta-skill not found at $META_SKILL. Skills are in skills/*/SKILL.md."
}
EOF
fi

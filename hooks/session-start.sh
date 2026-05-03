#!/bin/bash
# agent-skills (Android) session start hook
# Injects the using-agent-skills meta-skill into every new session.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
META_SKILL="$PLUGIN_ROOT/skills/using-agent-skills/SKILL.md"

if ! command -v jq >/dev/null 2>&1; then
  echo '{"priority": "INFO", "message": "agent-skills (Android): jq is required for the session-start hook but was not found on PATH. Install jq (e.g. `brew install jq` or `apt-get install jq`) to enable meta-skill injection. Skills remain available individually under skills/*/SKILL.md."}'
  exit 0
fi

if [ -f "$META_SKILL" ]; then
  CONTENT=$(cat "$META_SKILL")
  jq -cn \
    --arg message "Agent Skills (Android) loaded. Use the skill discovery flowchart below to find the right skill for your task.

$CONTENT" \
    '{priority: "IMPORTANT", message: $message}'
else
  echo '{"priority": "INFO", "message": "agent-skills (Android): using-agent-skills meta-skill not found at '"$META_SKILL"'. Skills may still be available individually."}'
fi

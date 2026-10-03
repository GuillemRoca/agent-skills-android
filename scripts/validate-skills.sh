#!/usr/bin/env bash
# Validates every skills/*/SKILL.md against the contract in CONTRIBUTING.md:
#   - frontmatter `name` matches the kebab-case directory name (<= 64 chars)
#   - frontmatter `description` starts with "Use when" (<= 1024 chars)
#   - the six required sections are present (meta-skill exempt)
#   - body is <= 500 lines
#   - AGENTS.md and README.md skill listings match the skills on disk
#   - prose skill counts ("All 30 Skills", "30 specialized workflows",
#     "all 30 at once") in the docs and skills match the skills on disk
# Runs in CI on every PR; run locally before pushing a skill change.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Skills exempt from the six-section anatomy (see CONTRIBUTING.md "Meta-skill exemption")
META_SKILLS=("using-agent-skills")

FAIL=0
err() { echo "FAIL: $1"; FAIL=1; }

is_meta() {
  local s
  for s in "${META_SKILLS[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

# Extract a single-line-or-folded frontmatter scalar (handles `>-` blocks).
frontmatter_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    $0 ~ "^" field ":" {
      val = $0; sub("^" field ":[[:space:]]*", "", val)
      if (val == ">-" || val == ">" || val == "|" || val == "|-") { folded = 1; next }
      print val; exit
    }
    folded {
      if ($0 ~ /^[a-zA-Z_-]+:/ || $0 == "---") exit
      line = $0; sub(/^[[:space:]]+/, "", line)
      printf "%s%s", sep, line; sep = " "
    }
  ' "$file"
}

SKILL_DIRS=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)

for dir in $SKILL_DIRS; do
  skill="$(basename "$dir")"
  file="$dir/SKILL.md"

  [[ -f "$file" ]] || { err "$skill: missing SKILL.md"; continue; }

  # Directory naming
  [[ "$skill" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || err "$skill: directory is not kebab-case"

  # Frontmatter
  head -1 "$file" | grep -q '^---$' || { err "$skill: missing YAML frontmatter"; continue; }

  name="$(frontmatter_field "$file" name)"
  description="$(frontmatter_field "$file" description)"

  [[ -n "$name" ]] || err "$skill: frontmatter has no 'name'"
  [[ "$name" == "$skill" ]] || err "$skill: frontmatter name '$name' != directory name"
  (( ${#name} <= 64 )) || err "$skill: name exceeds 64 chars (${#name})"

  [[ -n "$description" ]] || err "$skill: frontmatter has no 'description'"
  [[ "$description" == "Use when"* ]] || err "$skill: description must start with 'Use when'"
  (( ${#description} <= 1024 )) || err "$skill: description exceeds 1024 chars (${#description})"

  # Line cap
  lines=$(wc -l < "$file")
  (( lines <= 500 )) || err "$skill: SKILL.md is $lines lines (cap 500)"

  # Six-section anatomy (meta-skills keep Overview + Verification only)
  required_sections=("## Overview" "## Verification")
  if ! is_meta "$skill"; then
    required_sections+=("## When to Use" "## Core Process" "## Common Rationalizations" "## Red Flags")
  fi
  for section in "${required_sections[@]}"; do
    grep -q "^${section}" "$file" || err "$skill: missing section '$section'"
  done
done

# AGENTS.md / README.md consistency: every skill on disk is listed, and
# every `skill-name` mentioned in the directory tree/tables exists on disk.
for doc in AGENTS.md README.md; do
  for dir in $SKILL_DIRS; do
    skill="$(basename "$dir")"
    grep -q "$skill" "$doc" || err "$doc: does not mention skill '$skill'"
  done
done

# Reverse check: skills referenced in AGENTS.md tree that don't exist
while IFS= read -r ref; do
  [[ -d "skills/$ref" ]] || err "AGENTS.md: references non-existent skill '$ref'"
done < <(grep -oE '[a-z0-9-]+/SKILL\.md' AGENTS.md | cut -d/ -f1 | sort -u)

# Prose skill counts must match the skills on disk. Matches "N skills",
# "N Android skills", "N specialized workflows" and "all N"; ranges such as
# "2–3 skills" are advice, not counts, and are skipped.
SKILL_COUNT=$(echo "$SKILL_DIRS" | wc -l | tr -d ' ')
COUNT_PATTERN='([0-9]+[–-])?[0-9]+ (Android |specialized )?(skills|Skills|workflows)\b|\b[Aa]ll [0-9]+\b'
while IFS= read -r hit; do
  location="${hit%:*}"   # file:line
  match="${hit##*:}"
  [[ "$match" =~ [0-9][–-] ]] && continue
  n="$(grep -oE '[0-9]+' <<< "$match" | head -1)"
  [[ "$n" == "$SKILL_COUNT" ]] || err "$location: says '$match' but there are $SKILL_COUNT skills"
done < <(grep -noE "$COUNT_PATTERN" README.md AGENTS.md CONTRIBUTING.md docs/*.md skills/*/SKILL.md || true)

if (( FAIL )); then
  echo "Skill validation failed."
  exit 1
fi
echo "OK: $SKILL_COUNT skills validated."

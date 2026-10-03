#!/usr/bin/env bash
# Validates every skills/*/SKILL.md against the contract in CONTRIBUTING.md:
#   - frontmatter `name` matches the kebab-case directory name (<= 64 chars)
#   - frontmatter `description` starts with "Use when" (<= 1024 chars)
#   - the six required sections are present (meta-skill exempt)
#   - body is <= 500 lines
#   - AGENTS.md and README.md skill listings match the skills on disk
#   - prose skill counts ("All 30 Skills", "30 specialized workflows",
#     "all 30 at once") in the docs and skills match the skills on disk
#   - frontmatter keys are in the Agent Skills spec set, and single-line
#     values avoid the YAML forms hosts reject (tabs, unclosed quotes,
#     leading indicators, unquoted ": ")
#   - skill directories hold no empty subdirectories, and supporting .md
#     files are kebab-case
#   - every `references/*.md` path in a skill resolves from that file
#   - relative markdown links in the docs and skills resolve, and any
#     #anchor matches a heading in the target (fenced code is exempt)
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

# Top-level frontmatter keys allowed by the Agent Skills spec. Anything else
# (model hints, tool limits, host switches) goes under `metadata`: hosts don't
# promise to ignore unknown keys, and a strict one rejects the skill.
SPEC_KEYS=" name description license compatibility metadata allowed-tools "

# Print one line per frontmatter problem a YAML host would reject. Only
# top-level lines are checked; indented lines are block-scalar or `metadata`
# content, where these rules don't apply.
frontmatter_problems() {
  awk -v spec="$SPEC_KEYS" '
    NR == 1 { next }
    $0 == "---" { exit }
    /^[ ]*\t/ { printf "frontmatter line %d indents with a tab (invalid YAML)\n", NR; next }
    /^[ \t]/ || /^$/ { next }
    {
      colon = index($0, ":")
      if (colon == 0) { printf "frontmatter line %d is not a key: value pair\n", NR; next }
      key = substr($0, 1, colon - 1)
      if (index(spec, " " key " ") == 0)
        printf "frontmatter key %s is not in the Agent Skills spec (move it under metadata)\n", key
      val = substr($0, colon + 1); sub(/^[ \t]+/, "", val); sub(/[ \t]+$/, "", val)
      if (val == "" || val ~ /^[|>][-+]?$/) next
      q = substr(val, 1, 1)
      if (q == "\"" || q == "'\''") {
        if (length(val) < 2 || substr(val, length(val), 1) != q)
          printf "frontmatter line %d opens a quote that never closes\n", NR
        next
      }
      if (val ~ /^[`@%*,]/ || val ~ /^[|>][^ \t]/ || val ~ /^[-?&]([ \t]|$)/)
        printf "frontmatter line %d starts an unquoted value with a YAML indicator; quote it\n", NR
      else if (val ~ /:([ \t]|$)/)
        printf "frontmatter line %d has an unquoted value containing \": \"; quote it or fold it with >-\n", NR
    }
  ' "$1"
}

# GitHub-style heading anchors for a markdown file, one per line. Headings
# inside fenced code don't count; repeated headings get -1, -2, ... suffixes.
heading_slugs() {
  LC_ALL=C awk '
    /^[ ]*(```|~~~)/ { fence = !fence; next }
    fence || !/^#{1,6} / { next }
    {
      h = $0; sub(/^#+ +/, "", h); sub(/ +#+ *$/, "", h)
      h = tolower(h)
      gsub(/[^a-z0-9 _-]/, "", h)
      gsub(/ /, "-", h)
      if (h in seen) { seen[h]++; print h "-" seen[h] } else { seen[h] = 0; print h }
    }
  ' "$1"
}

# Markdown with fenced code blocks blanked out (line numbers preserved), so
# examples inside fences are never treated as links.
without_fences() {
  awk '/^[ ]*(```|~~~)/ { fence = !fence; print ""; next } { print (fence ? "" : $0) }' "$1"
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

  while IFS= read -r problem; do
    [[ -n "$problem" ]] && err "$skill: $problem"
  done < <(frontmatter_problems "$file")

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

  # Layout: no empty subdirectories, supporting .md files are kebab-case
  while IFS= read -r empty; do
    err "$skill: empty directory '${empty#"$dir"/}/' (remove it)"
  done < <(find "$dir" -mindepth 1 -type d -empty)
  while IFS= read -r support; do
    base="$(basename "$support" .md)"
    [[ "$base" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || err "$skill: supporting file '${support#"$dir"/}' is not kebab-case"
  done < <(find "$dir" -mindepth 2 -type f -name '*.md')
done

# `references/*.md` paths in a skill must resolve from the file that names
# them: shared checklists are `../../references/x.md` from SKILL.md, a skill's
# own files are `references/x.md`. Fenced code is exempt.
while IFS= read -r md; do
  while IFS= read -r hit; do
    lineno="${hit%%:*}"
    ref="${hit#*:}"
    path="${ref%%#*}"
    target="$(dirname "$md")/$path"
    if [[ ! -f "$target" ]]; then
      err "$md:$lineno: '$path' does not resolve from this file (shared checklists are ../../references/<file>.md)"
    elif [[ "$ref" == *"#"* ]] && ! heading_slugs "$target" | grep -qxF "${ref#*#}"; then
      err "$md:$lineno: '$ref' — no heading '#${ref#*#}' in $path"
    fi
  done < <(without_fences "$md" | grep -noE '(^|[^A-Za-z0-9._/-])(\.\./)*references/[A-Za-z0-9._-]+\.md(#[a-z0-9_-]+)?' \
             | sed -E 's/^([0-9]+):[^.r]*/\1:/')
done < <(find skills -name '*.md' | sort)

# Relative markdown links resolve, and #anchors match a heading. Covers the
# docs, personas, commands, references and skills; fenced code is exempt.
while IFS= read -r md; do
  while IFS= read -r hit; do
    lineno="${hit%%:*}"
    link="${hit#*](}"; link="${link%)}"
    link="${link%% *}"                       # drop a "title" after the URL
    [[ "$link" =~ ^(https?:|mailto:) ]] && continue
    path="${link%%#*}"
    anchor=""; [[ "$link" == *"#"* ]] && anchor="${link#*#}"
    if [[ -z "$path" ]]; then
      target="$md"
    else
      target="$(dirname "$md")/$path"
      [[ -e "$target" ]] || { err "$md:$lineno: link target '$path' does not exist"; continue; }
    fi
    if [[ -n "$anchor" && "$target" == *.md ]] && ! heading_slugs "$target" | grep -qxF "$anchor"; then
      err "$md:$lineno: link '$link' — no heading '#$anchor' in ${path:-this file}"
    fi
  done < <(without_fences "$md" | grep -noE '\]\([^)[:space:]]+( "[^"]*")?\)')
done < <(find README.md AGENTS.md CONTRIBUTING.md docs references agents hooks skills .claude/commands -name '*.md' | sort)

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

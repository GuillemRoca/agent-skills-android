#!/bin/bash
# sdd-cache-post.sh — PostToolUse hook for WebFetch.
#
# After WebFetch, stores the response body in .claude/sdd-cache/<sha>.json
# with the current ETag / Last-Modified captured via a HEAD request so the
# pre hook can revalidate on the next fetch.
#
# Keyed by URL. The caller's prompt is stored as metadata (not part of the
# key) so a future cache hit can show what question produced the cached
# reading. Entries without ETag or Last-Modified are not cached.
#
# Dependencies: jq, curl, shasum (or sha256sum).

set -euo pipefail

command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# Debug logging: active when SDD_CACHE_DEBUG=1 is set, or when a sentinel
# file exists at .claude/sdd-cache/.debug. Toggle with `touch` / `rm`.
# Log auto-truncates past 10 MiB. URLs are logged without query strings so
# OAuth / signed-URL credentials don't land on disk.
dbg() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
  [ "${SDD_CACHE_DEBUG:-0}" = "1" ] || [ -f "$dir/.debug" ] || return 0
  mkdir -p "$dir"
  local log="$dir/.debug.log"
  if [ -f "$log" ] && [ "$(wc -c <"$log" 2>/dev/null || echo 0)" -gt 10485760 ]; then
    : > "$log"
  fi
  printf '%s [post] %s\n' "$(date -u +%FT%TZ)" "$*" >> "$log"
}
redact_url() { printf '%s' "${1%%\?*}"; }
dbg "fired"

URL=$(printf '%s'    "$INPUT" | jq -r '.tool_input.url    // empty' 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
if [ -z "$URL" ]; then dbg "no url in tool_input, exit"; exit 0; fi
dbg "url=$(redact_url "$URL") prompt-len=${#PROMPT}"

# SSRF defense. Reject obviously-private hosts before any network I/O.
URL_HOST=$(printf '%s' "$URL" | sed -E 's|^[a-z]+://([^/:]+).*|\1|' | tr '[:upper:]' '[:lower:]')
case "$URL_HOST" in
  localhost|127.*|0.0.0.0|169.254.*|10.*|::1|fe80:*|fc00:*|fd*:*) dbg "private host, skip caching"; exit 0 ;;
  192.168.*) dbg "private host, skip caching"; exit 0 ;;
  172.1[6-9].*|172.2[0-9].*|172.3[01].*) dbg "private host, skip caching"; exit 0 ;;
esac

# Origin allowlist. Only cache responses from documented doc origins; an
# attacker-steered fetch to a malicious host won't get cached, which keeps
# the cache hit message ("Use the cached content as if WebFetch had just
# returned it") trustworthy. Override via SDD_CACHE_ALLOWED_HOSTS
# (space-separated) when caching additional sources is intentional.
DEFAULT_ALLOW="developer.android.com kotlinlang.org material.io m3.material.io developers.google.com firebase.google.com gradle.org square.github.io kotlin.github.io android.googlesource.com"
ALLOWED="${SDD_CACHE_ALLOWED_HOSTS:-$DEFAULT_ALLOW}"
host_allowed=0
for entry in $ALLOWED; do
  case "$URL_HOST" in
    "$entry"|*."$entry") host_allowed=1; break ;;
  esac
done
if [ "$host_allowed" -eq 0 ]; then
  dbg "host $URL_HOST not on allowlist, skip caching"
  exit 0
fi

# Truncate the persisted prompt. Full prompts are useful for "is this
# reading still relevant" but anything beyond a couple of sentences risks
# capturing inadvertently quoted secrets ("compare against API key foo=...")
# that end up on disk and re-surface to future agents.
PROMPT_MAX=400
if [ "${#PROMPT}" -gt "$PROMPT_MAX" ]; then
  PROMPT="${PROMPT:0:$PROMPT_MAX}…"
  dbg "prompt truncated to $PROMPT_MAX chars"
fi

# WebFetch tool_response shape (Claude Code as of 2026-04): an object with
# keys bytes, code, codeText, durationMs, result, url — content lives at
# .result. The other keys (.output / .text / .content / .body) are kept as
# defensive fallbacks in case the shape changes; jq returns empty if none
# match. The string branch handles older/custom integrations.
TOOL_RESPONSE_TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_response | type' 2>/dev/null || echo "unknown")
dbg "tool_response type=$TOOL_RESPONSE_TYPE keys=$(printf '%s' "$INPUT" | jq -r 'try (.tool_response | keys | join(",")) catch "n/a"' 2>/dev/null)"

CONTENT=$(printf '%s' "$INPUT" | jq -r '
  if (.tool_response | type) == "object" then
    (.tool_response.result
     // .tool_response.output
     // .tool_response.text
     // .tool_response.content
     // .tool_response.body
     // empty)
  elif (.tool_response | type) == "string" then
    .tool_response
  else
    empty
  end
' 2>/dev/null || true)

if [ -z "$CONTENT" ]; then
  dbg "WARN: could not extract content from tool_response (shape may have changed)"
  exit 0
fi

# Reject oversized bodies. Holding multi-MiB content in a shell variable
# slows everything down, blows past the hook's 10s timeout when re-emitted
# on a hit, and isn't useful for doc-page caching. 1 MiB covers every
# realistic Android/Kotlin/Material doc page with headroom.
CONTENT_MAX=1048576
if [ "${#CONTENT}" -gt "$CONTENT_MAX" ]; then
  dbg "content size ${#CONTENT} exceeds cap $CONTENT_MAX, skip caching"
  exit 0
fi
dbg "extracted content bytes=${#CONTENT}"

# Must match the pre hook: sha256(URL), first 32 hex chars.
hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR" 2>/dev/null || true
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

# Capture validators + final URL from the origin. Try HEAD first (cheap);
# fall back to GET-with-discarded-body if the origin strips validators on
# HEAD (some CDNs do, including parts of developer.android.com behind GFE).
# --proto / --proto-redir block scheme escalation on malicious redirects.
URL_EFFECTIVE=""
fetch_headers() {
  local method="$1"  # HEAD or GET
  local headers_out url_effective_out
  if [ "$method" = "HEAD" ]; then
    headers_out=$(curl -sI -L --max-time 5 \
      --proto '=https' --proto-redir '=https' \
      -w '\n%{url_effective}\n' \
      "$URL" 2>/dev/null | tr -d '\r' || true)
  else
    headers_out=$(curl -s -L --max-time 5 \
      --proto '=https' --proto-redir '=https' \
      -o /dev/null -D - \
      -w '\n%{url_effective}\n' \
      "$URL" 2>/dev/null | tr -d '\r' || true)
  fi
  # url_effective comes after the headers (own line); split it off.
  url_effective_out=$(printf '%s' "$headers_out" | awk 'END{print}')
  printf '%s' "$headers_out" | sed '$d'
  URL_EFFECTIVE_LATEST="$url_effective_out"
}

extract_header() {
  local name="$1" headers_in="$2"
  printf '%s' "$headers_in" | awk -v h="$name" '
    BEGIN { FS = ":" }
    tolower($1) == tolower(h) {
      sub(/^[^:]*:[ \t]*/, "")
      sub(/[ \t]+$/, "")
      gsub(/[\r\n\t]/, "")  # defense-in-depth: strip header-injection chars
      print
      exit
    }
  '
}

# Take only the final response's headers (last paragraph) to avoid picking
# up validators from intermediate 301/302 hops.
final_headers() {
  printf '%s' "$1" | awk '
    BEGIN { RS = ""; last = "" }
    { last = $0 }
    END { print last }
  '
}

URL_EFFECTIVE_LATEST=""
HEAD_OUT=$(fetch_headers "HEAD")
FINAL=$(final_headers "$HEAD_OUT")
ETAG=$(extract_header "ETag" "$FINAL")
LAST_MOD=$(extract_header "Last-Modified" "$FINAL")
URL_EFFECTIVE="$URL_EFFECTIVE_LATEST"
dbg "HEAD etag-len=${#ETAG} last_modified-len=${#LAST_MOD}"

if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "HEAD returned no validators, falling back to GET"
  GET_OUT=$(fetch_headers "GET")
  FINAL=$(final_headers "$GET_OUT")
  ETAG=$(extract_header "ETag" "$FINAL")
  LAST_MOD=$(extract_header "Last-Modified" "$FINAL")
  URL_EFFECTIVE="$URL_EFFECTIVE_LATEST"
  dbg "GET fallback etag-len=${#ETAG} last_modified-len=${#LAST_MOD}"
fi

# Sanity-cap validator lengths to defeat malformed/hostile origin headers.
ETAG="${ETAG:0:512}"
LAST_MOD="${LAST_MOD:0:128}"

if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "no validator from origin (HEAD or GET), removing any stale entry and exit"
  rm -f "$CACHE_FILE"
  exit 0
fi

NOW=$(date +%s)

# Integrity HMAC. Defends against another local process implanting a
# poisoned cache file under .claude/sdd-cache/ — without the per-cache
# secret in .key, an attacker cannot produce a valid HMAC even if they
# know the URL, ETag, and content. .key is generated lazily on first
# write with chmod 600. Skipped silently when openssl is absent; the
# pre hook treats a missing hmac field as "integrity not enforced for
# this entry" and falls through to its existing freshness checks.
HMAC=""
KEY_FILE="$CACHE_DIR/.key"
if command -v openssl >/dev/null 2>&1; then
  if [ ! -f "$KEY_FILE" ]; then
    if head -c 32 /dev/urandom 2>/dev/null | base64 > "$KEY_FILE.tmp"; then
      chmod 600 "$KEY_FILE.tmp" 2>/dev/null || true
      mv "$KEY_FILE.tmp" "$KEY_FILE"
      dbg "generated cache integrity key"
    else
      rm -f "$KEY_FILE.tmp"
    fi
  fi
  if [ -f "$KEY_FILE" ]; then
    KEY=$(cat "$KEY_FILE" 2>/dev/null || true)
    if [ -n "$KEY" ]; then
      HMAC=$(printf '%s\037%s\037%s\037%s' \
        "${URL_EFFECTIVE:-$URL}" "$ETAG" "$LAST_MOD" "$CONTENT" \
        | openssl dgst -sha256 -hmac "$KEY" 2>/dev/null \
        | awk '{print $NF}')
      dbg "computed hmac len=${#HMAC}"
    fi
  fi
fi

TMP="${CACHE_FILE}.$$.tmp"
if jq -n \
  --arg url            "$URL" \
  --arg url_effective  "${URL_EFFECTIVE:-$URL}" \
  --arg prompt         "$PROMPT" \
  --arg etag           "$ETAG" \
  --arg last_modified  "$LAST_MOD" \
  --arg content        "$CONTENT" \
  --arg hmac           "$HMAC" \
  --argjson fetched_at "$NOW" \
  '{url: $url, url_effective: $url_effective, prompt: $prompt, etag: $etag, last_modified: $last_modified, content: $content, hmac: $hmac, fetched_at: $fetched_at}' \
  > "$TMP"
then
  chmod 600 "$TMP" 2>/dev/null || true
  mv "$TMP" "$CACHE_FILE"
  dbg "wrote cache file"
else
  rm -f "$TMP"
  dbg "jq failed, temp cleaned"
fi

exit 0

#!/bin/bash
# sdd-cache-pre.sh — PreToolUse hook for WebFetch.
#
# HTTP resource cache keyed by URL. Freshness is delegated to the origin via
# HTTP validators; 304 Not Modified is the only signal to serve from cache.
# On hit, exits 2 and writes the cached body to stderr so Claude Code can
# deliver it to the agent in place of the WebFetch result. Otherwise exits 0.
#
# No TTL: if validators don't catch a change, nothing will. Entries without
# ETag or Last-Modified are never cached (can't revalidate).
#
# Cached bodies are prompt-shaped (WebFetch post-processes through a model),
# so the key is URL-only and the original prompt is surfaced in the hit
# message so the next agent can tell if the earlier reading still applies.
#
# Dependencies: jq, curl, shasum (or sha256sum).

set -euo pipefail

# Graceful degradation: if any dependency is missing, let the fetch through.
command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# Debug logging: active when SDD_CACHE_DEBUG=1 is set, or when a sentinel
# file exists at .claude/sdd-cache/.debug. Toggle with `touch` / `rm`.
# Log auto-truncates past 10 MiB to prevent unbounded growth on long sessions
# with debug left on. URLs are logged with query strings stripped so OAuth /
# signed-URL credentials don't land on disk.
dbg() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
  [ "${SDD_CACHE_DEBUG:-0}" = "1" ] || [ -f "$dir/.debug" ] || return 0
  mkdir -p "$dir"
  local log="$dir/.debug.log"
  if [ -f "$log" ] && [ "$(wc -c <"$log" 2>/dev/null || echo 0)" -gt 10485760 ]; then
    : > "$log"
  fi
  printf '%s [pre]  %s\n' "$(date -u +%FT%TZ)" "$*" >> "$log"
}
redact_url() { printf '%s' "${1%%\?*}"; }
dbg "fired"

URL=$(printf '%s' "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null || true)
if [ -z "$URL" ]; then dbg "no url in tool_input, exit"; exit 0; fi
dbg "url=$(redact_url "$URL")"

# SSRF defense. Reject obviously-private hosts before any network I/O.
# DNS rebinding can defeat this; --proto-redir below is the second line.
URL_HOST=$(printf '%s' "$URL" | sed -E 's|^[a-z]+://([^/:]+).*|\1|' | tr '[:upper:]' '[:lower:]')
case "$URL_HOST" in
  localhost|127.*|0.0.0.0|169.254.*|10.*|::1|fe80:*|fc00:*|fd*:*) dbg "private host, bypass"; exit 0 ;;
  192.168.*) dbg "private host, bypass"; exit 0 ;;
  172.1[6-9].*|172.2[0-9].*|172.3[01].*) dbg "private host, bypass"; exit 0 ;;
esac

# Origin allowlist (must match post hook). If a URL is not on the list it
# was never cached in the first place; skip the cache lookup entirely so
# we don't issue a revalidation request to a host we wouldn't store.
DEFAULT_ALLOW="developer.android.com kotlinlang.org material.io m3.material.io developers.google.com firebase.google.com gradle.org square.github.io kotlin.github.io android.googlesource.com"
ALLOWED="${SDD_CACHE_ALLOWED_HOSTS:-$DEFAULT_ALLOW}"
host_allowed=0
for entry in $ALLOWED; do
  case "$URL_HOST" in
    "$entry"|*."$entry") host_allowed=1; break ;;
  esac
done
if [ "$host_allowed" -eq 0 ]; then
  dbg "host $URL_HOST not on allowlist, bypass"
  exit 0
fi

# Cache key is sha256(URL), truncated to 128 bits.
hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

if [ ! -f "$CACHE_FILE" ]; then dbg "no cache file at $CACHE_FILE, exit"; exit 0; fi
dbg "cache file exists: $CACHE_FILE"

FETCHED_AT=$(jq -r '.fetched_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0)
ORIGINAL_PROMPT=$(jq -r '.prompt // empty' "$CACHE_FILE" 2>/dev/null || true)
ETAG=$(jq -r '.etag // empty' "$CACHE_FILE" 2>/dev/null || true)
LAST_MOD=$(jq -r '.last_modified // empty' "$CACHE_FILE" 2>/dev/null || true)
URL_EFFECTIVE=$(jq -r '.url_effective // empty' "$CACHE_FILE" 2>/dev/null || true)
STORED_HMAC=$(jq -r '.hmac // empty' "$CACHE_FILE" 2>/dev/null || true)
STORED_CONTENT=$(jq -r '.content // empty' "$CACHE_FILE" 2>/dev/null || true)

# Integrity check. If the entry was written with an HMAC and we have
# openssl + the key file, recompute and compare. Mismatch = the cache
# file was tampered with after we wrote it; delete and bypass. Entries
# without an HMAC field (older entries, or written on a system without
# openssl) skip this check and rely on the freshness rules below.
KEY_FILE="$CACHE_DIR/.key"
if [ -n "$STORED_HMAC" ] && command -v openssl >/dev/null 2>&1 && [ -f "$KEY_FILE" ]; then
  KEY=$(cat "$KEY_FILE" 2>/dev/null || true)
  if [ -n "$KEY" ]; then
    EXPECTED=$(printf '%s\037%s\037%s\037%s' \
      "${URL_EFFECTIVE:-$URL}" "$ETAG" "$LAST_MOD" "$STORED_CONTENT" \
      | openssl dgst -sha256 -hmac "$KEY" 2>/dev/null \
      | awk '{print $NF}')
    if [ "$EXPECTED" != "$STORED_HMAC" ]; then
      dbg "WARN: hmac mismatch (cache tampered or key rotated), purging entry"
      rm -f "$CACHE_FILE"
      exit 0
    fi
    dbg "hmac verified"
  fi
fi

# No validator means we cannot verify freshness — never serve from cache.
# (Should be unreachable: post hook refuses to write entries without
# validators. If this fires, the cache file was corrupted or hand-edited.)
if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "WARN: cached entry missing validators (post-hook bug or hand-edited file), bypass"
  exit 0
fi

# Revalidate against the URL the post hook actually saw after redirects, if
# we recorded one. Falls back to the agent-requested URL for cache entries
# written before url_effective was tracked.
REVAL_URL="${URL_EFFECTIVE:-$URL}"

HEADERS=()
[ -n "$ETAG" ]     && HEADERS+=(-H "If-None-Match: $ETAG")
[ -n "$LAST_MOD" ] && HEADERS+=(-H "If-Modified-Since: $LAST_MOD")

# Conditional GET (not HEAD) because some CDNs strip validators on HEAD or
# return 405. Body is discarded; on 304 there's no body anyway.
# --proto / --proto-redir block scheme escalation (https→file/ftp/etc) on
# malicious redirects; complements the host-based private-IP check above.
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 3 -L \
  --proto '=https' --proto-redir '=https' \
  "${HEADERS[@]}" \
  "$REVAL_URL" 2>/dev/null || echo "000")
dbg "revalidation GET status=$STATUS"

if [ "$STATUS" != "304" ]; then
  dbg "not 304, letting WebFetch proceed"
  exit 0
fi

# Server confirmed content unchanged. Serve cached copy to the agent.
if [ -z "$STORED_CONTENT" ]; then dbg "cache file has empty content field, bypass"; exit 0; fi
dbg "cache HIT, blocking WebFetch with ${#STORED_CONTENT} bytes of cached content"

VERIFIED_AT_ISO=$(date -u -r "$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "@$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "unknown")

# Emit the payload with printf so $CONTENT is never interpreted by the shell
# (docs contain backticks, $vars, and backslashes in code examples; an
# unquoted heredoc would treat them as command substitution).
{
  printf '[sdd-cache] Cache hit for %s\n\n' "$URL"
  printf 'Revalidated via HTTP 304; unchanged since %s. Use the cached\n' "$VERIFIED_AT_ISO"
  printf 'content below as if WebFetch had just returned it.\n\n'
  if [ -n "$ORIGINAL_PROMPT" ]; then
    printf 'Original WebFetch prompt: "%s". If your angle differs, judge\n' "$ORIGINAL_PROMPT"
    printf 'whether this reading still covers it.\n\n'
  fi
  printf -- '----- BEGIN CACHED CONTENT -----\n'
  printf '%s\n' "$STORED_CONTENT"
  printf -- '----- END CACHED CONTENT -----\n'
} >&2
exit 2

# sdd-cache hook

Cross-session citation cache for [`source-driven-development`](../skills/source-driven-development/SKILL.md). Skips redundant `WebFetch` calls without weakening the skill's "verify against current docs" guarantee.

## Why

`source-driven-development` fetches official docs (Android developer docs, Jetpack reference, Kotlin docs, Material 3 spec, Gradle docs, etc.) for every framework-specific decision. Working on the same project across sessions means fetching the same pages over and over. Caching the content as local memory would contradict the skill — docs change, and a stale cache hides that.

This hook caches fetched content on disk, but **revalidates with the origin server on every reuse** via HTTP `If-None-Match` / `If-Modified-Since`. Content is only served from cache when the server responds `304 Not Modified`, which is a fresh verification — not a memory read.

## Setup

The cache is **opt-in** — it isn't auto-registered by the plugin's `hooks.json` because it requires `jq`, `curl`, and `shasum` and writes to `.claude/sdd-cache/` in your project. To enable it, add hooks to `.claude/settings.json` (or `.claude/settings.local.json` for personal use):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/sdd-cache-pre.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/sdd-cache-post.sh",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`${CLAUDE_PLUGIN_ROOT}` resolves to this plugin's root when installed via the marketplace. If you cloned the repo manually and the hooks live elsewhere, replace `${CLAUDE_PLUGIN_ROOT}/hooks/...` with the absolute path to each script.

Add `.claude/sdd-cache/` to your `.gitignore` (or your project's global gitignore) so cached responses aren't committed.

Use the `source-driven-development` skill (or any `WebFetch` against documentation) as usual. No changes to the skill or the agent's workflow — the cache is transparent.

## Mental model

HTTP resource cache keyed by URL. Freshness is delegated to the origin via `ETag` / `Last-Modified`; no TTL, no prompt in the key.

The stored body is not raw HTML — `WebFetch` post-processes each response through a model using the caller's prompt, so what we cache is one agent's reading of the page. The key stays URL-only so reads reuse across sessions; the original prompt is kept as metadata and surfaced in the hit message so the next agent can tell whether the earlier reading fits.

## How it works

One cache entry per URL, stored as JSON in `.claude/sdd-cache/<sha>.json`:

| Event | Action |
|---|---|
| `PreToolUse WebFetch` | If an entry exists, sends a conditional `GET` (with body discarded) to the URL the post hook recorded after redirects, with `If-None-Match` / `If-Modified-Since`. On `304`, blocks the fetch and returns the cached content to the agent via stderr, with the original prompt surfaced as metadata. Otherwise allows the fetch. |
| `PostToolUse WebFetch` | Captures the response, issues a `HEAD` to record the current `ETag` / `Last-Modified` (falling back to a discarded-body `GET` when the origin strips validators on `HEAD`), records the post-redirect URL, and stores `{url, url_effective, prompt, etag, last_modified, content, fetched_at}`. |

**Freshness rules:**

- Entry is served only if the origin confirms `304 Not Modified`.
- Entries without an `ETag` or `Last-Modified` header are never cached — without a validator, the hook cannot verify freshness later, and caching would mean trusting memory.
- Any non-`304` response (including network errors, `4xx`, `5xx`, redirects to a different scheme/host than `https`) bypasses the cache and lets `WebFetch` proceed normally.
- Revalidation runs against the post-redirect URL the post hook recorded, not the URL the agent asked for. Prevents false `304`s when an upstream `301` chain changes between sessions.
- Cache key is `sha256(url)`. The same URL asked with a different prompt hits the same entry; the cached body reflects the prompt used on the first fetch, and that prompt is shown alongside the hit so the agent can decide whether to re-use or re-fetch manually.
- Cached prompts are truncated to 400 characters before storage. The hit message shows the truncated form.
- Bodies larger than 1 MiB are not cached.

**What the agent sees:**

- Cache hit: `WebFetch` is blocked via exit code 2. Claude Code delivers the hook's stderr payload back to the agent as a tool error — this is the intended signal for a cache hit, not a failure. The payload is prefixed with `[sdd-cache] Cache hit for <url>` and wraps the cached body between `----- BEGIN CACHED CONTENT -----` / `----- END CACHED CONTENT -----` markers so the agent can use it as if `WebFetch` had just returned it.
- Cache miss or stale: `WebFetch` runs normally; the result is stored for next time.

The skill itself is unchanged. It continues to follow `DETECT → FETCH → IMPLEMENT → CITE`. The hook only changes what happens under the hood when `FETCH` runs.

## Local testing

### 1. Smoke test the scripts directly

```bash
# Simulate a PostToolUse payload: cache an Android docs page
echo '{
  "tool_input": {
    "url": "https://developer.android.com/jetpack/compose/state",
    "prompt": "summarize StateFlow vs MutableStateFlow patterns"
  },
  "tool_response": "Compose state hoisting pattern: keep MutableStateFlow private, expose as StateFlow..."
}' | bash hooks/sdd-cache-post.sh

# Inspect the stored entry
ls .claude/sdd-cache/
cat .claude/sdd-cache/*.json | jq .

# Simulate the next PreToolUse on the same URL + prompt
echo '{
  "tool_input": {
    "url": "https://developer.android.com/jetpack/compose/state",
    "prompt": "summarize StateFlow vs MutableStateFlow patterns"
  }
}' | bash hooks/sdd-cache-pre.sh
echo "exit=$?"
```

Expected:

- First command creates one file under `.claude/sdd-cache/` (only if the server returned an `ETag` or `Last-Modified`).
- Second command exits `2` with the cached content on stderr when the origin replies `304`, or exits `0` silently otherwise.

### 2. End-to-end in a real session

1. Register the hooks in `.claude/settings.local.json` as shown above.
2. Start a Claude Code session in this repo or any Android project.
3. Ask the agent to fetch a documentation page (e.g. "fetch `https://developer.android.com/jetpack/androidx/releases/compose-runtime` and summarize").
4. Verify a file appears under `.claude/sdd-cache/`.
5. Ask the agent to fetch the same page with the same prompt again.
6. Verify the second `WebFetch` is blocked and the cached content is returned (visible in the session transcript as a tool error with `[sdd-cache]` prefix).

### 3. Freshness verification

To confirm the cache invalidates when docs change, force an `ETag` mismatch. Pick one specific entry — `*.json` is unsafe once the cache holds more than one file:

```bash
# Pick the entry you want to corrupt (swap in the actual filename)
ENTRY=.claude/sdd-cache/e49c9f378670cfbb1d7d871b6dee16d9.json

# Patch its ETag to something the origin will not recognize
jq '.etag = "W/\"stale-etag-forced\""' "$ENTRY" > "$ENTRY.tmp" && mv "$ENTRY.tmp" "$ENTRY"

# Next PreToolUse should miss (server returns 200, not 304)
echo '{"tool_input":{"url":"...", "prompt":"..."}}' | bash hooks/sdd-cache-pre.sh
echo "exit=$?"   # expect 0 (fetch allowed through)
```

### 4. Negative-path recipes

These exercise the freshness-strict invariants the cache's value rests on. Each should produce the documented behavior; any deviation is a regression.

```bash
# (a) Corrupt cache file → graceful bypass (must not error to the agent)
URL="https://kotlinlang.org/docs/coroutines-overview.html"
KEY=$(printf '%s' "$URL" | shasum -a 256 | cut -c1-32)
mkdir -p .claude/sdd-cache && echo "garbage" > ".claude/sdd-cache/$KEY.json"
echo "{\"tool_input\":{\"url\":\"$URL\",\"prompt\":\"x\"}}" | bash hooks/sdd-cache-pre.sh
echo "exit=$?"   # expect 0
rm -f ".claude/sdd-cache/$KEY.json"

# (b) Network unreachable → fetch-through within timeout
URL="https://10.255.255.1/no-route"   # private + unroutable
time (echo "{\"tool_input\":{\"url\":\"$URL\",\"prompt\":\"x\"}}" | bash hooks/sdd-cache-pre.sh)
# expect: exit 0 within ~1s (private-host guard) — does not hit network at all

# (c) Private-host SSRF guard
echo '{"tool_input":{"url":"http://169.254.169.254/latest/meta-data/","prompt":"x"}}' \
  | bash hooks/sdd-cache-pre.sh; echo "exit=$?"   # expect 0, no curl issued
echo '{"tool_input":{"url":"https://localhost:9200/_cat","prompt":"x"}}' \
  | bash hooks/sdd-cache-post.sh; echo "exit=$?"  # expect 0, no entry written

# (d) Concurrent post-hooks for the same URL → one valid file remains
URL="https://kotlinlang.org/docs/coroutines-overview.html"
PAYLOAD="{\"tool_input\":{\"url\":\"$URL\",\"prompt\":\"a\"},\"tool_response\":\"body\"}"
( echo "$PAYLOAD" | bash hooks/sdd-cache-post.sh ) &
( echo "$PAYLOAD" | bash hooks/sdd-cache-post.sh ) &
wait
ls .claude/sdd-cache/                        # expect exactly one *.json file
jq . .claude/sdd-cache/*.json >/dev/null && echo "ok"   # expect "ok"
```

### 5. Schema-drift self-test

The post hook depends on Claude Code's `WebFetch` `tool_response` shape. After upgrading Claude Code (or in CI), run:

```bash
bash hooks/sdd-cache-selftest.sh
```

The script feeds the post hook seven synthetic payloads (current `object.result` shape, three defensive fallbacks, and three negative cases) and asserts that extraction succeeds or fails as expected. It writes only to a `mktemp -d` sandbox, never to your real cache. Exit non-zero on any failure means the extractor needs updating before the post hook will silently no-op against the new schema.

### 6. Debugging

Both hooks write timestamped events to `.claude/sdd-cache/.debug.log` when debug mode is on. Enable it with either:

```bash
# Option A: env var (per-session)
SDD_CACHE_DEBUG=1 claude

# Option B: sentinel file (persistent)
mkdir -p .claude/sdd-cache && touch .claude/sdd-cache/.debug
# …disable with: rm .claude/sdd-cache/.debug
```

The log captures URL, detected `tool_response` shape, HEAD status, and why each invocation hit or missed. Useful when a cache miss looks unexpected (typically: the origin stopped emitting validators).

## Security model

Hooks execute with the **user's full shell privileges** on every `WebFetch`. Anything that can modify these scripts — a malicious PR merged into the plugin, a `git pull` from a compromised fork, a marketplace update to a tampered tag — gains arbitrary code execution at the moment a `WebFetch` fires. Review the scripts before enabling, pin to a tagged release if your environment requires it, and enable the cache only in projects where you would already trust a `postinstall` script.

The hook is intentionally narrow:

- **Scheme allowlist.** Both hooks pass `--proto '=https' --proto-redir '=https'` to `curl`, so an `https` URL that redirects to `http://`, `file://`, `gopher://`, or any non-`https` scheme is dropped.
- **Private-IP guard.** Hosts matching `localhost`, `127.*`, `10.*`, `192.168.*`, `172.16-31.*`, `169.254.*`, `::1`, `fc00:*`, `fe80:*` skip caching and revalidation entirely. DNS rebinding can defeat name-based checks; the scheme-redir guard is the second line of defense.
- **Origin allowlist.** Both hooks only act on URLs whose host is on a list of documented doc origins (`developer.android.com`, `kotlinlang.org`, `material.io`, `developers.google.com`, `firebase.google.com`, `gradle.org`, `square.github.io`, `kotlin.github.io`, `m3.material.io`, `android.googlesource.com`, plus their subdomains). Override with `SDD_CACHE_ALLOWED_HOSTS="host1 host2 ..."` if you need to cache from additional sources. An attacker-steered fetch to a host outside the list is never cached, so the cache hit message ("Use the cached content as if WebFetch had just returned it") cannot be weaponized against allowlisted-doc trust.
- **No code in cache.** The `<sha>.json` files are read with `jq` and emitted via `printf '%s'` — never `eval`'d, sourced, or interpolated unquoted. A poisoned cache file can mislead the *agent* (prompt-injection-via-doc-body), but not the shell.
- **Cache files are `0600`, directory `0700`.** Reduces the surface for another local process implanting prompt-injection content under your home directory.
- **Integrity HMAC (when `openssl` is available).** Each cache entry stores an HMAC-SHA256 over `(url_effective, etag, last_modified, content)` keyed by a per-cache secret in `.claude/sdd-cache/.key` (32 bytes from `/dev/urandom`, base64-encoded, `chmod 600`). On read, the pre hook recomputes and compares — a tampered or implanted file is purged on the spot. Skipped silently when `openssl` is missing; entries written without an HMAC fall through to the freshness checks alone. Rotate the key by deleting `.key` and `*.json`; both hooks regenerate transparently.

Things the hook does **not** defend against:

- **Prompt persistence.** `tool_input.prompt` is stored verbatim (truncated to 400 chars) in `<sha>.json` and surfaced to the next agent on a hit. If you embed secrets in `WebFetch` prompts (`"compare against API key foo=…"`), they land on disk and cross-session-leak. Avoid quoting secrets in fetch prompts.
- **Debug-log persistence.** When debug mode is on, the redacted URL (no query string), prompt length, status codes, and validator lengths are appended to `.claude/sdd-cache/.debug.log` (auto-truncated past 10 MiB). Enable debug only when investigating a miss; disable when done.
- **Cache poisoning by agent context.** A `WebFetch` against an attacker-controlled doc URL caches that content under the same trust framing as legit docs. Mitigation: don't enable the cache in projects where agents fetch arbitrary user-supplied URLs.

## Known limitations

- **Body is prompt-shaped.** A hit returns the earlier agent's reading of the page, with the original prompt surfaced so the current agent can decide whether it applies. If it doesn't, delete the file under `.claude/sdd-cache/` to force a re-fetch.
- **Every cache write costs at least one extra request.** Claude Code doesn't expose the response headers that `WebFetch` already received, so the post hook re-queries the origin to capture `ETag` / `Last-Modified`. `HEAD` first; falls back to a discarded-body `GET` when the origin strips validators on `HEAD` (parts of `developer.android.com` behind Google Frontend do this). The post hook is `async: true` so the latency doesn't reach the user.
- **Servers without `ETag` or `Last-Modified` on either `HEAD` or `GET` are never cached.** Most official Android/Jetpack/Kotlin doc pages emit validators (`developer.android.com`, `kotlinlang.org`, `material.io`). Sites that don't are always re-fetched.
- **A misbehaving server can serve a wrong `304`.** That's a server bug to diagnose, not a cache invariant to defend against; we don't paper over it with a TTL. Delete the entry if you spot a stale one.
- **Cache is local and per-project.** There is no team-wide shared cache. Adding one would require a signed-content-addressable storage layer, which is out of scope.

## Cache management

- **List cached URLs:** `bash hooks/sdd-cache-purge.sh --list`
- **Purge one entry:** `bash hooks/sdd-cache-purge.sh https://developer.android.com/...`
- **Purge everything:** `bash hooks/sdd-cache-purge.sh --all`
- **Force re-fetch of a single page:** purge it; the next `WebFetch` repopulates the entry.
- **Rotate the integrity key:** delete `.claude/sdd-cache/.key` and `.claude/sdd-cache/*.json`. Both hooks regenerate the key on the next write.

The hook itself never deletes entries except when an origin stops emitting validators (post hook, on the next fetch) or when the integrity HMAC mismatches (pre hook, on the next read). All other deletes are user-driven.

## Requirements

- `jq`
- `curl`
- `shasum` or `sha256sum` (auto-detected)
- `openssl` (optional — enables cache integrity HMAC; absent = HMAC skipped)
- Bash 3.2+

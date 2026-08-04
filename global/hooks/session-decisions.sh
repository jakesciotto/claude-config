#!/usr/bin/env bash
# SessionEnd hook: extract the session's design decisions and upsert them to Supabase (configs.decisions).
# One row per design fork. Sibling of session-summary.sh, deliberately a separate script so a JSON
# parse failure here cannot break the summary lane.
#
# Secrets are shared with that hook, in ~/.claude/hooks/.session-summary.env (NOT in git):
#   SUPABASE_URL=https://jselgaytmwlstuuhrwzj.supabase.co
#   SUPABASE_SERVICE_KEY=<service_role key>
#
# Reads the SessionEnd payload on stdin. Pass --dry-run to print the rows instead of posting them.

set -euo pipefail

# Re-entry guard: the claude -p below triggers SessionEnd, which fires this hook AND session-summary.sh.
# Bail if either headless extraction is already in flight, or they recurse.
if [ -n "${CLAUDE_DECISIONS_RUNNING:-}" ] || [ -n "${CLAUDE_SUMMARY_RUNNING:-}" ]; then
  exit 0
fi

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

PAYLOAD=$(cat)
ENV_FILE="$HOME/.claude/hooks/.session-summary.env"
LOG="$HOME/.claude/hooks/session-decisions.log"

# Keep the tail only. An append-only hook log in ~/.claude grows unbounded and
# nothing else prunes it.
if [ -f "$LOG" ] && [ "$(wc -c <"$LOG" | tr -d ' ')" -gt 262144 ]; then
  tail -c 131072 "$LOG" >"$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"
fi

CLAUDE_BIN="$HOME/.local/bin/claude"
MODEL="claude-sonnet-5"

read -r -d '' PROMPT <<'EOP' || true
You are extracting a decision log from a Claude Code session transcript.

Output ONLY a JSON array. No prose, no markdown fences, no explanation.

Each element has this shape:
{"decision":"...","rationale":"...","alternatives":["..."],"decided_by":"agent|user|joint","category":"..."}

Include ONLY genuine design forks: points where a path was chosen among alternatives that were
actually in play. Schema shape, library, mechanism, architecture, scope calls, what to defer.

Exclude tool calls, routine implementation steps, naming, restatements of what was built, and
anything that had no alternative under consideration.

Field rules:
- decision: one sentence, past tense, specific. What was chosen.
- rationale: why that option won, using the reason actually given in the transcript. If no reason
  was stated, use null. Do not invent one.
- alternatives: the rejected options, as short strings. Empty array if none were named.
- decided_by: "user" if the user picked it, including selecting from options presented to them.
  "agent" if the assistant resolved it without asking. "joint" if it converged through back-and-forth.
- category: prefer one of architecture, data-model, tooling, scope, process. Other values allowed.

At most 10 elements, ordered as they occurred.
If the session contained no design forks, output exactly: []
EOP

extract() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "$(date -u +%FT%TZ) no env file, skipping"
    return 0
  fi
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  : "${SUPABASE_URL:?}" "${SUPABASE_SERVICE_KEY:?}"

  transcript_path=$(jq -r '.transcript_path // empty' <<<"$PAYLOAD")
  session_id=$(jq -r '.session_id // empty' <<<"$PAYLOAD")
  cwd=$(jq -r '.cwd // empty' <<<"$PAYLOAD")

  if [ -z "$session_id" ]; then
    echo "$(date -u +%FT%TZ) no session_id in payload"
    return 0
  fi
  if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    echo "$(date -u +%FT%TZ) no transcript ($session_id)"
    return 0
  fi

  # Gate out headless runs. The CLAUDE_*_RUNNING guards above only cover the two hooks
  # we own; any third-party SessionEnd hook that shells out to `claude -p` (hogpilot's
  # capture hook does) spawns a transcript this hook would then ingest as a real session.
  # entrypoint is read off the transcript, so it holds regardless of who spawned it.
  # Interactive runs report "cli", headless ones "sdk-cli"; missing is treated as headless
  # (fail safe - skipping costs one session, recursing pollutes the table).
  entrypoint=$(jq -rs 'map(.entrypoint // empty) | first // ""' "$transcript_path" 2>/dev/null || echo "")
  if [ "$entrypoint" != "cli" ]; then
    echo "$(date -u +%FT%TZ) headless transcript, skipping ($session_id, entrypoint=${entrypoint:-none})"
    return 0
  fi

  project=$(basename "${cwd:-unknown}")

  # Flatten user/assistant text turns into plain conversation text (same shape as session-summary.sh).
  convo=$(jq -rs '
    map(select(.type=="user" or .type=="assistant"))
    | map(
        ((.message.role // .type)) as $role
        | (.message.content
            | if type=="array" then (map(.text // empty) | join("\n"))
              elif type=="string" then .
              else "" end) as $text
        | select(($text|length) > 0)
        | "[\($role)] \($text)"
      )
    | join("\n\n")
  ' "$transcript_path" 2>/dev/null || echo "")

  if [ -z "$convo" ]; then
    echo "$(date -u +%FT%TZ) empty convo ($session_id)"
    return 0
  fi

  # Keep the head AND the tail. Unlike a summary, a decision log cannot afford to lose the end of a
  # long session: late forks are often the load-bearing ones.
  bytes=$(printf '%s' "$convo" | wc -c | tr -d ' ')
  if [ "$bytes" -gt 120000 ]; then
    convo="$(printf '%s' "$convo" | head -c 40000)

[... $((bytes - 120000)) chars elided from the middle ...]

$(printf '%s' "$convo" | tail -c 80000)"
  fi

  export CLAUDE_DECISIONS_RUNNING=1
  raw=$(printf '%s' "$convo" | "$CLAUDE_BIN" -p --model "$MODEL" "$PROMPT" 2>>"$LOG" || echo "")

  if [ -z "$raw" ]; then
    echo "$(date -u +%FT%TZ) extractor returned nothing ($session_id)"
    return 0
  fi

  json=$(printf '%s' "$raw" | sed '/^[[:space:]]*```/d')

  # The extractor is non-deterministic and intermittently wraps the array in a sentence of prose.
  # Salvage the outermost bracket span and retry before giving up on the session.
  if ! printf '%s' "$json" | jq -e 'type=="array"' >/dev/null 2>&1; then
    json=$(printf '%s' "$json" | awk '{ buf = buf $0 "\n" } END {
      s = index(buf, "[")
      if (s == 0) exit
      e = 0
      for (i = length(buf); i > 0; i--) if (substr(buf, i, 1) == "]") { e = i; break }
      if (e > s) printf "%s", substr(buf, s, e - s + 1)
    }')
  fi

  if ! printf '%s' "$json" | jq -e 'type=="array"' >/dev/null 2>&1; then
    # Keep the whole output, not a truncated snippet: an intermittent parse failure is only
    # diagnosable if the raw text survives.
    dump="$HOME/.claude/hooks/session-decisions-failed-$(date -u +%Y%m%dT%H%M%SZ).txt"
    printf '%s' "$raw" >"$dump" 2>/dev/null || true
    echo "$(date -u +%FT%TZ) non-JSON output ($session_id), raw saved to $dump"
    return 0
  fi

  rows=$(printf '%s' "$json" | jq -c \
    --arg session_id "$session_id" \
    --arg project "$project" \
    --arg cwd "$cwd" '
    [ .[] | select((((.decision // "") | tostring) | gsub("^\\s+|\\s+$";"")) != "") ]
    | to_entries
    | map(
        .key as $i | .value as $d
        | (($d.decided_by // "") | tostring) as $by
        | {
            session_id: $session_id,
            seq: ($i + 1),
            project: $project,
            cwd: $cwd,
            decision: ($d.decision | tostring),
            rationale: (if ($d.rationale // null) == null or (($d.rationale | tostring) == "") then null else ($d.rationale | tostring) end),
            alternatives: (if (($d.alternatives // null) | type) == "array" then ($d.alternatives | map(tostring)) else [] end),
            decided_by: (if (["agent","user","joint"] | index($by)) then $by else null end),
            category: (if (($d.category // "") | tostring) == "" then null else ($d.category | tostring) end)
          }
      )')

  n=$(printf '%s' "$rows" | jq 'length')
  if [ "$n" -eq 0 ]; then
    echo "$(date -u +%FT%TZ) no decisions ($session_id, $project)"
    return 0
  fi

  if [ -n "$DRY_RUN" ]; then
    printf '%s\n' "$rows" | jq .
    return 0
  fi

  # on_conflict is required: without it PostgREST upserts on the primary key (an auto-generated uuid,
  # never present in the payload), so a re-run would duplicate and then trip unique(session_id, seq).
  if ! printf '%s' "$rows" | curl -sS -X POST \
      "$SUPABASE_URL/rest/v1/decisions?on_conflict=session_id,seq" \
      -H "apikey: $SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates" \
      --data-binary @- >>"$LOG" 2>&1; then
    echo "$(date -u +%FT%TZ) post failed ($session_id)"
    return 0
  fi

  # Prune any tail left by a longer earlier extraction. The extractor is not deterministic, so a
  # re-run yielding fewer decisions would otherwise leave stale high-seq rows from the previous run,
  # mixing two extractions in one session. Ordered after the upsert deliberately: a failed prune
  # leaves a recoverable stale tail, whereas pruning first would risk deleting with nothing to replace.
  if ! curl -sS -X DELETE \
      "$SUPABASE_URL/rest/v1/decisions?session_id=eq.$session_id&seq=gt.$n" \
      -H "apikey: $SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" >>"$LOG" 2>&1; then
    echo "$(date -u +%FT%TZ) wrote $n decisions for $session_id ($project), tail prune failed"
    return 0
  fi

  echo "$(date -u +%FT%TZ) wrote $n decisions for $session_id ($project)"
}

if [ -n "$DRY_RUN" ]; then
  extract
else
  # Background everything; return control to the harness immediately.
  { extract; } >>"$LOG" 2>&1 &
fi

exit 0

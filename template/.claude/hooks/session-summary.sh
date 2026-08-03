#!/usr/bin/env bash
# SessionEnd hook: summarize the session and upsert it to Supabase (configs.claude_sessions).
# Forks the heavy work to the background so session teardown never blocks on the API call.
# Secrets live in ~/.claude/hooks/.session-summary.env (NOT in git):
#   SUPABASE_URL=https://jselgaytmwlstuuhrwzj.supabase.co
#   SUPABASE_SERVICE_KEY=<service_role key>

set -euo pipefail

# Re-entry guard: claude -p below also triggers SessionEnd, which fires this hook AND
# session-decisions.sh. Exit if either headless extraction is already in flight, or they recurse.
if [ -n "${CLAUDE_SUMMARY_RUNNING:-}" ] || [ -n "${CLAUDE_DECISIONS_RUNNING:-}" ]; then
  exit 0
fi

PAYLOAD=$(cat)
ENV_FILE="$HOME/.claude/hooks/.session-summary.env"
LOG="$HOME/.claude/hooks/session-summary.log"
CLAUDE_BIN="$HOME/.local/bin/claude"

# Background everything; return control to the harness immediately.
{
  [ -f "$ENV_FILE" ] || { echo "$(date -u +%FT%TZ) no env file, skipping"; exit 0; }
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  : "${SUPABASE_URL:?}" "${SUPABASE_SERVICE_KEY:?}"

  transcript_path=$(jq -r '.transcript_path // empty' <<<"$PAYLOAD")
  session_id=$(jq -r '.session_id // empty' <<<"$PAYLOAD")
  cwd=$(jq -r '.cwd // empty' <<<"$PAYLOAD")
  reason=$(jq -r '.reason // empty' <<<"$PAYLOAD")

  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || { echo "$(date -u +%FT%TZ) no transcript ($session_id)"; exit 0; }

  # Gate out headless runs. The CLAUDE_*_RUNNING guards above only cover the two hooks
  # we own; any third-party SessionEnd hook that shells out to `claude -p` (hogpilot's
  # capture hook does) spawns a transcript this hook would then summarize as a real
  # session. entrypoint is read off the transcript, so it holds regardless of who spawned
  # it. Interactive runs report "cli", headless ones "sdk-cli"; missing is treated as
  # headless (fail safe - skipping costs one session, recursing pollutes the table).
  entrypoint=$(jq -rs 'map(.entrypoint // empty) | first // ""' "$transcript_path" 2>/dev/null || echo "")
  [ "$entrypoint" = "cli" ] || { echo "$(date -u +%FT%TZ) headless transcript, skipping ($session_id, entrypoint=${entrypoint:-none})"; exit 0; }

  project=$(basename "${cwd:-unknown}")
  msg_count=$(wc -l <"$transcript_path" | tr -d ' ')

  # Flatten user/assistant text turns into plain conversation text.
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

  [ -n "$convo" ] || { echo "$(date -u +%FT%TZ) empty convo ($session_id)"; exit 0; }

  export CLAUDE_SUMMARY_RUNNING=1
  summary=$(printf '%s' "$convo" | head -c 120000 | "$CLAUDE_BIN" -p --model claude-sonnet-4-6 \
    "Summarize this Claude Code session in 3-6 terse bullet points: what was worked on, key decisions, and outcomes. Output only the bullets, no preamble." \
    2>>"$LOG" || echo "")
  [ -n "$summary" ] || summary="(summary unavailable)"

  jq -n \
    --arg session_id "$session_id" \
    --arg project "$project" \
    --arg cwd "$cwd" \
    --arg reason "$reason" \
    --arg summary "$summary" \
    --arg transcript_path "$transcript_path" \
    --argjson message_count "${msg_count:-0}" \
    '{session_id:$session_id, project:$project, cwd:$cwd, reason:$reason, summary:$summary, transcript_path:$transcript_path, message_count:$message_count}' \
  | curl -sS -X POST "$SUPABASE_URL/rest/v1/claude_sessions" \
      -H "apikey: $SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates" \
      --data-binary @- >>"$LOG" 2>&1 \
  && echo "$(date -u +%FT%TZ) wrote $session_id ($project, $msg_count msgs)" >>"$LOG"
} >>"$LOG" 2>&1 &

exit 0

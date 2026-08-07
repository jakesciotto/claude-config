#!/usr/bin/env bash
# SessionEnd hook: critic pass -- extract rich transcript projection and produce
# discrete findings rows upserted to Supabase (configs.session_findings).
# Forks to background so teardown never blocks. Shares secrets with session-summary.sh.
#
# Reads the SessionEnd payload on stdin. Pass --dry-run to print rows instead of posting.

set -euo pipefail

# Re-entry guard: claude -p below triggers SessionEnd which fires all three hooks.
# Bail if any of them are already running.
if [ -n "${CLAUDE_CRITIC_RUNNING:-}" ] || [ -n "${CLAUDE_SUMMARY_RUNNING:-}" ] || [ -n "${CLAUDE_DECISIONS_RUNNING:-}" ]; then
  exit 0
fi

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

PAYLOAD=$(cat)
ENV_FILE="$HOME/.claude/hooks/.session-summary.env"
LOG="$HOME/.claude/hooks/session-critic.log"

# Keep the tail only. An append-only hook log in ~/.claude grows unbounded.
if [ -f "$LOG" ] && [ "$(wc -c <"$LOG" | tr -d ' ')" -gt 262144 ]; then
  tail -c 131072 "$LOG" >"$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"
fi

CLAUDE_BIN="$HOME/.local/bin/claude"
MODEL="claude-sonnet-5"

read -r -d '' PROMPT <<'EOP' || true
You are a critic reviewing a Claude Code session. Your job is to identify both what went well and what went poorly.

Output ONLY a JSON array. No prose, no markdown fences, no explanation.

Each element has this shape:
{"finding":"...","went_well":true,"category":"...","severity":"...","target_kind":"...","target_ref":"...","evidence":"..."}

Field rules:
- finding: one sentence, past tense, specific. What happened.
- went_well: true if the thing worked correctly; false if it was a gap or mistake.
- category: exactly one of: skill-discipline, model-selection, process, tool-use, communication, scope
- severity: exactly one of: low, medium, high. Only applies to went_well=false; use "low" for went_well=true.
- target_kind: "skill" if a skill is the lever, "process" if a process step, "hook" if a hook, null if none.
- target_ref: the specific skill name (e.g. "hogql-gotchas", "verification-before-completion") or process slug, or null.
- evidence: short quote or tool name anchoring the finding. Required when went_well=false; optional for true.

Category definitions:
- skill-discipline: skill invoked out of order, skipped, or wrong one loaded
- model-selection: tier escalation without justification, or over-powered model for trivial work
- process: skipped verification, committed without confirm, destructive op without guard
- tool-use: unnecessary Agent spawn, Bash where Read/Edit was right, over-agentification
- communication: verbose where terse needed, missing key user update, silence mid-task
- scope: implemented beyond what was asked, premature abstraction added

The transcript below includes both text turns (prefixed [user]/[assistant]) and tool events (prefixed [tool]).
Tool events list: tool name, and for Skill calls the skill arg, for Agent calls the description.

Include went_well=true findings for skills that fired correctly, right model tier held, verification ran.
Include went_well=false findings for genuine gaps only -- not stylistic preferences.

At most 10 findings total. If none, output exactly: []
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

  # Gate out headless runs. entrypoint is in the transcript JSONL, not the payload.
  entrypoint=$(jq -rs 'map(.entrypoint // empty) | first // ""' "$transcript_path" 2>/dev/null || echo "")
  if [ "$entrypoint" != "cli" ]; then
    echo "$(date -u +%FT%TZ) headless transcript, skipping ($session_id, entrypoint=${entrypoint:-none})"
    return 0
  fi

  project=$(basename "${cwd:-unknown}")

  # Build rich projection: text turns + tool events, sequenced.
  # Text turns: [role] text (same format as sibling hooks).
  # Tool events: [tool] <name>: <input_summary>
  #   Skill -> skill arg; Agent -> description + subagent_type; Bash -> first 120 chars; others -> name only.
  rich=$(jq -rs '
    map(
      select(.type == "user" or .type == "assistant")
      | (.message.role // .type) as $role
      | (.message.content
          | if type == "array" then .
            elif type == "string" then [{type:"text", text:.}]
            else [] end) as $parts
      | $parts[]
      | if .type == "text" then
          ((.text // "") | gsub("^\\s+|\\s+$"; "")) as $t
          | if ($t | length) > 0 then "[\($role)] \($t)" else empty end
        elif .type == "tool_use" then
          (.name // "unknown") as $tool
          | (.input // {}) as $inp
          | if $tool == "Skill" then
              "[tool] Skill: \($inp.skill // "unknown")"
            elif $tool == "Agent" then
              "[tool] Agent: \($inp.description // "")  subagent_type=\($inp.subagent_type // "default")"
            elif $tool == "Bash" then
              "[tool] Bash: \(($inp.command // "") | .[0:120])"
            else
              "[tool] \($tool)"
            end
        else empty end
    )
    | join("\n\n")
  ' "$transcript_path" 2>/dev/null || echo "")

  if [ -z "$rich" ]; then
    echo "$(date -u +%FT%TZ) empty projection ($session_id)"
    return 0
  fi

  # Head + tail cap: critic needs both ends of the session.
  bytes=$(printf '%s' "$rich" | wc -c | tr -d ' ')
  if [ "$bytes" -gt 120000 ]; then
    rich="$(printf '%s' "$rich" | head -c 40000)

[... $((bytes - 120000)) chars elided from the middle ...]

$(printf '%s' "$rich" | tail -c 80000)"
  fi

  export CLAUDE_CRITIC_RUNNING=1
  raw=$(printf '%s' "$rich" | "$CLAUDE_BIN" -p --model "$MODEL" "$PROMPT" 2>>"$LOG" || echo "")

  if [ -z "$raw" ]; then
    echo "$(date -u +%FT%TZ) critic returned nothing ($session_id)"
    return 0
  fi

  json=$(printf '%s' "$raw" | sed '/^[[:space:]]*```/d')

  # Salvage outermost bracket span if the model wrapped the array in prose.
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
    dump="$HOME/.claude/hooks/session-critic-failed-$(date -u +%Y%m%dT%H%M%SZ).txt"
    printf '%s' "$raw" >"$dump" 2>/dev/null || true
    echo "$(date -u +%FT%TZ) non-JSON output ($session_id), raw saved to $dump"
    return 0
  fi

  rows=$(printf '%s' "$json" | jq -c \
    --arg session_id "$session_id" \
    --arg project "$project" \
    --arg cwd "$cwd" '
    [ .[] | select((((.finding // "") | tostring) | gsub("^\\s+|\\s+$";"")) != "") ]
    | to_entries
    | map(
        .key as $i | .value as $f
        | {
            session_id: $session_id,
            seq: ($i + 1),
            project: $project,
            cwd: $cwd,
            finding: ($f.finding | tostring),
            went_well: (($f.went_well // false) | if . == true or . == "true" then true else false end),
            category: (if (($f.category // "") | tostring) == "" then null else ($f.category | tostring) end),
            severity: (if (($f.severity // "") | tostring) == "" then null else ($f.severity | tostring) end),
            target_kind: (if (($f.target_kind // null) | . == null or tostring == "") then null else ($f.target_kind | tostring) end),
            target_ref: (if (($f.target_ref // null) | . == null or tostring == "") then null else ($f.target_ref | tostring) end),
            evidence: (if (($f.evidence // null) | . == null or tostring == "") then null else ($f.evidence | tostring) end)
          }
      )')

  n=$(printf '%s' "$rows" | jq 'length')
  if [ "$n" -eq 0 ]; then
    echo "$(date -u +%FT%TZ) no findings ($session_id, $project)"
    return 0
  fi

  if [ -n "$DRY_RUN" ]; then
    printf '%s\n' "$rows" | jq .
    return 0
  fi

  if ! printf '%s' "$rows" | curl -sS -X POST \
      "$SUPABASE_URL/rest/v1/session_findings?on_conflict=session_id,seq" \
      -H "apikey: $SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates" \
      --data-binary @- >>"$LOG" 2>&1; then
    echo "$(date -u +%FT%TZ) post failed ($session_id)"
    return 0
  fi

  # Prune stale tail from a longer earlier extraction.
  if ! curl -sS -X DELETE \
      "$SUPABASE_URL/rest/v1/session_findings?session_id=eq.$session_id&seq=gt.$n" \
      -H "apikey: $SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" >>"$LOG" 2>&1; then
    echo "$(date -u +%FT%TZ) wrote $n findings for $session_id ($project), tail prune failed"
    return 0
  fi

  echo "$(date -u +%FT%TZ) wrote $n findings for $session_id ($project)"
}

if [ -n "$DRY_RUN" ]; then
  extract
else
  { extract; } >>"$LOG" 2>&1 &
fi

exit 0

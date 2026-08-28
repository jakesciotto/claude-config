#!/usr/bin/env bash
# SessionStart hook: one DRIFT line per problem, silence when clean.
# Covers the two config repos and the ~/.claude install on this box.
# stdout lands in session context, so keep it short.

# Skip inside hook-spawned headless sessions.
if [ -n "${CLAUDE_CRITIC_RUNNING:-}" ] || [ -n "${CLAUDE_SUMMARY_RUNNING:-}" ] || [ -n "${CLAUDE_DECISIONS_RUNNING:-}" ]; then
  exit 0
fi

warn() { echo "DRIFT: $*"; }

check_repo() {
    local repo="$1" name counts ahead behind tmo=""
    name=$(basename "$repo")
    [ -d "$repo/.git" ] || { warn "$name missing at $repo"; return; }
    [ -n "$(git -C "$repo" status --porcelain)" ] && warn "$name has uncommitted changes"
    # Fetch at most once a day, never let a dead network stall session start.
    if [ ! -f "$repo/.git/FETCH_HEAD" ] || [ -n "$(find "$repo/.git/FETCH_HEAD" -mmin +1440 2>/dev/null)" ]; then
        command -v timeout  >/dev/null && tmo="timeout 5"
        command -v gtimeout >/dev/null && tmo="gtimeout 5"
        GIT_TERMINAL_PROMPT=0 $tmo git -C "$repo" fetch -q origin 2>/dev/null || true
    fi
    counts=$(git -C "$repo" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null) || return 0
    read -r behind ahead <<< "$counts"
    [ "${behind:-0}" != "0" ] && warn "$name is $behind commit(s) behind origin - pull and rerun its installer"
    [ "${ahead:-0}" != "0" ] && warn "$name is $ahead commit(s) ahead of origin - push"
}

# Claude Code persists runtime state (the model picker, the effort picker) into
# ~/.claude/settings.json, which IS global/settings.json in this repo. So every model
# or effort switch dirties a tracked public repo. Move those keys down to the
# machine-local overlay, which wins over settings.json, and restore the tracked file.
# The effective config does not change; only the git status does.
VOLATILE_KEYS='["model","modelSettings","effortLevel"]'

heal_settings_drift() {
    local repo="$HOME/github/claude-config" tracked="global/settings.json"
    local overlay="$HOME/.claude/settings.local.json"
    local head_json work_json overlay_json changed outside merged

    command -v jq >/dev/null 2>&1 || return 0
    [ -f "$overlay" ] || return 0
    git -C "$repo" diff --quiet -- "$tracked" 2>/dev/null && return 0

    head_json=$(git -C "$repo" show "HEAD:$tracked" 2>/dev/null) || return 0
    work_json=$(cat "$repo/$tracked" 2>/dev/null) || return 0
    overlay_json=$(cat "$overlay" 2>/dev/null) || return 0
    # Refuse on malformed JSON anywhere. A broken overlay must not be overwritten.
    for j in "$head_json" "$work_json" "$overlay_json"; do
        jq -e . >/dev/null 2>&1 <<<"$j" || return 0
    done

    changed=$(jq -nc --argjson h "$head_json" --argjson w "$work_json" \
        '[($h|keys) + ($w|keys) | unique | .[] | select($h[.] != $w[.])]' 2>/dev/null) || return 0
    [ "$(jq -r 'length' <<<"$changed")" -gt 0 ] || return 0

    # Any key outside the volatile set means a real edit. Leave it for the DRIFT line.
    outside=$(jq -r --argjson v "$VOLATILE_KEYS" \
        '[.[] | select(. as $k | $v | index($k) | not)] | join(", ")' <<<"$changed")
    [ -z "$outside" ] || return 0

    merged=$(jq -n --argjson w "$work_json" --argjson l "$overlay_json" --argjson c "$changed" \
        '$l + (reduce $c[] as $k ({}; if ($w|has($k)) then .[$k] = $w[$k] else . end))') || return 0

    ( umask 077; printf '%s\n' "$merged" >"$overlay.tmp" ) || return 0
    mv -f "$overlay.tmp" "$overlay" || return 0
    git -C "$repo" checkout -- "$tracked" 2>/dev/null || return 0
    echo "HEALED: moved $(jq -r 'join(", ")' <<<"$changed") to settings.local.json (harness runtime state)"
}

heal_settings_drift

check_repo "$HOME/github/claude-config"
check_repo "$HOME/github/dotfiles"

[ -L "$HOME/.claude/settings.json" ] || warn "~/.claude/settings.json is not a symlink - rerun bootstrap.sh"
[ -L "$HOME/.zshrc" ] || warn "~/.zshrc is not a symlink - run dotfiles/install.sh"

f="$HOME/.claude/settings.local.json"
if [ ! -f "$f" ]; then
    warn "settings.local.json missing - telemetry drops to localhost silently; rerun bootstrap.sh"
else
    grep -q 'host\.name=' "$f" || warn "no host.name in settings.local.json - Grafana series unlabeled"
    grep -q 'OTEL_EXPORTER_OTLP_ENDPOINT' "$f" || warn "no OTLP endpoint in settings.local.json - metrics drop silently"
fi

exit 0

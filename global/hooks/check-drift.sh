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

#!/usr/bin/env bash
# Set up this machine's ~/.claude config from the claude-config repo.
# Idempotent: safe to re-run. Re-links symlinks, patches folder-trust state.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR/hooks"

# repo path -> install path (relative to $CLAUDE_DIR)
link() {
    local src="$REPO/$1" dest="$CLAUDE_DIR/$2"
    if [ ! -e "$src" ]; then
        echo "skip (missing source): $1" >&2
        return
    fi
    ln -sfn "$src" "$dest"
    echo "linked: $dest -> $src"
}

link "global/settings.json"                      "settings.json"
link "global/agents"                             "agents"
link "global/skills"                             "skills"
link "global/references"                         "references"
link "global/commands"                           "commands"
link "global/scripts"                            "scripts"
link "global/CLAUDE.md"                          "CLAUDE.md"
link "template/.claude/hooks/auto-trust-folder.sh" "hooks/auto-trust-folder.sh"
link "template/.claude/hooks/session-summary.sh"   "hooks/session-summary.sh"
link "template/.claude/hooks/session-decisions.sh" "hooks/session-decisions.sh"

# PostHog-internal skills live in the gitignored posthog/ folder (internal table
# names and customer-adjacent queries stay out of git - this repo is public), so
# they are linked per-skill rather than via the global/skills tree. On a fresh
# clone posthog/ does not exist and link() skips these cleanly.
mkdir -p "$CLAUDE_DIR/skills"
link "posthog/catchup"                             "skills/catchup"
link "posthog/ff-pitfall-scan"                     "skills/ff-pitfall-scan"

# Both SessionEnd hooks source this env file for Supabase creds. It is never in git,
# so on a fresh machine the hooks find nothing, log "no env file, skipping" and exit 0 -
# a silent no-op with no signal that anything is missing. Seed a stub and say so.
seed_hook_env() {
    local f="$CLAUDE_DIR/hooks/.session-summary.env"
    if [ -f "$f" ]; then
        echo "kept (live): $f"
        return
    fi
    cat >"$f" <<'EOF'
SUPABASE_URL=https://jselgaytmwlstuuhrwzj.supabase.co
SUPABASE_SERVICE_KEY=
EOF
    chmod 600 "$f"
    echo "ACTION REQUIRED: set SUPABASE_SERVICE_KEY in $f - session-summary and session-decisions no-op until then" >&2
}
seed_hook_env

# Memory rules are live machine state, not symlinks: the repo holds bootstrap
# templates in global/rules/, seeded once per machine and never clobbered.
seed_rules() {
    [ -L "$CLAUDE_DIR/rules" ] && rm "$CLAUDE_DIR/rules"   # migrate old symlink setup
    mkdir -p "$CLAUDE_DIR/rules"
    local f dest
    for f in "$REPO"/global/rules/*.md; do
        dest="$CLAUDE_DIR/rules/$(basename "$f")"
        if [ -e "$dest" ]; then
            echo "kept (live): $dest"
        else
            cp "$f" "$dest"
            echo "seeded: $dest"
        fi
    done
}
seed_rules

# Folder-trust lives in live machine state (~/.claude.json), NOT a symlink:
# the file holds the project list and account data and must stay local.
# Pre-accept the trust gate for $HOME so launches don't prompt.
trust_home() {
    local f="$HOME/.claude.json"
    command -v jq >/dev/null || { echo "jq not found; skipping trust patch" >&2; return; }
    [ -f "$f" ] || echo '{}' > "$f"
    jq --arg h "$HOME" '.projects[$h].hasTrustDialogAccepted = true' "$f" > "$f.tmp" \
        && mv -f "$f.tmp" "$f"
    echo "trusted folder: $HOME"
}
trust_home

echo "done. restart any running Claude Code session to load."

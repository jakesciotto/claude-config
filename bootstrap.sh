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
link "global/rules"                              "rules"
link "global/commands"                           "commands"
link "global/CLAUDE.md"                          "CLAUDE.md"
link "template/.claude/hooks/auto-trust-folder.sh" "hooks/auto-trust-folder.sh"

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

#!/usr/bin/env bash
# Set up this machine's ~/.claude config from the claude-config repo.
# Idempotent: safe to re-run. Re-links symlinks, patches folder-trust state.
#
#   ./bootstrap.sh          install / re-link
#   ./bootstrap.sh --diff   report drift between the repo's rule templates and live rules
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Rule templates that ship real content, so template-vs-live drift is a defect.
# The rest are blank skeletons and are expected to diverge as live memory grows.
CONTENT_RULES=(memory-profile.md memory-preferences.md)

# repo path -> install path (relative to $CLAUDE_DIR)
link() {
    local src="$REPO/$1" dest="$CLAUDE_DIR/$2"
    if [ ! -e "$src" ]; then
        echo "skip (missing source): $1" >&2
        return
    fi
    # ln -sfn only replaces a dest that is a file or a symlink. Against a real
    # directory it silently creates the link *inside* it, which is how
    # ~/.claude/skills/skills existed for months while global/skills never loaded.
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        echo "REFUSING: $dest is a real directory, not a symlink - would nest. Use link_children." >&2
        return 1
    fi
    ln -sfn "$src" "$dest"
    echo "linked: $dest -> $src"
}

# Symlink each child of a repo dir into a real dest dir. Use when the dest must
# stay a real directory because other tools drop entries there (skills, hooks).
# Pass --skills-only to link just the children that are actual skills, so a
# loose reference doc sitting in the source dir is not published as one.
link_children() {
    local srcdir="$REPO/$1" destdir="$CLAUDE_DIR/$2" mode="${3:-}" child name
    if [ ! -d "$srcdir" ]; then
        echo "skip (missing source dir): $1" >&2
        return
    fi
    # Migrate an old whole-dir symlink. With dest -> srcdir, the ln below
    # resolves through it and writes self-symlinks INSIDE the repo
    # (global/skills/capture/capture, seen on fedora 2026-08-06).
    if [ -L "$destdir" ]; then
        rm "$destdir"
        echo "migrated: $destdir symlink removed, will be a real dir"
    fi
    mkdir -p "$destdir"
    shopt -s nullglob
    for child in "$srcdir"/*; do
        name="$(basename "$child")"
        case "$name" in .*|.gitkeep) continue ;; esac
        if [ "$mode" = "--skills-only" ] && [ ! -f "$child/SKILL.md" ]; then
            echo "skip (not a skill): $1/$name"
            continue
        fi
        ln -sfn "$child" "$destdir/$name"
        echo "linked: $destdir/$name -> $child"
    done
    shopt -u nullglob
}

install_all() {

link "global/settings.json" "settings.json"
link "global/agents"        "agents"
link "global/references"    "references"
link "global/commands"      "commands"
link "global/scripts"       "scripts"
link "global/CLAUDE.md"     "CLAUDE.md"

# skills/ and hooks/ stay real directories: marketplace plugins and hook state
# files live alongside the repo's entries, so the tree cannot be one symlink.
link_children "global/skills" "skills" --skills-only
link_children "global/hooks"  "hooks"

# PostHog-internal skills (internal table names, customer-adjacent queries)
# are NOT in this public repo: they live as real dirs in ~/.claude/skills/ on
# the work laptop only, machine-local state like rules/. No remote, no backup
# beyond whatever covers ~/.claude - a fresh machine gets none of them.

}

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

# Seed-if-missing means a content-carrying template can rot for months while the
# live file moves on, and a fresh machine then gets the stale copy. Nothing
# surfaces that by itself, so make it an explicit check.
diff_rules() {
    local rc=0 f live name
    echo "content-carrying templates (drift here is a defect):"
    for name in "${CONTENT_RULES[@]}"; do
        f="$REPO/global/rules/$name"; live="$CLAUDE_DIR/rules/$name"
        if [ ! -f "$f" ] || [ ! -f "$live" ]; then
            echo "  MISSING  $name"; rc=1; continue
        fi
        if diff -q "$f" "$live" >/dev/null; then
            echo "  ok       $name"
        else
            echo "  DRIFTED  $name"
            diff -u "$f" "$live" | sed 's/^/           /'
            rc=1
        fi
    done
    echo
    echo "skeleton templates (divergence expected, sizes for reference):"
    for f in "$REPO"/global/rules/*.md; do
        name="$(basename "$f")"
        case " ${CONTENT_RULES[*]} " in *" $name "*) continue ;; esac
        live="$CLAUDE_DIR/rules/$name"
        printf "  %-24s template=%6s live=%6s\n" "$name" \
            "$(wc -c <"$f" | tr -d ' ')" "$(wc -c <"$live" 2>/dev/null | tr -d ' ' || echo NA)"
    done
    return $rc
}

# Telemetry endpoint and host name are machine-local (settings.local.json). A
# box missing them still exports - to localhost:4317, silently dropping every
# metric, and series without host.name legend as bare "Value" in Grafana.
# Seed a stub on fresh machines, validate existing ones.
seed_settings_local() {
    local f="$CLAUDE_DIR/settings.local.json"
    if [ -f "$f" ]; then
        grep -q '"OTEL_EXPORTER_OTLP_ENDPOINT"' "$f" \
            || echo "ACTION REQUIRED: no OTLP endpoint in $f - metrics fall back to localhost:4317 and drop silently" >&2
        grep -q 'host\.name=' "$f" \
            || echo "ACTION REQUIRED: no host.name in $f - series legend as bare Value in Grafana" >&2
        echo "kept (live): $f"
        return
    fi
    local box="${CLAUDE_BOX:-$(hostname -s)}"
    cat >"$f" <<EOF
{
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://vinelab:4317",
    "OTEL_RESOURCE_ATTRIBUTES": "host.name=$box"
  }
}
EOF
    echo "seeded: $f (host.name=$box from hostname - Macs get DHCP-renamed, verify it is the fleet name)"
}

# Folder-trust lives in live machine state (~/.claude.json), NOT a symlink:
# the file holds the project list and account data and must stay local.
# Pre-accept the trust gate for $HOME so launches don't prompt. Note: the docs
# say trust for a session started in the home directory is held for that session
# only and is not written to disk, so this may be inert for $HOME specifically.
trust_home() {
    local f="$HOME/.claude.json"
    command -v jq >/dev/null || { echo "jq not found; skipping trust patch" >&2; return; }
    [ -f "$f" ] || echo '{}' > "$f"
    jq --arg h "$HOME" '.projects[$h].hasTrustDialogAccepted = true' "$f" > "$f.tmp" \
        && mv -f "$f.tmp" "$f"
    echo "trusted folder: $HOME"
}

if [ "${1:-}" = "--diff" ]; then
    diff_rules
    exit $?
fi

install_all
seed_hook_env
seed_rules
seed_settings_local
trust_home

echo "done. restart any running Claude Code session to load."

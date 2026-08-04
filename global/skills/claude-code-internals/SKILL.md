---
name: claude-code-internals
description: Hard-won mechanics of Claude Code hooks and plugin installs - why an env-var re-entry guard between SessionEnd hooks is not sufficient, gating on the transcript entrypoint instead, loud-vs-silent failure lanes, how to verify a guard, and what a plugin install actually copies for directory vs git marketplaces. Load before writing or debugging a hook, wiring a SessionEnd handler, or reasoning about what a plugin install shipped.
when_to_use: Writing or debugging a Claude Code hook, adding a SessionEnd handler, seeing a hook ingest its own headless run, or auditing what a plugin install copied onto disk.
paths:
  - "**/hooks/*.sh"
  - "**/hooks/hooks.json"
  - "**/.claude/settings*.json"
  - "**/.claude-plugin/plugin.json"
---

# Claude Code hooks and plugin internals

Each of these cost a wrong first attempt.

## SessionEnd re-entry

**An env-var cross-guard between SessionEnd hooks only covers the hooks you own.** `claude -p` triggers SessionEnd, which fires *every* hook, so one hook's headless call spawns the others. Exporting `CLAUDE_X_RUNNING` before your own `claude -p` and bailing on any sibling's variable is necessary but not sufficient: a **third-party** hook that shells out to `claude -p` sets no such variable, and your hook then ingests *its* headless transcript as if it were a real session. Bit twice - the hogpilot plugin's `hp-session-capture.sh` distiller fed its own facts/metrics output into `session-decisions.sh` (loud: non-JSON dumps) and into `session-summary.sh` (silent: 163 junk rows, 21% of the table).

**Gate on the transcript, not on an env var.** Read `entrypoint` off the transcript JSONL: interactive is `cli`, headless is `sdk-cli`. It holds regardless of who spawned the run. It is *not* on line 1 - scan for the first non-null (`jq -rs 'map(.entrypoint // empty) | first // ""'`). Treat missing as headless: skipping costs one session, recursing pollutes the table.

Use an explicit `if`, not `test && exit 0` - a false test in an `&&` list does not abort under `set -e`.

## Failure lanes and verification

A hook that fails **loudly** (parse error, dump file) is far cheaper than the same bug in a lane that fails **silently**. Same root cause, but the strict-parse lane self-reported for days while the write-anything lane quietly corrupted a fifth of the table. When two hooks share an input, give both a strict gate.

Verify a guard like this with a **before/after diff of the log across a full run**, not by timestamps. An unrelated real session ending mid-test will look exactly like a leak.

## Plugin installs

**A plugin install is a frozen copy** at `~/.claude/plugins/cache/<mkt>/<plugin>/<version>/`, pinned to `plugin.json`'s version and moving only on `/plugin update`. For a `source: directory` marketplace, Claude Code puts the **live source dir's** `bin/` on PATH while `CLAUDE_PLUGIN_ROOT` points at the frozen cache copy - so a PATH-resolved binary can be current while `${CLAUDE_PLUGIN_ROOT}/bin/x` is months stale, in the same install. Third-party and local-path marketplaces have auto-update disabled by default, and a local-path marketplace can only re-read that directory - it never fetches new commits.

Removing a marketplace **uninstalls its plugins**. Keep durable state outside `CLAUDE_PLUGIN_DATA` so it survives.

**A `source: directory` marketplace copies the whole tree into the plugin cache, gitignored paths included** - `.claude/`, `.venv/`, and any `.env` left there. A **git**-source marketplace clones, so it carries only tracked files. Same plugin, different blast radius: the local dev install bundles your private working tree, remote installers get the clean clone. `.gitignore` is a packaging boundary only over git. Audit the cached version dir (`~/.claude/plugins/cache/<mkt>/<plugin>/<version>/`), never the repo, to see what actually shipped.

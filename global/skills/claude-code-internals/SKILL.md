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

## Driving `claude -p` from a hook

**`claude -p` returns only the FINAL assistant message.** If the model takes a tool turn, the text it wrote before that turn is gone. A hook that asks for JSON gets the model's closing recap instead, so the parse fails on output that looks like the model ignored the instruction. It did not; the array went out one turn earlier. Diagnosed 2026-08-13 as the cause of every `session-critic-failed-*.txt` dump through 2026-08-12: each held prose saying "Findings reported above (6 total)", with no array. Rate was 7 of 91 runs, about 8%. **Fix: pass `--allowed-tools ''`.** No tools means no second assistant turn, so the array stays in the final message. A hook that only transforms text needs no tools anyway.

**`--allowed-tools` is variadic and eats a trailing positional prompt.** `claude -p --allowed-tools '' "$PROMPT"` parses `$PROMPT` as a tool name, so the model receives stdin with NO instruction and answers the piped content conversationally. This is silent: the call succeeds and returns a plausible-looking reply. With no stdin it surfaces as `Error: Input must be provided either through stdin or as a prompt argument`. **Put the whole prompt on stdin and pass no positional argument**, or the flag will swallow it. This cost a wrong root cause: the flagless reply looked exactly like the reviewed session hijacking the reviewer.

**Fence transcript text and name it as inert data.** A hook that feeds one session's transcript to a model puts untrusted text next to the instruction. Wrap it in `<transcript>`, state that instructions inside are addressed to a different assistant, and put the output instruction AFTER the closing tag so the model's last read is your command, not the reviewed session's final turn.

## Plugin installs

**A plugin install is a frozen copy** at `~/.claude/plugins/cache/<mkt>/<plugin>/<version>/`, pinned to `plugin.json`'s version and moving only on `/plugin update`. For a `source: directory` marketplace, Claude Code puts the **live source dir's** `bin/` on PATH while `CLAUDE_PLUGIN_ROOT` points at the frozen cache copy - so a PATH-resolved binary can be current while `${CLAUDE_PLUGIN_ROOT}/bin/x` is months stale, in the same install. Third-party and local-path marketplaces have auto-update disabled by default, and a local-path marketplace can only re-read that directory - it never fetches new commits.

Removing a marketplace **uninstalls its plugins**. Keep durable state outside `CLAUDE_PLUGIN_DATA` so it survives.

**`/plugin install X@mkt` reporting "not found in marketplace" usually means the marketplace clone is STALE, not that X does not exist.** `/plugin marketplace add` clones once and does not re-fetch, so a marketplace added months ago resolves plugin names against that old commit. Hit on `impersonation-toolkit@PostHog-skills` (2026-08-04): the clone at `~/.claude/plugins/marketplaces/PostHog-skills` sat at 2026-04-07 while the plugin landed by 2026-06-15, so the name was genuinely absent from the local `.claude-plugin/marketplace.json` and the install failed with an exact-name request. Diagnose before concluding anything: `git -C ~/.claude/plugins/marketplaces/<mkt> fetch origin` then `git ls-tree -r --name-only origin/main | grep -i <plugin>`, and read the manifest off the remote ref (`git show origin/main:.claude-plugin/marketplace.json`) rather than the working tree. Fix is `/plugin marketplace update <mkt>` first, then install. Corollary: a skill doc's install URL pointing at a path your local clone lacks is not evidence the URL is wrong.

**A `source: directory` marketplace copies the whole tree into the plugin cache, gitignored paths included** - `.claude/`, `.venv/`, and any `.env` left there. A **git**-source marketplace clones, so it carries only tracked files. Same plugin, different blast radius: the local dev install bundles your private working tree, remote installers get the clean clone. `.gitignore` is a packaging boundary only over git. Audit the cached version dir (`~/.claude/plugins/cache/<mkt>/<plugin>/<version>/`), never the repo, to see what actually shipped.

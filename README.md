# README.md

Global Claude Code settings and a project template, for rolling out and maintaining the same setup across machines and workspaces.

`bootstrap.sh` installs into `~/.claude` (idempotent; safe to re-run). `./bootstrap.sh --diff` is read-only and reports drift between the repo's rule templates and the live files.

**This repo is public.** Anything referencing internal PostHog tables, customer names, or book data never goes in it: PostHog-internal skills live as real directories in `~/.claude/skills/` on the work laptop, machine-local state outside git entirely.

## How install works

Three mechanisms, deliberately different:

| Mechanism | Applies to | Why |
|---|---|---|
| Symlink the whole path | `settings.json`, `CLAUDE.md`, `agents/`, `commands/`, `scripts/`, `references/` | Nothing else writes there, so the repo can own the path outright. |
| Symlink each child | `skills/`, `hooks/` | These directories must stay real: marketplace plugins and hook state files (`.session-summary.env`, logs) live alongside the repo's entries. `ln -sfn` against a real directory silently nests inside it instead of replacing it, which is how `~/.claude/skills/skills` existed for months while `global/skills` never loaded. `link()` now refuses that case; `link_children()` handles it. |
| Seed once, never clobber | `rules/` | Memory rules are live machine state that evolves in place. The repo holds bootstrap templates only. |

Seed-if-missing means a template can rot while the live file moves on, and a fresh machine then gets the stale copy. `--diff` exists to surface that. `memory-profile.md` and `memory-preferences.md` carry real content and must not drift; the rest are blank skeletons and are expected to.

## Global settings

- `settings.json` - permissions, hooks, statusline, plugins, marketplaces, auto-memory layout.
- `CLAUDE.md` - role and the memory-update trigger table.
- `rules/` - templates seeded to `~/.claude/rules/`:
  - `memory-profile.md`, `memory-preferences.md` - carry content.
  - `memory-decisions.md` - pointer index to project decision logs. Full prose is archived in Supabase, never loaded.
  - `memory-sessions.md` - rolling summary of the last 3 substantive sessions.
  - `memory-technical.md` - only cross-project gotchas that must hold in **every** repo. Domain gotchas live in skills instead (see below).
- `skills/` - user skills, available in every project, body loads on demand:
  - `claude-code-internals` - hook re-entry, transcript `entrypoint` gating, plugin install copy semantics. `paths:`-scoped to hook and settings files.
  - `data-pipeline-gotchas` - PostgREST/Supabase upserts, LLM-output validation and salvage, test isolation.
  - `capture` - Todoist Inbox to Obsidian, one-way. `disable-model-invocation: true` (side effects; you trigger it). Its Supabase audit-log spec and DDL are supporting files under `references/`, not separate commands.
- `hooks/` - user-scope hooks, symlinked into `~/.claude/hooks/`:
  - `session-summary.sh`, `session-decisions.sh` - SessionEnd, fork to background, write to Supabase `configs`. Both gate on the transcript `entrypoint` so a headless `claude -p` run is never ingested as a real session. Both self-trim their log at 256KB.
- `scripts/` - `statusline-usage.py`.
- `references/` - reference material, loaded on demand. Directory tracked, contents never.
- `agents/` - `orchestrator` (model/effort router), `obsidian-vault` (read-only PARA operator).

`global/commands-archive/` holds deprecated commands, gitignored and outside the loaded tree. A file left inside `commands/` still registers as a namespaced command, so removal means moving it out, not renaming it.

## Where an instruction belongs

A rule without `paths:` frontmatter loads every session, exactly like CLAUDE.md, so it costs the same. Scope or relocate rather than accumulate.

| Kind of instruction | Home |
|---|---|
| Must hold in every session, every repo | `global/CLAUDE.md` or `rules/` without `paths:` |
| Applies only to certain files | a rule or skill with `paths:` globs |
| A procedure or reference needed only sometimes | a skill; description loads, body does not |
| Must happen every time, without judgment | a hook, not a written instruction |
| Learned while working, per repo | auto memory, which Claude maintains itself |

## Auto memory

Claude Code writes its own memory to `~/.claude/memory` (`autoMemoryDirectory` in `settings.json`). The default is per-repo, keyed on the git root, which fragments customer knowledge across directories. Since PostHog work happens from arbitrary cwds, this is set to one shared directory at user scope instead.

Code repos that should not pollute that pile carry an override in their own `.claude/settings.local.json` pointing at `~/.claude/memory-repos/<repo>/`: currently `hogpilot`, `posthog`, `claude-config`. Kept outside the repos so customer data cannot be committed by accident. `posthog.com` is excluded because upstream tracks a `.claude/settings.local.json` in `master`, so any local edit there is a working-tree diff against PostHog's public repo.

`MEMORY.md` is the index and is the only part loaded at session start, capped at 200 lines or 25KB. Everything past the cap is silently dropped, so keep it to one line per entry.

## Project template

Copied into a project's `.claude/` to seed structure. Tracked locally in a gitignored `projects/` folder so per-project changes can be diffed.

- `CLAUDE.md` - behavioral rules, the where-to-find-information map, auto-update triggers, and the instruction-placement table. Sole entry point. Claude Code reads `CLAUDE.md`, not `AGENTS.md`; a repo that needs both should `@AGENTS.md` import or symlink.
- `project/` - `architecture.md`, `decisions.md`, `memory.md`, `testing.md`, `todo.md`.
- `rules/` - `repository.md` (unscoped: secrets, branching, versioning), `code-style.md` (`paths:`-scoped to source files), `workflow.md`.
- `plans/` - specs (`<feature>.md`) and plans (`<feature>-plan.md`), plus `done.md` for finished todos.
- `agents/`, `skills/` - project-scoped extensions, empty by default.

A changelog and a capabilities file were dropped from the template: git log and release tags carry the first, and the second is derivable from the code and rots.

## Directory structure

```
├── bootstrap.sh
├── README.md
├── global
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── agents/          orchestrator, obsidian-vault
│   ├── hooks/           session-summary.sh, session-decisions.sh
│   ├── skills/          capture, claude-code-internals, data-pipeline-gotchas
│   ├── commands/        empty; custom commands are merged into skills
│   ├── scripts/         statusline-usage.py
│   ├── references/      tracked dir, untracked contents
│   └── rules/           seeded templates
└── template
    └── .claude
        ├── CLAUDE.md
        ├── agents/
        ├── skills/
        ├── plans/       done.md
        ├── project/     architecture, decisions, memory, testing, todo
        └── rules/       repository.md, code-style.md, workflow.md
```

## Known gaps

- The PostHog-internal skills (`catchup`, `cs-issue-response`, `ff-pitfall-scan`, `hogql-gotchas`, `posthog-onboarding`, `source-tracker-sync`, `user-deep-dive`, `workload-analysis`) are real dirs in `~/.claude/skills/` on the work laptop only - no remote, no marketplace copy (verified 2026-08-04), no recovery path beyond whatever backup covers `~/.claude`. Accepted risk.
- `~/.claude/settings.local.json` is deliberately per-machine: its `env` block points telemetry at the home LLM gateway over Tailscale (`100.70.246.68`, `host.name=m5pro`), which is correct to keep untracked and machine-local. The other ~36 entries are portable, though: MCP permission grants, `enabledPlugins`, and UI preferences. On a new machine those cost 36 re-approvals. Moving the portable half into the tracked `global/settings.json` would fix that, at the cost of publishing internal MCP and skill *names* in a public repo. `enabledPlugins.hogpilot` is already duplicated between the two files.

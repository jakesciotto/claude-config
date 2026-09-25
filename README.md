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

Seed-if-missing means a template can rot while the live file moves on, and a fresh machine then gets the stale copy. `--diff` exists to surface that. `memory-profile.md` and `memory-preferences.md` carry real content. The preferences template is the public subset of the live file, which also holds work-specific sections that never enter this repo. The rest are blank skeletons and are expected to diverge.

## Global settings

- `settings.json` - permissions, hooks, statusline, plugins, marketplaces, auto-memory layout.
- `CLAUDE.md` - role and the memory-update trigger table.
- `rules/` - templates seeded to `~/.claude/rules/`:
  - `memory-profile.md`, `memory-preferences.md` - carry content.
  - `memory-decisions.md` - pointer index to project decision logs. Full prose is archived in Supabase, never loaded.
  - `memory-sessions.md` - rolling summary of the last 3 substantive sessions.
  - `memory-technical.md` - a pointer index, one line per gotcha, with the mechanism in one of the skills below. Rewritten 2026-09-21 from a 42 KB narrative; the live file stays under 8 KB.
- `skills/` - user skills, available in every project, body loads on demand:
  - `claude-code-internals` - hook re-entry, transcript `entrypoint` gating, plugin install copy semantics, MCP scope, the two Claude homes, runtime keys Claude Code writes into settings.json, classifier denials, zsh traps. `paths:`-scoped to hook and settings files.
  - `git-github-recipes` - signed-commit rulesets, the `~/.config/git` layout, API paths that 404 or return a silent zero, canonical-repo checks, squash and release mechanics, the posthog venv.
  - `obsidian-vault-ops` - what an agent may write into the vault, the three writers, TCC and iCloud, the obsidian-git pull-failed loop, add/add conflict recovery.
  - `data-pipeline-gotchas` - PostgREST/Supabase upserts, LLM-output validation and salvage, test isolation.
  - `capture` - Todoist Inbox to Obsidian, one-way. `disable-model-invocation: true` (side effects; you trigger it). Its Supabase audit-log spec and DDL are supporting files under `references/`, not separate commands.
- `hooks/` - user-scope hooks, symlinked into `~/.claude/hooks/`:
  - `check-drift.sh` - SessionStart. One DRIFT line per problem, and it heals the runtime keys Claude Code writes into the tracked `settings.json`.
  - `ste100-style.sh` - UserPromptSubmit. Injects the ASD-STE100 writing rules on every prompt.
  - `session-summary.sh` - SessionEnd, forks to background, writes the summary, tokens and cost to Supabase `configs.claude_sessions`. Gates on the transcript `entrypoint` so a headless `claude -p` run is never ingested as a real session. Self-trims its log at 256KB.
  - `session-decisions.sh`, `session-critic.sh` - kept in the repo, unwired from SessionEnd on 2026-09-21. Their tables (`decisions`, `session_findings`) stay queryable. Re-add the settings entry to turn one back on.
- `scripts/` - `statusline-usage.py`.
- `references/` - reference material, loaded on demand. Directory tracked, contents never.
- `agents/` - `obsidian-vault` (read-only PARA operator). The `orchestrator` router was removed on 2026-09-21.

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
│   ├── agents/          obsidian-vault
│   ├── hooks/           check-drift.sh, ste100-style.sh, session-summary.sh (+ two unwired)
│   ├── skills/          capture, claude-code-internals, data-pipeline-gotchas,
│   │                    git-github-recipes, obsidian-vault-ops
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

- The PostHog-internal skills (`catchup`, `ff-pitfall-scan`, `hogql-gotchas`, `posthog-onboarding`, `source-tracker-sync`, `user-deep-dive`, `workload-analysis`) are real dirs in `~/.claude/skills/` on the work laptop only - no remote, no marketplace copy (verified 2026-08-04), no recovery path beyond whatever backup covers `~/.claude`. Accepted risk.
- `~/.claude/settings.local.json` is deliberately per-machine: its `env` block carries `host.name=<box>` for Grafana, which is correct to keep untracked and machine-local. The OTLP endpoint moved to `dotfiles/.zshenv` on 2026-09-24, because Claude Code 2.1.282 ignores it in project and local settings. The other ~36 entries are portable, though: MCP permission grants, `enabledPlugins`, and UI preferences. On a new machine those cost 36 re-approvals. Moving the portable half into the tracked `global/settings.json` would fix that, at the cost of publishing internal MCP and skill *names* in a public repo. `enabledPlugins.hogpilot` is already duplicated between the two files.

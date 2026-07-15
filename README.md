# README.md

Global settings and a project template for rolling out & maintaining Claude across multiple machines and workspaces.

`bootstrap.sh` symlinks the `global/` contents into `~/.claude` (idempotent; safe to re-run). Exception: `global/rules/` holds bootstrap templates that are copied (seeded) into `~/.claude/rules/` once per machine; live memory then evolves on the machine and is never clobbered by re-runs or tracked in git.

#### Global Settings

_Symlinked into `~/.claude` by `bootstrap.sh`, except `rules/` (seeded copy)._

- `settings.json` → permissions, model aliases, plugins, hooks, statusline.
- `CLAUDE.md` → top-level role and memory-update rules.
- `rules/` → memory file templates, seeded to `~/.claude/rules/` on first bootstrap:
  - `memory-profile.md` → user info relevant to discussions (template carries content).
  - `memory-preferences.md` → preferences, plus compute/model and subagent guardrails (template carries content).
  - `memory-decisions.md` → dated log of decisions (template is a blank skeleton).
  - `memory-sessions.md` → rolling summary of the last 10 substantive sessions (template is a blank skeleton).
- `commands/` → active slash commands (`capture`, `_shared/`).
- `scripts/` → e.g. `statusline-usage.py`.
- `references/` → reference material loaded on demand.
- `agents/` → global agents. _Empty; reserved for future agents._
- `skills/` → global skills.

Deprecated commands live in `global/commands-archive/` (gitignored, outside the loaded command tree, kept locally for reference).

#### Project Level Template

_Copied into a project's `.claude/` to seed structure. Tracked locally in a `.gitignored` `projects/` folder so per-project changes can be diffed._

- `CLAUDE.md` → project behavioral rules.
- `AGENTS.md` → directory map and where-to-find-information.
- `agents/`, `hooks/`, `skills/` → project-scoped extensions.
- `plans/`
  - `done.md` → finished tasks moved out of `project/todo.md` once it grows large.
- `project/` → main project-specific docs:
  - `architecture.md`, `capabilities.md`, `changelog.md`, `memory.md`, `testing.md`, `todo.md`
- `rules/` → project rules that override global settings:
  - `repository.md`, `workflow.md`

#### Directory Structure

```
├── bootstrap.sh
├── README.md
├── global
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── agents/
│   ├── skills/
│   ├── commands
│   │   ├── capture.md
│   │   └── _shared/
│   ├── scripts
│   │   └── statusline-usage.py
│   └── rules
│       ├── memory-profile.md
│       ├── memory-preferences.md
│       ├── memory-decisions.md
│       └── memory-sessions.md
└── template
    ├── AGENTS.md
    └── .claude
        ├── CLAUDE.md
        ├── agents/
        ├── hooks/
        ├── skills/
        ├── plans
        │   └── done.md
        ├── project
        │   ├── architecture.md
        │   ├── capabilities.md
        │   ├── changelog.md
        │   ├── memory.md
        │   ├── testing.md
        │   └── todo.md
        └── rules
            ├── repository.md
            └── workflow.md
```

# README.md

Global settings and a project template for rolling out & maintaining Claude across multiple machines and workspaces.

`bootstrap.sh` symlinks the `global/` contents into `~/.claude` (idempotent; safe to re-run).

#### Global Settings

_Symlinked into `~/.claude` by `bootstrap.sh`._

- `settings.json` → permissions, model aliases, plugins, hooks, statusline.
- `CLAUDE.md` → top-level role and memory-update rules.
- `rules/` → memory files (loaded every session):
  - `memory-profile.md` → user info relevant to discussions.
  - `memory-preferences.md` → preferences, plus compute/model and subagent guardrails.
  - `memory-decisions.md` → dated log of decisions.
  - `memory-sessions.md` → rolling summary of the last 10 substantive sessions.
- `commands/` → active slash commands (`capture`, `_shared/`).
- `scripts/` → e.g. `statusline-usage.py`.
- `agents/` → global agents. _Empty; reserved for future agents._
- `skills/` → global skills. _Empty; reserved for future skills._

Deprecated commands live in `global/commands-archive/` (gitignored, outside the loaded command tree, kept locally for reference).

#### Project Level Template

_Copied into a project's `.claude/` to seed structure. Tracked locally in a `.gitignored` `projects/` folder so per-project changes can be diffed._

- `CLAUDE.md` → project behavioral rules.
- `AGENTS.md` → directory map and where-to-find-information.
- `agents/`, `hooks/`, `skills/` → project-scoped extensions.
- `plans/`
  - `DONE.md` → finished tasks moved out of `project/TODO.md` once it grows large.
- `project/` → main project-specific docs:
  - `ARCHITECTURE.md`, `CAPABILITIES.md`, `CHANGELOG.md`, `MEMORY.md`, `TESTING.md`, `TODO.md`
- `rules/` → project rules that override global settings:
  - `REPOSITORY.md`, `WORKFLOW.md`

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
        │   └── DONE.md
        ├── project
        │   ├── ARCHITECTURE.md
        │   ├── CAPABILITIES.md
        │   ├── CHANGELOG.md
        │   ├── MEMORY.md
        │   ├── TESTING.md
        │   └── TODO.md
        └── rules
            ├── REPOSITORY.md
            └── WORKFLOW.md
```

# CLAUDE.md

Behavioral rules for this project, and the entry point to `.claude/`. Workflow detail in `rules/workflow.md`; code and repo rules in `rules/repository.md`.

## Efficiency

**CRITICAL** Before scanning the whole project for context, read `.claude/` and the files there first. Do not burn tens of thousands of tokens scanning every file. Prioritize precision.

Start with `project/architecture.md` (current state), `project/decisions.md` (what is already settled), and `project/memory.md` (gotchas that will otherwise cost a wrong first attempt).

## Where to find information

| File                    | Description                                            |
|-------------------------|--------------------------------------------------------|
| project/architecture.md | Project architecture and current state                 |
| project/decisions.md    | Locked design decisions and why - do not re-litigate   |
| project/memory.md       | Project-specific lessons, corrections, and gotchas     |
| project/capabilities.md | Project capabilities                                   |
| project/changelog.md    | Changelog                                              |
| project/testing.md      | Testing strategy                                       |
| project/todo.md         | To-dos captured at the project level                   |
| plans/                  | Specs (`<feature>.md`) and plans (`<feature>-plan.md`) |
| rules/repository.md     | Code style and repository-level decisions              |
| rules/workflow.md       | Explicit workflow definition and process               |

## Auto-updates (MANDATORY)

Updates should be minimal and concise; if unsure whether a trigger warrants the update, ask.

| Trigger                                                | File                    |
|--------------------------------------------------------|-------------------------|
| Commit that changes project architecture               | project/architecture.md |
| A design decision is made, or one is reversed          | project/decisions.md    |
| User pushes a commit                                   | project/changelog.md    |
| Any corrections, mistakes, or errors                   | project/memory.md       |
| Updates to testing strategy                            | project/testing.md      |
| User pushes a commit (capture any new features)        | project/capabilities.md |
| After a commit, update the captured tasks              | project/todo.md         |
| Code style change, or a new tool replacing another     | rules/repository.md     |

Project-specific decisions and gotchas go in `project/`, **not** in the global `~/.claude/rules/` files, which are loaded into every session in every project.

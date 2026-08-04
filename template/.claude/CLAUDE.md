# CLAUDE.md

Behavioral rules for this project, and the entry point to `.claude/`. Workflow detail in `rules/workflow.md`; repo and code rules in `rules/repository.md` and `rules/code-style.md`.

## Efficiency

**CRITICAL** Before scanning the whole project for context, read `.claude/` and the files there first. Do not burn tens of thousands of tokens scanning every file. Prioritize precision.

Start with `project/architecture.md` (current state), `project/decisions.md` (what is already settled), and `project/memory.md` (gotchas that will otherwise cost a wrong first attempt).

## Where to find information

| File                    | Description                                            |
|-------------------------|--------------------------------------------------------|
| project/architecture.md | Project architecture and current state                 |
| project/decisions.md    | Locked design decisions and why - do not re-litigate   |
| project/memory.md       | Project-specific lessons, corrections, and gotchas     |
| project/testing.md      | Testing strategy                                       |
| project/todo.md         | To-dos captured at the project level                   |
| plans/                  | Specs (`<feature>.md`) and plans (`<feature>-plan.md`) |
| rules/repository.md     | Repository-level decisions and secret handling         |
| rules/code-style.md     | Code style, path-scoped to source files                |
| rules/workflow.md       | Explicit workflow definition and process               |

## Auto-updates (MANDATORY)

Updates should be minimal and concise; if unsure whether a trigger warrants the update, ask.

| Trigger                                             | File                    |
|-----------------------------------------------------|-------------------------|
| Commit that changes project architecture            | project/architecture.md |
| A design decision is made, or one is reversed       | project/decisions.md    |
| Any corrections, mistakes, or errors                | project/memory.md       |
| Updates to testing strategy                         | project/testing.md      |
| After a commit, update the captured tasks           | project/todo.md         |
| Code style change, or a new tool replacing another  | rules/code-style.md     |

Deliberately not tracked: a changelog and a capabilities list. Git log and release tags already carry the first; the second is derivable from the code and rots.

## Where an instruction belongs

A file in `.claude/rules/` without `paths:` frontmatter loads in every session, exactly like CLAUDE.md. Scope or relocate rather than accumulate.

| Kind of instruction                            | Home                                              |
|------------------------------------------------|---------------------------------------------------|
| Applies to every session in this project       | `CLAUDE.md`, kept under 200 lines                 |
| Applies only to certain files                  | a rule in `rules/` with `paths:` globs            |
| A procedure or reference needed only sometimes | a skill in `skills/`, body loads on demand        |
| Must happen every time, without judgment       | a hook, not a written instruction                 |

Project-specific decisions and gotchas go in `project/`, **not** in the global `~/.claude/rules/` files, which are loaded into every session in every project.

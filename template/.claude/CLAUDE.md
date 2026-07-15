# CLAUDE.md

Behavioral rules for this project. The directory map is in `AGENTS.md`; workflow detail in `rules/workflow.md`; code/repo rules in `rules/repository.md`.

## Efficiency

**CRITICAL** Before scanning the whole project for context, read `.claude/` and the files there first. Do not burn tens of thousands of tokens scanning every file. Prioritize precision.

## Auto-updates (MANDATORY)

Updates should be minimal and concise; if unsure whether a trigger warrants the update, ask.

| Trigger                                                | File                    |
|--------------------------------------------------------|-------------------------|
| Commit that changes project architecture               | project/architecture.md |
| User pushes a commit                                   | project/changelog.md    |
| Any corrections, mistakes, or errors                   | project/memory.md       |
| Updates to testing strategy                            | project/testing.md      |
| User pushes a commit (capture any new features)        | project/capabilities.md |
| After a commit, update the captured tasks              | project/todo.md         |
| Code style change, or a new tool replacing another     | rules/repository.md     |

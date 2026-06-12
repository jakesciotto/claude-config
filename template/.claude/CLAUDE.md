# CLAUDE.md

Behavioral rules for this project. The directory map is in `AGENTS.md`; workflow detail in `rules/WORKFLOW.md`; code/repo rules in `rules/REPOSITORY.md`.

## Efficiency

**CRITICAL** Before scanning the whole project for context, read `.claude/` and the files there first. Do not burn tens of thousands of tokens scanning every file. Prioritize precision.

## Auto-updates (MANDATORY)

Updates should be minimal and concise; if unsure whether a trigger warrants the update, ask.

| Trigger                                                | File                    |
|--------------------------------------------------------|-------------------------|
| Commit that changes project architecture               | project/ARCHITECTURE.md |
| User pushes a commit                                   | project/CHANGELOG.md    |
| Any corrections, mistakes, or errors                   | project/MEMORY.md       |
| Updates to testing strategy                            | project/TESTING.md      |
| User pushes a commit (capture any new features)        | project/CAPABILITIES.md |
| After a commit, update the captured tasks              | project/TODO.md         |
| Code style change, or a new tool replacing another     | rules/REPOSITORY.md     |

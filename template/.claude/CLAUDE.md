# AGENTS.md

This document provides high-level context for AI agents working in this particular repository.

## Directory Structure

```
.claude
├── agents
│   └── software-architect.md
├── CLAUDE.md
├── hooks
├── plans
├── project
│   ├── ARCHITECTURE.md
│   ├── CAPABILITIES.md
│   ├── CHANGELOG.md
│   ├── MEMORY.md
│   ├── TESTING.md
│   └── TODO.md
├── rules
│   ├── REPOSITORY.md
│   └── WORKFLOW.md
└── skills
```

## Where to find information

| File                    | Description                               |
|-------------------------|-------------------------------------------|
| project/ARCHITECTURE.md | Project architecture                      |
| project/CHANGELOG.md    | Changelog                                 |
| project/MEMORY.md       | Project-specific lessons and learnings    |
| project/TESTING.md      | Captures testing strategy                 |
| project/CAPABILITIES.md | Describes project capabilities            |
| project/TODO.md         | To-dos captured at the project level      |
| rules/REPOSITORY.md     | Code style and repository-level decisions |
| rules/WORKFLOW.md       | Explicit workflow definition and process  |


## Auto-updates (MANDATORY)

Updates should be minimal and concise; if you're unsure if the trigger warrants the update, ask. 

| Trigger                                                                          | File                    |
|----------------------------------------------------------------------------------|-------------------------|
| User pushes a commit that involves a change to the architecture of the project   | project/ARCHITECTURE.md |
| User pushes a commit                                                             | project/CHANGELOG.md    |
| Any corrections, mistakes, user corrections, or errors                           | project/MEMORY.md       |
| Updates to testing strategy                                                      | project/TESTING.md      |
| User pushes a commit, update this file to capture any new features               | project/CAPABILITIES.md |
| After user pushes a commit, update the tasks that were captured on the todo list | project/TODO.md         |
| User issues a code style change, a new tool to be used in place of another       | rules/REPOSITORY.md     |
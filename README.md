# README.md

Global settings and template for rolling out & maintaining Claude across multiple machines and workspaces.

####  Global Settings

_All symlinked to top-level `.claude` directory._

`CLAUDE.md` &rarr; top-level workflow settings.

`agents/`&rarr; general agents for use.

  - `code-simplification-specialist.md`

`rules/` &rarr; symlinked to top-level `.claude`.

  - `MEMORY-DECISIONS.md` &rarr; dated log of decisions made during sessions.
  - `MEMORY-PREFERENCES.md` &rarr; user preferences (code style, comments).
  - `MEMORY-PROFILES.md` &rarr; user information relevant to discussions.
  - `MEMORY-SESSIONS.md` &rarr; rolling summary of last 10 substantive sessions.

#### Project Level Template

- To-do: shell script to copy to projects.

_A .gitignored folder has each of my project-level Claude settings in it so that modifications can be tracked or changed across projects._

`CLAUDE.md` &rarr; project-level workflow settings.

`agents/`

`hooks/`

  - To-do: fix hook that updates semnatic versioning of recent commits.
  - To-do: create hook that guarantees `project` folder gets updated every time a commit is made.

`plans/` 

  - `DONE.md` &rarr; after a certain number of lines are contained in the `project/TODO.md`file, we will put the finished tasks here. 
  - _Future_ - there is sometimes need for an `archive` folder contained within.

`project` &rarr; main project-specific folder (where the real shit happens).

  - `ARCHITECTURE.md`
  - `CAPABILITIES.md`
  - `CHANGELOG.md`
  - `MEMORY.md`
  - `TESTING.md`
  - `TODO.md`

`rules/` &rarr; project-level rules that contain workflow specifics or repo settings that override global settings.

  - `REPOSITORY.md`
  - `WORKFLOW.md`


#### Directory Structure

```
├── global
│   ├── CLAUDE.md 
│   ├── rules
│   │   ├── MEMORY-DECISIONS.md
│   │   ├── MEMORY-PREFERENCES.md
│   │   ├── MEMORY-PROFILE.md
│   │   └── MEMORY-SESSIONS.md
│   └── settings.json
├── README.md
└── template
    ├── .claude
    │   ├── agents
    │   ├── CLAUDE.md
    │   ├── hooks
    │   ├── plans
    │   │   └── DONE.md
    │   ├── project
    │   │   ├── ARCHITECTURE.md
    │   │   ├── CAPABILITIES.md
    │   │   ├── CHANGELOG.md
    │   │   ├── MEMORY.md
    │   │   ├── TESTING.md
    │   │   └── TODO.md
    │   └── rules
    │       ├── REPOSITORY.md
    │       └── WORKFLOW.md
    └── AGENTS.md
```
---
description: Weekly snapshot from the vault — project status, stale items, archive candidates, wins, someday re-triage.
argument-hint: "[YYYY-MM-DD week end]"
---

You are running Jake's weekly review for the week ending `$1` (default: today). **Offline-first — reads the vault + the Supabase archive. Todoist is not involved.**

## Context
- Vault: `/Users/jakesciotto/Documents/Obsidian Vault` (`mcp__obsidian__*`)
- Conventions: `Resources/conventions/{para-structure,project-readme-fields,task-system}.md`
- Supabase: project `configs` / `jselgaytmwlstuuhrwzj`, table `archived_tasks` (`_shared/supabase-logging.md`)

## Gather (parallel)

1. **Project READMEs** — list `Projects/`, read each. Frontmatter: `name`, `status`, `priority`, `next_action`, `blocked_by`, `target_date`, `last_touched`.
2. **Area sub-files** — `Areas/Home/*.md`, `Areas/Personal/*.md`, `Areas/Work/*.md` (excl. `Customers/`). Capture stale `last_touched`.
3. **Completed this week** — query Supabase `archived_tasks WHERE completed_date >= <week start>` (the durable record after `/archive` prunes them from pages), PLUS any current `- [x]` lines still in `Areas/**`/`Projects/**` not yet archived. Group by project.
4. **Someday pile** — scan `Areas/**`/`Projects/**` for open tasks with `[tier:: someday]` (excl. the reference files). This is the weekly re-triage list.

## Analyze
- **Status snapshot** — count Projects by `status` (active/paused/blocked/done), grouped by stream.
- **Stale Projects** — `last_touched` > 14 days → propose archive or revive.
- **Done Projects** — `status: done` → propose move to `Archives/`.
- **Wins** — top completed tasks this week (from gather #3).
- **Friction** — open tasks whose `[deadline::]` or `[due::]` is now in the past (overdue) and still not done → flag to unblock/redefine/drop.
- **Velocity** — count completed this week vs prior week (from `archived_tasks`, if prior data exists).

## Output — Part 1: write the review note

Write `Daily Notes/<YYYY-MM>/<date>-weekly-review.md`:

```markdown
---
date: <date>
type: weekly-review
generated_by: agent
tags:
  - type/weekly
---

# Weekly Review — week ending <date>
> [!info] Generated <timestamp>

## Status snapshot
| Stream | Active | Paused | Blocked | Done |
|---|---|---|---|---|
| Projects | N | N | N | N |

**Active:** <names>  ·  **Blocked:** <names + blocker>  ·  **Done (archive candidates):** <names>

## Stale (> 14 days)
- <project> — last touched <date>

## Wins this week
- [x] [<project>] <task>

## Friction (overdue + open)
- <task> — <due/deadline> passed. Suggest: <unblock/redefine/drop>

## Someday — re-triage
> Edit `[tier:: someday]` → an active tier (or add `[due::]`) in the task's page to graduate it.
```dataview
TASK
FROM ("Areas" OR "Projects") AND -"Areas/Work/Documentation" AND -"Areas/Work/Scratch" AND -"Projects/GTM Toolkit/csm-hud"
WHERE !completed AND tier = "someday"
GROUP BY file.folder
```

## Velocity
- Completed this week: <N> (vs prior <N>)

## Notes
<empty for reflection>
```

(The Someday block is a live Dataview query — it stays current; no hardcoded list.)

## Output — Part 2: confirm archive moves

Stop. For any Project with `status: done`: ask `Move these to Archives/? (y/N)`. On `y`: `mcp__obsidian__move_note` each `Projects/<name>/README.md` → `Archives/projects/<YYYY-MM-DD>-<name>/README.md` (+ sub-files). On `N`: skip.

## Log to Supabase
`command_runs`, `command='weekly-review'`, `scope=<week start>` (`_shared/supabase-logging.md`): `proposed` with counts (stale, archive candidates, someday count), then `applied`/`vetoed`. Non-blocking.

## Behavior
- Reads vault (offline) + Supabase. **No Todoist.**
- Confirm before any archive move.
- If Supabase is unreachable: fall back to current vault `[x]` lines for Wins/Velocity and note the data is partial.

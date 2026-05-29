---
description: Weekly snapshot — project status, stale items, archive candidates, wins/friction
argument-hint: "[YYYY-MM-DD week end]"
---

You are running Jake's weekly review for the week ending $1 (default: today).

## Context

PARA reference:
- `Resources/conventions/{para-structure,project-readme-fields,todoist-mapping}.md`

## Gather (parallel)

1. **All Project READMEs** — list `Projects/`, read each. Capture frontmatter (name, status, priority, next_action, blocked_by, target_date, last_touched).

2. **All Area sub-files** — read `Areas/Home/*.md`, `Areas/Personal/*.md`, `Areas/Work/*.md` (excluding `Customers/`). Capture: stale `last_touched`.

3. **Last 7 Daily Notes** — for each of past 7 days, read `Daily Notes/<YYYY-MM>/<date>.md` if exists (compute each day's month folder; window may span two folders near a month boundary). Parse `End-of-day reconcile` sections + checked items.

4. **Todoist completed this week** — `mcp__todoist__find-completed-tasks` since 7 days ago. Group by projectId.

5. **Todoist productivity stats** — `mcp__todoist__get-productivity-stats` for the week.

## Analyze

- **Status snapshot** — count Projects by `status`: active / paused / blocked / done. Group by stream.
- **Stale Projects** — `last_touched` > 14 days ago → propose archive or revive.
- **Done Projects** — `status: done` → propose move to `Archives/`.
- **Wins** — top 5 completed tasks of the week. Rank by priority (`p1` first), then by project size of completions.
- **Friction** — items appearing in 3+ consecutive Daily Notes as unchecked → flag for unblocking, redefining, or dropping.
- **Velocity** — total tasks completed this week vs prior week (if prior data available).

## Output — Part 1: Write weekly review note

Write to `Daily Notes/<YYYY-MM>/<date>-weekly-review.md` (month folder of `<date>`):

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
| Areas (Home/Personal/Work) | N | — | — | — |

**Active projects:** <names>
**Blocked projects:** <names with blocker>
**Done projects (archive candidates):** <names>

## Stale (> 14 days no touch)
- [?] <project> — last touched <date>

## Wins this week
- [x] [<project>] <task>
- [x] ...

## Friction
- [!] <task> — appeared in N daily notes uncompleted. Suggest: <unblock/redefine/drop>

## Velocity
- Tasks completed this week: <N>
- vs. prior week: <delta>

## Notes
<empty for user reflection>
```

## Output — Part 2: Confirm archive moves

Stop. For any Project with `status: done`, show in conversation:

> "Move these to Archives/? (y/N)"
> - Projects/<name>/

If `y`: for each, use `mcp__obsidian__move_note` to relocate `Projects/<name>/README.md` → `Archives/projects/<YYYY-MM-DD>-<name>/README.md`. Also move any sub-files in the project folder.

If `N`: skip moves, exit cleanly.

## Log run to Supabase

Per `_shared/supabase-logging.md`, `command='weekly-review'`, `scope=<week start date>`:
- After writing the review note + showing proposed archive moves (Part 2): insert `status='proposed'` row with `proposed_counts` (stale items, archive candidates) + `proposed_ops`. Keep `id`.
- On `y`: update → `status='applied'`, `applied_at=now()`, fill `applied_*` with moved projects.
- On `N`: update → `status='vetoed'` (review note still written; record that in `notes`).

Non-blocking.

## Behavior

- Read-only on Todoist.
- Confirm before any Archive move.
- If <7 Daily Notes available: fall back to README-only snapshot, note "Daily Notes data incomplete" at top.
- If Todoist offline: skip Velocity section, warn in callout.

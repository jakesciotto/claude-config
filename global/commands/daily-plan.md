---
description: Draft today's Daily Note from Todoist (due-today + overdue + undated backlog). READ-ONLY on Todoist; never overwrites an existing note.
argument-hint: "[YYYY-MM-DD]"
---

You are drafting Jake's Daily Note for $1 (default: today).

**Obsidian is the brain. This command is READ-ONLY on Todoist and NEVER overwrites a note that already exists.** A day's note, once created, holds Jake's edits — those flow to Todoist via `/sync`, never the reverse. The clobber bug (regenerating a note from Todoist over Jake's edits) is structurally impossible here: existing notes are append-only.

## Context

- Vault: `/Users/jakesciotto/Documents/Obsidian Vault`, via `mcp__obsidian__*`
- Todoist: `mcp__todoist__*`
- Calendar: `mcp__claude_ai_Google_Calendar__*`
- **Structure: `Templates/daily-note.md`** — read at runtime; the template owns section set + order. Strip `> [!info]` callouts on output, keep the `> [!tip]` legend.
- Mapping + line format: `Resources/conventions/todoist-mapping.md`

## Resolve target + branch on existence

Target: `Daily Notes/<YYYY-MM>/<date>.md` (`<YYYY-MM>` = first 7 chars of `<date>`; create the folder if absent).

Check whether the note already exists (`mcp__obsidian__read_note`; treat "file not found" as missing).

- **Missing** → Case A (create fresh).
- **Exists** → Case B (append new only). NEVER overwrite. NEVER back up + regenerate.

## Gather inputs (parallel) — both cases

1. **Calendar today** — `mcp__claude_ai_Google_Calendar__list_events` (primary, today). Unavailable → `> [!warning] Calendar unavailable` callout, skip Calendar.
2. **Due today + overdue** — `mcp__todoist__find-tasks-by-date({"startDate":"today","overdueOption":"include-overdue","limit":50})`. Capture `id`, `content`, `projectId`, `priority`, `labels`, `dueDate`, `deadlineDate`.
3. **Undated open tasks** — `mcp__todoist__find-tasks({"filter":"no date","limit":50})`. Keep only those with **no `dueDate` AND no `deadlineDate`** (Todoist's "no date" filters on due only — drop any that carry a deadline). These are the date-me queue. If the result hit the limit, note the truncation in the summary (no silent cap).
4. **Project tree** — `mcp__todoist__find-projects({"limit":200})`. Build `projectId → "[<Leaf Name>]"` tag map (leaf = the project's own name).

## Line format (authoritative: [[todoist-mapping]])

```
- [ ] [Tag] content (due YYYY-MM-DD, deadline YYYY-MM-DD, labels: a, b) <!-- todoist:id -->
```

- **One `[Tag]` = one project** (leaf name from the tree). It drives `/sync` routing for any line Jake later edits or creates. Tasks living in Todoist **Inbox** have no project → emit **no tag**; Jake adds a `[Tag]` to route them (next `/sync` moves them out of Inbox).
- Parenthetical carries only the markers that exist: `due` / `deadline` / `labels:` (labels last). Omit the parenthetical entirely if none apply.
- `<!-- todoist:id -->` is always last.
- **Dedupe by Todoist ID** — each ID appears once. Precedence: Today > Overdue > Backlog.

## Case A — note missing (create fresh)

Read `Templates/daily-note.md`, follow its structure, populate:

- **Calendar** — today's events (or warning callout).
- **Focus** — LEAVE EMPTY. Jake curates this.
- **Today** — tasks whose `dueDate` is today. Flat list (no Area/section hierarchy).
- **Overdue** — tasks whose `dueDate` is before today.
- **Backlog — needs a date** — undated open tasks (input 3), minus any already in Today/Overdue. This is where Jake assigns deadlines; `/sync` pushes them and the task graduates on a future plan.
- **Quick capture** — LEAVE EMPTY (blank zone for net-new tasks Jake types).

Write the note (`mcp__obsidian__write_note`).

## Case B — note exists (append new only)

NEVER overwrite. Steps:

1. Read the existing note; collect every `<!-- todoist:id -->` already present.
2. From inputs 2-3, take every Todoist task whose ID is **not** already in the note.
3. If any: append them under a `## New since plan` heading using the line format above (`mcp__obsidian__patch_note`, append-only, existing content untouched). **`## New since plan` is the one heading daily-plan creates outside `Templates/daily-note.md` — an intentional, documented exception: it is an append-only overflow zone that exists only when re-running on an existing note, never in a fresh Case-A note.**
4. Touch nothing else — no edits to existing lines, sections, Focus, or Quick capture.
5. If nothing new: report "note exists, no new items — unchanged."

## Log to Supabase

One `command_runs` row (`_shared/supabase-logging.md`): `command='daily-plan'`, `scope=<date>`, `status='applied'`, `applied_at=now()`. `applied_counts` = `{today, overdue, backlog, new_appended}`; `applied_ops` = section summary. Non-blocking — warn and continue if Supabase is unreachable.

## Behavior

- **READ-ONLY on Todoist.** No completes, no edits, no label/date changes. All Obsidian→Todoist writes happen in `/sync`.
- **NEVER overwrite an existing note.** No `.bak` files are created.
- **No dry-run gate** (unlike `/sync`): Case A is a one-time write when the note is missing; Case B is strictly append-only. Both are non-destructive, so daily-plan writes directly without a `y` prompt.
- Calendar MCP unavailable → warning callout, skip section.
- Todoist MCP unavailable → warning; Case A writes the empty template scaffold, Case B reports unchanged.
- Summary: `Daily plan: T today, O overdue, B backlog.` (Case A) or `Appended N new item(s) to existing note.` / `Note exists, unchanged.` (Case B).

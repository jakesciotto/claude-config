---
description: "DEPRECATED — do not run. Replaced by the Obsidian-native task system (/capture, /daily, /archive)."
argument-hint: "[scope: today|all|<path>]"
---

> [!danger] DEPRECATED — DO NOT RUN.
> This bidirectional sync is retired. Tasks now live **only** in Obsidian (Dataview inline fields); running this would push markdown to Todoist and recreate the exact drift this system was built to kill. Use **`/capture`** (Todoist Inbox → Obsidian), **`/daily`**, and **`/archive`** instead. See `docs/superpowers/specs/2026-06-02-obsidian-native-task-system-design.md`. If you truly need this, delete this banner first.

You are running Obsidian → Todoist sync for Jake. Scope `$1` (default: `today`).

## Truth model

**Obsidian is the brain.** One push direction + two narrow pulls (completion, homing):

- **Obsidian → Todoist** for everything Jake controls: create, project (via `[Tag]` / path), content, due, deadline, labels, complete (`[x]`), delete (`[-]`). On any metadata difference, **Obsidian wins** — overwrite Todoist with the note's value.
- **Todoist → Obsidian**, two cases only: (1) a task completed elsewhere → patch the note line to `[x]`; (2) **homing** — an open Todoist task with no tracked line in its home file gets a line appended there.
- Todoist owns only: task `id`, recurrence pattern.

Completion is monotonic toward done — unchecking does not reopen; reopen in Todoist.

**DEFAULT IS DRY-RUN.** Never write without an explicit `y`.

## Task identity + home (read this — it prevents the duplicate-task bug)

- **Identity = the Todoist `id`.** A line is *tracked* once it carries `<!-- todoist:id -->`.
- **Permanent home = the mapped project file** (`Areas/**/*.md`, `Projects/**/README.md`), resolved through the single bidirectional `project ↔ path` table below. Each open task has **exactly one** tracked line in its home file.
- **A Daily Note is a dated working view**, not a home. A `[Tag]` line there is how Jake creates/schedules/completes; the same task lives permanently in its project file.
- `[Tag]`, file path, and Todoist project are **one identity through one table** — `[Marriage]` ≡ `Areas/Home/marriage.md` ≡ `Areas > Home > Marriage`. Never resolve a tag and a path differently.
- **Create exactly once.** Before diffing, build a vault-wide index of every tracked `id` and the files it appears in. A no-id line creates once and is then tracked; the homing pull only ever appends an `id` that has **no tracked line in its home file**. An `id` already tracked anywhere is never re-created.

## Scope resolution

| `$1` | Files scanned |
|---|---|
| `today` (default) | `Daily Notes/<YYYY-MM>/<today>.md`, all `Projects/**/README.md`, all `Areas/**/*.md` (excl. `Templates/`, `Resources/`, `Archives/`, `Meeting Notes/`, `Areas/Work/Scratch/`) |
| `all` | Same as `today` + last 7 Daily Notes |
| `<explicit path>` | Just that file (homing into other files still applies) |

**The home-file walk is mandatory — never deferred.** Every `today`/`all` run reads and reconciles *every* `Projects/**/README.md` (+ subfiles) and `Areas/**/*.md`, not just the Daily Note. Skipping it is the root cause of page↔Todoist drift (pages silently go stale for weeks). The Step 7 report **must** state the count of home files scanned; a count of 0 on a `today`/`all` run is a bug, not a clean run.

## Build the bidirectional mapping

`mcp__todoist__find-projects({"limit":200})` → build BOTH directions of one table:

```
project_of_path = { "Areas/Home/marriage.md": "Areas > Home > Marriage", "Projects/Easton Plus/": "Projects > Easton Plus", ... }
home_path_of_project = inverse(project_of_path)   // Todoist project → canonical Obsidian home file
todoist_index = { "Areas > Home > Marriage": <id>, ... }   // qualified name → Todoist project id
tag_resolves_to = leaf-name lookup into the SAME table (e.g. "Marriage" → "Areas > Home > Marriage")
```

Path / tag rules are authoritative in `Resources/conventions/todoist-mapping.md` (Projects subfolders → project root; Areas files → path + section-header rule; leaf `[Tag]` → same project).

## Pre-pass: tracked-id index

Across **all** scoped files, collect every `<!-- todoist:id -->` → `{id: [(file, line, state, is_home_file)]}`. `is_home_file` = the file equals `home_path_of_project[project_of(id)]`. This index drives create-once, homing, and multi-location dedup.

Lines carrying `<!-- todoist:gone -->` are **sentinels** — skip all op generation for them (no create, no diff, no homing). They mark a task that 404'd in a prior run.

## Walk each scoped file

### 1. Parse each checkbox line

Regex `^(\s*)- \[(.)\] (.*)$`. Extract, in order: leading `[Tag]` (Daily Notes), trailing `<!-- todoist:id -->`, trailing parenthetical `(due …, deadline …, labels: a, b)`. Inside the parenthetical, parse only the `due` / `deadline` / `labels:` segments; **ignore any other token** — never treat it as content or a label.

State: only `[x]` (done) and `[-]` (cancelled) carry meaning; **every other glyph is open** — including the daily-plan-emitted render-only flags `[!]` (overdue) and `[*]` (future deadline), which sync ignores entirely. No tier/priority is ever derived from the checkbox glyph — tiers (`now`/`next`/`waiting`/`blocked`/`someday`) live in the `labels:` parenthetical and sync through the normal label channel.

### 2. Resolve target project

- **Daily Notes:** `[Tag]` → table. No tag → Todoist Inbox.
- **Project/Area files:** path → table, plus the Areas section-header rule.

### 3. Match + diff → ops

`id` present → `fetch-object` (404 → `gone`). No `id` → `create`.

| Obsidian | Todoist | Op |
|---|---|---|
| no id, open (any file) | — | `create` in target project → write id back into the line → if the line is in a Daily Note, also stage `home` (append a tracked line to the project's home file) |
| open Todoist task, no tracked line in its **home file** | — | `home`: append `- [ ] content (markers) <!-- todoist:id -->` to the home file under `## Tasks` (or the file's primary task section; project root for Projects subfolders) |
| tracked line, `[Tag]` changed (Daily Notes) | different project | `move-project` (`update-tasks` `projectId`/`sectionId`); re-home into the new project's file AND remove the stale tracked line from the **old** home file |
| `(due)` add/edit/remove | differs | `set-due`/`clear-due` (`reschedule-tasks` if recurring) |
| `(deadline)` add/edit/remove | differs | `set-deadline`/`clear-deadline` |
| `(labels:)` add/edit/remove | differs | `set-labels` (full replace) / `clear-labels` |
| content edited | differs | `update-content` |
| `[x]` | open | `complete` |
| `[-]` | open | `delete` |
| any open state | **done in Todoist** | `note-complete`: patch line → `[x]` (mirror to every tracked line of that id) |
| id 404 | gone | flag `> [!warning] Task gone in Todoist`; no Todoist write |

`move-project` uses `update-tasks` `projectId` (the `project-move` tool only moves projects workspace↔personal). Recurring: complete advances the next instance — never re-fire; reschedule via `reschedule-tasks` (preserves pattern).

**Homing pass (this sources the `home` rows above).** For each project/area file in scope, call `mcp__todoist__find-tasks({"projectId": <that file's project>})` for open tasks. Any returned id with **no tracked line in that file** (per the pre-pass index, and not a `gone` sentinel) becomes a `home` op appending a line to it. This is bounded to scoped files — the default `today` scope already scans every `Projects/**/README.md` and `Areas/**/*.md`, so every active project's home file is covered in one pass. A task already tracked in its home file is never re-homed.

### 4. Stage + dedupe (multi-location precedence)

A single `id` may appear in its home file **and** in today's Daily Note (normal steady state — view + home). Apply **at most one** op per id:

- **Metadata** (due/deadline/labels/content/move): precedence **Daily Note (current working view) > home file** — BUT guarded by staleness (below). If both carry edits that disagree, take the Daily Note's value and note the conflict.
- **Staleness guard — never overwrite a fresher value with a staler one.** A home file whose `last_touched` predates the task's Todoist activity is a *stale archive*, not an edit. When a home-file value disagrees with Todoist and the file is stale, **Todoist wins → refresh the page** (do not push the old page value to Todoist). Page-wins applies only when the page is the *fresher* edit. This blocks the failure mode where a 3-week-old page clobbers correct current Todoist data.
- **Completion:** honored from any location; `note-complete` and forward `complete` are mutually exclusive per id.
- After any change, propagate the result to the id's other tracked lines **including the home-file line** via `mcp__obsidian__patch_note` using the **winning value** (the Obsidian winner, or Todoist when the staleness guard fired). Completion mirrors `[x]` / drops the completed line from a home-file task list; a metadata edit copies the same parenthetical. Home-file lines are reconciled every run — they are not exempt from the completion/metadata pull, which is why pages stay current instead of drifting.

Dedupe the final op list by `(type, id, file, line)`.

## Present, apply, log

### 5. Proposal

```
Sync proposal for <scope>:
- M creates · H homings (task → project file)
- P project moves · E metadata edits
- N completes · R note-completes (Todoist → [x])
- D deletes · G gone
[full list grouped by op type]
Apply? (y/N)
```

Log the proposal to Supabase (`_shared/supabase-logging.md`): one `command_runs` row, `command='sync'`, `status='proposed'`, with `proposed_counts` + `proposed_ops`; keep the id. Non-blocking.

### 6. Apply on `y`

Tools: `mcp__todoist__*` for Todoist ops; `mcp__obsidian__patch_note` for note writes (never `mcp__todoist__patch_note` — that does not exist).

- Creates → `mcp__todoist__add-tasks` (capture ids) → `mcp__obsidian__patch_note` to inject `<!-- todoist:id -->`.
- Homings → `patch_note` to append the tracked line to the home file.
- Moves/content/due/deadline/labels → `mcp__todoist__update-tasks` (`set-labels` passes full array); recurring reschedules → `mcp__todoist__reschedule-tasks`. A `move-project` also re-homes: `patch_note` to append the line to the new project's file and remove it from the old one.
- Completes → `complete-tasks`. Deletes → `delete-object`.
- `note-complete` → `patch_note` line marker → `[x]` (match full line; preserve content + id), all tracked copies.
- `gone` → `patch_note` append warning + `<!-- todoist:gone -->`.

### 7. Report + log result

```
Scope <scope>: scanned <F> home files + <D> daily note(s).
Applied: M creates, H homings, P moves, E edits, N completes, R note-completes, D deletes. Flagged: G gone.
⚠ Drift: <list any id whose tracked lines still disagree with Todoist after apply, or _none_>
```

**Consistency check (always run, after apply).** For every tracked `id`, assert Todoist `==` each of its tracked lines on state, due, deadline, labels, and content. Any surviving mismatch is **drift** — list it under `⚠ Drift` with the id, the files involved, and the differing field. Drift after a successful apply means a bug (a line was missed); never report a run as clean while drift exists. A run that touched 0 home files on `today`/`all` scope is itself drift.

Update the Step 5 row: `status='applied'`, `applied_at=now()`, fill `applied_counts` + `applied_ops`; or `status='vetoed'` on N. Non-blocking.

### 8. Mirror completions to Supabase

Full Todoist completion mirror → `public.archived_tasks` (`_shared/supabase-logging.md`). `find-completed-tasks` over the window (since previous `command='sync'` `run_date`, default 7 days); upsert by `todoist_id` (PK), recurring collapses to latest with `completion_count++`. Non-blocking; runs regardless of apply/veto.

## Behavior

- DRY-RUN default — never write without `y`.
- Obsidian wins on all metadata. Only Todoist→Obsidian writes are `note-complete` and `home`.
- Todoist MCP unavailable → abort with a message.
- Before applying, capture current file content; on apply error, no auto-rollback (re-run to reconcile).

## Edge cases

- **Subtasks** (nested checkboxes): preserve `parentId`; new nested lines create with the parent line's id as `parentId`.
- **Multi-line descriptions:** only the bracket line is the task; following indented non-checkbox bullets become the Todoist description.
- **`<!--` inside content:** strip the id comment with a narrow end-of-line-anchored regex.
- **Homing target ambiguity:** if a project's home file has no `## Tasks` section, append under the file's first task-bearing `##` heading, else at end of file. Projects subfolder tasks always go to the README under `## Tasks`.

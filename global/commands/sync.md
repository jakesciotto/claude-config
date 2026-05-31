---
description: Bidirectional Obsidian ↔ Todoist sync via path mapping + checkbox state diff
argument-hint: "[scope: today|all|<path>]"
---

You are running Obsidian ↔ Todoist sync for Jake. Scope $1 (default: `today` = today's Daily Note + project READMEs touched today). Forward direction (Obsidian state → Todoist) for completes/creates/edits/labels; reverse direction (Todoist completions → Obsidian `[x]`) via the bidirectional reconciliation pass. Todoist is the source of truth for completion state.

## Context

Path mapping rules: `Resources/conventions/todoist-mapping.md` (authoritative).
Vault: `/Users/jakesciotto/Documents/Obsidian Vault`, via `mcp__obsidian__*`.
Todoist: `mcp__todoist__*`.

## Scope resolution

| `$1` | Files scanned |
|---|---|
| `today` (default) | `Daily Notes/<YYYY-MM>/<today>.md` (month folder = first 7 chars of date), all `Projects/**/README.md`, all `Areas/**/*.md` (excluding `Templates/`, `Resources/`, `Archives/`, `Meeting Notes/`, `Areas/Work/Scratch/`) |
| `all` | Same as `today` + last 7 Daily Notes (search `Daily Notes/<YYYY-MM>/` folders; may span two month folders near a boundary) |
| `<explicit path>` | Just that file |

### Completion reconciliation — bidirectional (ALWAYS runs, every scope)

Regardless of `$1`, before the main walk, sweep the **last 7 Daily Notes** for every checkbox line carrying a `<!-- todoist:<id> -->`, and reconcile completion state in **both directions** in one pass. This is the true bidirectional layer: forward closes the leak where `[x]` ticked on a day `/sync` isn't run is never revisited; reverse closes the gap where a task completed directly in Todoist stays `[ ]` in the note forever (and would otherwise reopen on conflict).

1. Collect every line matching `^\s*- \[(.)\] .*<!-- todoist:([a-zA-Z0-9]+) -->` across the last 7 daily notes (any checkbox state, not just done).
2. Dedupe by Todoist ID (keep each occurrence's file+line for writes). Build the Todoist-state set with ONE batched `find-completed-tasks` over the window, then `fetch-object` only for IDs absent from it. `checked:true` (or a completion record in the window) = done; otherwise open; 404 = gone.
3. Reconcile per line by `(obsidian_state, todoist_state)`:
   - **Obsidian done (`[x]`/`[-]`) + Todoist open** → FORWARD: stage `complete` (`[x]`) or `delete` (`[-]`) on Todoist.
   - **Obsidian open (`[ ]`/`[/]`/`[?]`/`[>]`) + Todoist done** → REVERSE: stage `note-complete` — patch the Obsidian line `[<state>]`→`[x]` (Todoist is the source of truth for completion). `[>]` proposed lines included: if the underlying task is done, the proposal is moot — mark `[x]`.
   - **Obsidian open + Todoist gone (404)** → stage `gone` marker (existing behavior).
   - **States agree** (both done / both open) → no-op.
4. Recurring tasks: a recurring task in Todoist reads `checked:false` (it advanced to the next instance), so live state alone won't flip it. Use the `find-completed-tasks` window's completion records (which DO include recurring completions): if a completion record for that ID has `completedAt` on/before the note's date, treat that occurrence as done — FORWARD no-op (already done), REVERSE flip the note line `[x]`. Never stage a `complete` that would re-fire a recurring task.
5. Fold both directions into the proposal: `Forward completes (older notes)` and `Reverse completes (Todoist → note [x])` groups, visible before apply.

**Reopen semantics:** unchecking a box in Obsidian does NOT reopen a Todoist-completed task — reverse-sync will re-check it. To reopen, reopen in Todoist (the system of record); the next `/sync` reflects it back.

## Build mapping table at runtime

Call `mcp__todoist__find-projects({"limit": 200})`. Build:

```
todoist_index = {
  "Projects > Easton Plus": <id>,
  "Areas > Home > Marriage": <id>,
  "Areas > Work > Customers > AskElephant": <id>,
  ...
}

path_to_project = {
  "Projects/Easton Plus/": "Projects > Easton Plus",
  "Areas/Home/marriage.md": "Areas > Home > Marriage",
  "Areas/Work/Customers/askelephant.md": "Areas > Work > Customers > AskElephant",
  ...
}
```

Path mapping logic (per file path):

1. **Projects:**
   - `Projects/README.md` → `Projects > Miscellaneous`
   - `Projects/<Name>/**` → `Projects > <Name>` (use folder name as project)
2. **Areas/Home:**
   - `Areas/Home/README.md` → `Areas > Home` (root)
   - `Areas/Home/<slug>.md` → `Areas > Home > <CapitalizedSlug>` (lookup in todoist_index)
3. **Areas/Personal:**
   - `Areas/Personal/README.md` → `Areas > Personal` (root)
   - `Areas/Personal/<slug>.md` → `Areas > Personal > <CapitalizedSlug>`
4. **Areas/Work:**
   - `Areas/Work/README.md` → `Areas > Work` (root)
   - `Areas/Work/<slug>.md` (goals/admin/learning) → `Areas > Work` root, section name matches `<Slug>`
   - `Areas/Work/csm-playbook.md`, `Areas/Work/nrr-tracking.md` → `Areas > Work` (root)
   - `Areas/Work/Customers/<slug>.md` → `Areas > Work > Customers > <DisplayName>` (resolve slug back to Todoist display name via slug rule)
5. **Daily Note:** per-checkbox tag parsing (see below).

## For each scoped file

### Step 1: Read file

`mcp__obsidian__read_note({"path": file})`.

### Step 2: Walk checkboxes

Regex match each line: `^(\s*)- \[(.)\] (.*)$`

State map:
- `[ ]` → open
- `[/]` → in-progress
- `[x]` → done
- `[-]` → cancelled
- `[?]` → waiting
- `[!]` → important
- `[*]` → star
- `[>]` → proposed (agent-suggested categorization/move, awaiting user affirmation)

### Step 3: Determine Todoist target per checkbox

**For Daily Note files:**
- Parse inline tag `[<Tag>]` at start of content. Look up in todoist_index → target project.
  - Inbox triage section uses a trailing `→ [<Tag>]` annotation as the routing tag. The checkbox state gates whether the agent acts on it (see affirmation flow below).
- If no tag:
  - Section header context: `## Quick capture*` or `## Inbox triage` → Todoist Inbox
  - Else → Todoist Inbox (default)
- Inline `[<Tag>]` stripped from content before storing as task content.
- **Dedupe by ID:** the same Todoist ID may appear in multiple sections (Focus + triage + per-stream). Collapse to one task; act once. Obsidian state precedence: done > cancelled > in-progress > open.
- **Proposal → affirmation flow (`[>]`):** the agent writes a suggested categorization/move as a `[>]` checkbox with the routing tag. `[>]` is a PROPOSAL — never write it to Todoist. Surface all `[>]` lines under a "Suggested (awaiting affirm)" bucket in the proposal.
  - **Affirm:** user flips `[>]` → `[ ]`. Now eligible to move (see below).
  - **Reject:** user flips `[>]` → `[-]` → leave in Inbox, no move; log `affirmed:false`.
  - Same-run: act on whatever state the note holds when /sync runs — `[ ]` (affirmed) lines move now; `[>]` stay held.
- **Auto-move affirmed tagged Inbox items:** for an **open `[ ]`** linked task whose Todoist `projectId` is Inbox and whose note tag maps to a real project, stage `project-move` (via `update-tasks` with `projectId`/`sectionId`). On apply, rewrite the note annotation `→ [<Tag>]` to `→ moved: [<Tag>]` and log the op with `suggested:true, affirmed:true`. Query Inbox once with `find-tasks({projectId: inbox})` rather than fetching each ID. `[>]` lines are NOT moved.
- **Deadline/due reconcile:** if a note line's date annotation (`(deadline YYYY-MM-DD)` / `(due …)`) differs from Todoist, stage a `reschedule`/`deadline` update.

**For project/area files:**
- `target_project` from path mapping.
- `section_header` = nearest preceding `## <Name>` heading.
- If `target_project` has a Todoist section matching `<Name>`: assign that section.
- Else: project root (no section).

### Step 4: Parse ID comment

Regex on content trailing: `<!-- todoist:([a-zA-Z0-9]+) -->`

If present: extract id. Strip comment from content for matching.
If absent (`new` task or `gone` marker): no Todoist match by ID — try fuzzy match.

### Step 5: Match to Todoist

If `id`:
- `mcp__todoist__fetch-object({"type": "task", "id": <id>})` → existing task or 404.
- 404 → mark as `gone` for diff.

Else (no id):
- `mcp__todoist__find-tasks({"projectId": <target>, "searchText": <content>, "limit": 5})`.
- Filter to exact content match (case-insensitive). If single match → use it. If multiple → flag conflict. If none → stage as `create`.

### Step 6: Compute diff per checkbox

| Obsidian state | Todoist state | Action |
|---|---|---|
| open `[ ]` | open | no-op |
| open `[ ]` | done | REVERSE-SYNC: stage `note-complete` (patch line → `[x]`). Todoist is source of truth for completion; do NOT reopen. To reopen, reopen in Todoist. |
| in-progress `[/]` | open | no-op (state lives in Obsidian only for now) |
| in-progress `[/]` | done | REVERSE-SYNC: stage `note-complete` (patch line → `[x]`) |
| waiting `[?]` | done | REVERSE-SYNC: stage `note-complete` (patch line → `[x]`) |
| done `[x]` | open | stage `complete` |
| done `[x]` | done | no-op |
| cancelled `[-]` | open | stage `delete` |
| waiting `[?]` | open, no `waiting` label | stage `add-label: waiting` |
| important `[!]` | priority p4 | stage `set-priority: p1` |
| star `[*]` | no `star` label | stage `add-label: star` |
| no id + open | n/a | stage `create` in target project/section |
| content edited | mismatch w/ Todoist | stage `update-content` |
| any linked | in Todoist Inbox, tag maps to real project | stage `project-move` to mapped project/section |
| any linked | date annotation ≠ Todoist date | stage `reschedule` (due) / `deadline` update |

Note `project-move` uses `update-tasks` with `projectId` — the `project-move` tool only moves projects between workspace/personal, not tasks.

Mark `gone` (id 404) as: `> [!warning] Task gone in Todoist` annotation on the Obsidian line (no Todoist write).

### Step 7: Stage all diffs

The bidirectional reconciliation pass and the main walk can both emit ops for the same line (e.g. today's note is in both). **Dedupe the combined op list by `(type, id, file, line)`** — keep one. For completion ops specifically, dedupe by `(id)` across passes: a given task gets at most one `complete` (forward) or one `note-complete` (reverse), never both.

Build a list of operations:

```
[
  { type: "complete", id: "6...", content: "...", file: "Daily Notes/2026-05/2026-05-16.md", line: 12 },   // forward: Obsidian [x] → Todoist done
  { type: "note-complete", id: "6...", file: "Daily Notes/2026-05/2026-05-20.md", line: 14, from: "[ ]" }, // reverse: Todoist done → Obsidian [x]
  { type: "create", target: "Projects > Easton Plus", content: "...", file: "...", line: 18 },
  { type: "update-content", id: "...", from: "...", to: "..." },
  { type: "add-label", id: "...", label: "waiting" },
  ...
]
```

### Step 8: Present summary to user

```
Sync proposal for <scope>:
- N completes (forward: Obsidian [x] → Todoist)
- R reverse-completes (Todoist done → Obsidian [x])
- M creates (in projects: <breakdown>)
- K content updates
- J label/priority changes
- D deletions
- C conflicts (fuzzy/multi-match only — require manual resolution)
- G gone (Obsidian lines flagged)

[show full list, grouped by op type]

Apply? (y/N)
```

**Then log the proposal to Supabase** (`_shared/supabase-logging.md`): insert one `command_runs` row, `command='sync'`, `status='proposed'`, with `proposed_counts` + `proposed_ops`. Keep the returned `id`. Non-blocking — if Supabase is unauthed/unreachable, warn and continue.

### Step 9: Apply on confirmation

If `y`:
- Completes: `mcp__todoist__complete-tasks({"ids": [...]})`.
- Creates: `mcp__todoist__add-tasks({"tasks": [{content, projectId, sectionId, labels, priority}]})`. Capture new IDs.
- Updates / labels / priority: `mcp__todoist__update-tasks`.
- Deletes: `mcp__todoist__delete-object({"type": "task", "id": ...})`.

For each `note-complete` (reverse-sync), patch the Obsidian line via `mcp__obsidian__patch_note`, replacing the checkbox marker `[ ]`/`[/]`/`[?]`/`[>]` with `[x]` (match the full line to keep the replacement unique; preserve content + ID comment). No Todoist write.

For each `create`, patch the Obsidian line via `mcp__obsidian__patch_note` to inject `<!-- todoist:<new-id> -->` after content.

For each `gone`, patch Obsidian line to append `<!-- todoist:gone -->` and prefix with `[?]` if not already.

### Step 10: Report

```
Applied: N completes, R reverse-completes (note → [x]), M creates, K updates, J label changes, D deletes.
Skipped: C conflicts (listed above), G gone markers (Obsidian patched).
```

### Step 11: Log result to Supabase

Update the `command_runs` row from Step 8 (`_shared/supabase-logging.md`):
- Applied → `status='applied'`, `applied_at=now()`, fill `applied_counts` + `applied_ops`.
- Vetoed (user answered N) → `status='vetoed'`, leave `applied_*` null.

Non-blocking — logging failure never fails the sync.

### Step 12: Mirror completed tasks to Supabase

Full Todoist completion mirror → `public.archived_tasks` (`_shared/supabase-logging.md`). Each /sync:
- `mcp__todoist__find-completed-tasks` over a window (since the previous `command_runs.run_date` for `command='sync'`, default last 7 days). **Reuse the completion set already fetched by the bidirectional reconciliation pass** if its window covers this one — avoid a redundant call.
- Upsert each completion by `todoist_id` (PK). Recurring tasks collapse to latest: same id updated, `completion_count` incremented when the incoming `completed_at` is newer. Resolve `project` from the project index.

Non-blocking. Independent of whether the user applied or vetoed the sync proposal.

## Behavior

- DEFAULT IS DRY-RUN — never write without explicit `y`.
- Backup safety: before any write, capture current Obsidian file content. On error during apply, no rollback (Todoist + Obsidian state may diverge — user re-runs).
- Conflicts (Obsidian-done vs Todoist-done at different times) → flag, don't auto-resolve.
- If Todoist MCP unavailable: abort with message.
- Recurring tasks: completing a recurring task in Todoist auto-creates next instance — `/sync` shouldn't re-create from the Obsidian `[x]`. Detect `recurring: true` from Todoist task, treat `[x]` as `complete` only.

## Edge cases

- **Subtasks** (Obsidian nested checkboxes with indent): preserve `parentId` from Todoist. New nested checkboxes → create with `parentId` matching the parent line's Todoist ID.
- **Multi-line task descriptions** in Obsidian: only the bracket line is the task; following indented bullets become Todoist task description.
- **Task content with `<!--` in body**: rare, but strip ID comment via narrow regex anchored at end-of-line.

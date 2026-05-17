---
description: Bidirectional Obsidian ↔ Todoist sync via path mapping + checkbox state diff
argument-hint: "[scope: today|all|<path>]"
---

You are running Obsidian → Todoist sync for Jake. Scope $1 (default: `today` = today's Daily Note + project READMEs touched today).

## Context

Path mapping rules: `Resources/conventions/todoist-mapping.md` (authoritative).
Vault: `/Users/jakesciotto/Documents/posthog`, via `mcp__obsidian__*`.
Todoist: `mcp__todoist__*`.

## Scope resolution

| `$1` | Files scanned |
|---|---|
| `today` (default) | `Daily Notes/<today>.md`, all `Projects/**/README.md`, all `Areas/**/*.md` (excluding `Templates/`, `Resources/`, `Archives/`, `Meeting Notes/`, `Areas/Work/Scratch/`) |
| `all` | Same as `today` + last 7 Daily Notes |
| `<explicit path>` | Just that file |

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

### Step 3: Determine Todoist target per checkbox

**For Daily Note files:**
- Parse inline tag `[<Tag>]` at start of content. Look up in todoist_index → target project.
- If no tag:
  - Section header context: `## Quick capture` or `## Inbox triage` → Todoist Inbox
  - Else → Todoist Inbox (default)
- Inline `[<Tag>]` stripped from content before storing as task content.

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
| open `[ ]` | done | conflict — ask user; default reopen Todoist |
| in-progress `[/]` | open | no-op (state lives in Obsidian only for now) |
| done `[x]` | open | stage `complete` |
| done `[x]` | done | no-op |
| cancelled `[-]` | open | stage `delete` |
| waiting `[?]` | open, no `waiting` label | stage `add-label: waiting` |
| important `[!]` | priority p4 | stage `set-priority: p1` |
| no id + open | n/a | stage `create` in target project/section |
| content edited | mismatch w/ Todoist | stage `update-content` |

Mark `gone` (id 404) as: `> [!warning] Task gone in Todoist` annotation on the Obsidian line (no Todoist write).

### Step 7: Stage all diffs

Build a list of operations:

```
[
  { type: "complete", id: "6...", content: "...", file: "Daily Notes/2026-05-16.md", line: 12 },
  { type: "create", target: "Projects > Easton Plus", content: "...", file: "...", line: 18 },
  { type: "update-content", id: "...", from: "...", to: "..." },
  { type: "add-label", id: "...", label: "waiting" },
  ...
]
```

### Step 8: Present summary to user

```
Sync proposal for <scope>:
- N completes
- M creates (in projects: <breakdown>)
- K content updates
- J label/priority changes
- D deletions
- C conflicts (require manual resolution)
- G gone (Obsidian lines flagged)

[show full list, grouped by op type]

Apply? (y/N)
```

### Step 9: Apply on confirmation

If `y`:
- Completes: `mcp__todoist__complete-tasks({"taskIds": [...]})`.
- Creates: `mcp__todoist__add-tasks({"tasks": [{content, projectId, sectionId, labels, priority}]})`. Capture new IDs.
- Updates / labels / priority: `mcp__todoist__update-tasks`.
- Deletes: `mcp__todoist__delete-object({"type": "task", "id": ...})`.

For each `create`, patch the Obsidian line via `mcp__obsidian__patch_note` to inject `<!-- todoist:<new-id> -->` after content.

For each `gone`, patch Obsidian line to append `<!-- todoist:gone -->` and prefix with `[?]` if not already.

### Step 10: Report

```
Applied: N completes, M creates, K updates, J label changes, D deletes.
Skipped: C conflicts (listed above), G gone markers (Obsidian patched).
```

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

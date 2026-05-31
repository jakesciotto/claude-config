---
description: Draft today's Daily Note from Todoist + Calendar + project READMEs
argument-hint: "[YYYY-MM-DD]"
---

You are drafting Jake's Daily Note for $1 (default: today).

> **Structure is owned by `Templates/daily-note.md`, not by this command.** Read that template at runtime and follow the `> [!info]` agent-instructions embedded in each section. This command specifies only the data-gathering and how to populate the template's dynamic parts. If template and command ever disagree on structure, **the template wins** — never hardcode a skeleton here.

## Context

Jake's PARA system:
- Index: `Resources/system-design/README.md`
- Operational rules: `Resources/conventions/{naming,para-structure,todoist-mapping,project-readme-fields,agent-commands-usage}.md`
- **Template (authoritative structure): `Templates/daily-note.md` — READ IT FIRST.**
- Vault: `/Users/jakesciotto/Documents/Obsidian Vault`, via `mcp__obsidian__*`
- Todoist: `mcp__todoist__*`
- Calendar: `mcp__claude_ai_Google_Calendar__*`

## Gather inputs (parallel)

1. **Calendar today** — `mcp__claude_ai_Google_Calendar__list_events` for today, primary calendar.

2. **Todoist today + overdue** — `mcp__todoist__find-tasks-by-date({"startDate": "today", "overdueOption": "include-overdue", "limit": 50})`. Capture: `id`, `content`, `projectId`, `sectionId`, `priority`, `labels`, `dueDate`, `deadlineDate`.

3. **Todoist `@next` labeled** — `mcp__todoist__find-tasks({"labels": ["next"], "limit": 50})`. Same fields.

4. **Todoist Inbox stale** — `mcp__todoist__find-tasks({"projectId": "inbox", "limit": 50})`. Filter to items created > 24h ago.

5. **Project READMEs** — `mcp__obsidian__list_directory({"path": "Projects"})`, then read each `Projects/<name>/README.md`. Capture frontmatter (esp. `blocked_by`).

6. **Yesterday's Daily Note** — `mcp__obsidian__read_note({"path": "Daily Notes/<YYYY-MM>/<yesterday>.md"})` (`<YYYY-MM>` = yesterday's month folder; mind month rollover). If it exists, parse unchecked items (`- [ ]`, `- [/]`, `- [?]`) as roll-forward **candidates** (gated into Backlog — see compose rules).

7. **Project tree + sections** — `mcp__todoist__find-projects({"limit": 200})`; capture `id`, `name`, `parentId` to reconstruct the Area → sub-project → sub-sub-project hierarchy, and build the `projectId → "[<Leaf Name>]"` canonical-tag map (per [[todoist-mapping]]). For each project that has tasks surfacing today (from steps 2-3), `mcp__todoist__find-sections({"projectId": <id>})` to get section names + IDs. This tree drives the Per-stream heading hierarchy.

## Read the template

Read `Templates/daily-note.md`. It defines the section set, order, heading scheme, and per-section `> [!info]` rules. Populate each section using its embedded instruction plus the compose rules below.

In the **output note**:
- **Keep** the `> [!tip] Checkbox states` callout (user-facing legend).
- **Strip** every `> [!info]` callout — those are agent-instructions, not note content.
- Replace all `<placeholders>`; delete the template's `Example section` / `Sub-project of …` scaffolding lines.

## Compose rules

- **Focus (5 max)** — up to 5 top items across streams, area-tagged `[Work]` / `[Projects]` / `[Home]` (Personal items fold under `[Home]`). Prioritize P0/P1 and today-deadline. Use `- [/]` for the one being started now; `- [ ]` for the rest. Each line carries its `<!-- todoist:id -->`.

- **Inbox triage (Todoist Inbox > 24h)** — stale Inbox items as `- [>] <content> <!-- todoist:id --> → [<leaf-tag>]` (proposed state, awaiting affirm). Affirm by flipping `[>]`→`[ ]` (next `/sync` moves to the tagged project + rewrites to `→ moved: [Tag]`); reject with `[-]`. `[>]` is **never** written to Todoist.

- **Per-stream next actions** — a live Todoist snapshot (today + overdue + `@next`), **rebuilt fresh each day**, organized into the template's heading hierarchy from the project tree (step 7):
  - Three **Area** streams → `###` headings: **Work, Projects, Home**. The **Home** stream aggregates the sub-projects of BOTH Todoist `Home` (Marriage, Pets, Renovation) and Todoist `Personal` (Scheduling, Training, Finances, Health, Shopping), listed as peer `####` sub-projects under `### Home` (skip empty).
  - Tasks in an Area/project with **no Todoist section** → under `###### Tasks without a section`.
  - Each **Todoist section** in that project → `###### <Section>`.
  - **Direct sub-project** of an Area → `####`; **sub-project of a sub-project** → `#####`. (Heading depth: Area 3, child 4, grandchild 5; sections and "Tasks without a section" are always 6.)
  - **Skip empty** — never emit a heading for a project/section/area with no tasks.
  - Each task line: `- [ ] [<leaf-tag>] <content> <!-- todoist:id --> [optional deadline marker]`. Leaf tag is still required (drives `/sync` routing).

- **Quick capture** — net-new tasks that have **no written sub-project** in Obsidian or Todoist. daily-plan leaves this section **empty** (a blank capture zone for the user); `/sync` attempts to categorize whatever the user adds, each run. Do **not** place rolled-forward or live Todoist tasks here.

- **Backlog** — combined parking lot, deduped by ID against every section above. Three sources:
  1. **Waiting / blocked** — tasks labeled `waiting` → `- [?]`; plus project READMEs whose `blocked_by` is non-null.
  2. **Undated someday** — open Todoist tasks that surfaced (e.g. via `@next`) with **no due date and no deadline** and that aren't in Focus/Per-stream.
  3. **Deadline-gated roll-forward** — yesterday's open `[ ]`/`[/]`/`[?]` items, gated in order: **(a) liveness** — if the line's `<!-- todoist:id -->` is `checked:true` or 404s, do NOT carry forward; reconcile the prior note line to `[x]`. A candidate absent from the step-2 open set is presumed done — confirm with a targeted `fetch-object` before dropping. **(b) deadline** — carry forward only those with a deadline (line marker `(deadline YYYY-MM-DD)` or non-null Todoist `deadlineDate`); a due date is NOT a deadline; undated → drop (resurfaces via its own due/overdue query). Items already shown in Per-stream are not repeated.
  - If Backlog is empty, write `_none_`.

- **Dedupe** — each Todoist ID appears exactly once in the note. Precedence: **Focus > Per-stream > Inbox triage > Backlog**.

## Canonical inline tags

Per `Resources/conventions/todoist-mapping.md`: **Focus** uses Area-level tags (`[Work]`/`[Projects]`/`[Home]`/`[Personal]`); **all other sections** use leaf-level tags so `/sync` can route:

```
- [ ] [Easton Plus] <task> <!-- todoist:ID -->         → Projects > Easton Plus
- [ ] [Marriage] <task> <!-- todoist:ID -->            → Areas > Home > Marriage
- [ ] [Training] <task> <!-- todoist:ID -->            → Areas > Personal > Training
- [ ] [Shopping] <task> <!-- todoist:ID -->            → Areas > Personal > Shopping
- [ ] [Goals] <task> <!-- todoist:ID -->               → Areas > Work, section Goals
- [ ] [AskElephant] <task> <!-- todoist:ID -->         → Areas > Work > Customers > AskElephant
```

Inbox tasks have no tag yet — surface in Inbox triage with a proposed `[>]` tag.

## ID embedding

Every checkbox line sourced from Todoist MUST end with:

```
<!-- todoist:<task-id> -->
```

Renders invisibly in Obsidian preview. Enables `/sync` to match unambiguously.

## Output

Write `Daily Notes/<YYYY-MM>/<date>.md` (month folder = first 7 chars of `<date>`; create it if absent). If the file exists, back it up to `Daily Notes/<YYYY-MM>/<date>.bak.md` via `mcp__obsidian__move_note` first. The note's structure is the populated `Templates/daily-note.md` (see "Read the template").

## Log run to Supabase

After writing, log one `command_runs` row (`_shared/supabase-logging.md`): `command='daily-plan'`, `scope=<date>`, `status='applied'`, `applied_at=now()`. Counts = `{focus, per_stream, inbox_triage, backlog, rolled_forward}`; `applied_ops` = the section summary. daily-plan writes directly (no proposal gate), so a single applied row. Non-blocking — warn and continue if Supabase is unauthed/unreachable.

## Behavior

- READ-ONLY on Todoist. No completes, no label changes. (The roll-forward liveness gate may patch a **prior** note's line to `[x]` — that's an Obsidian write, not a Todoist write.)
- Write to `Daily Notes/<YYYY-MM>/<date>.md` (+ backup in same month folder).
- Calendar MCP unavailable → `> [!warning] Calendar unavailable` callout, skip Calendar section.
- Todoist MCP unavailable → same warning; still emit the Project READMEs portion of Per-stream + Backlog.
- After writing, print summary: `Daily plan written: N focus, M per-stream, K inbox triage, B backlog (R rolled forward).`

---
description: Draft today's Daily Note from Todoist + Calendar + project READMEs
argument-hint: "[YYYY-MM-DD]"
---

You are drafting Jake's Daily Note for $1 (default: today).

## Context

Jake's PARA system:
- Index: `Resources/system-design/README.md`
- Operational rules: `Resources/conventions/{naming,para-structure,todoist-mapping,project-readme-fields,agent-commands-usage}.md`
- Template: `Templates/daily-note.md`
- Vault: `/Users/jakesciotto/Documents/Obsidian Vault`, via `mcp__obsidian__*`
- Todoist: `mcp__todoist__*`
- Calendar: `mcp__claude_ai_Google_Calendar__*`

## Gather inputs (parallel)

1. **Calendar today** — `mcp__claude_ai_Google_Calendar__list_events` for today, primary calendar.

2. **Todoist today + overdue** — `mcp__todoist__find-tasks-by-date({"startDate": "today", "overdueOption": "include-overdue", "limit": 50})`. Capture: `id`, `content`, `projectId`, `priority`, `labels`, `dueDate`, `deadlineDate`.

3. **Todoist `@next` labeled** — `mcp__todoist__find-tasks({"labels": ["next"], "limit": 50})`. Same fields.

4. **Todoist Inbox stale** — `mcp__todoist__find-tasks({"projectId": "inbox", "limit": 50})`. Filter to items created > 24h ago.

5. **Project READMEs** — `mcp__obsidian__list_directory({"path": "Projects"})`, then for each dir read `Projects/<name>/README.md`. Capture frontmatter.

6. **Yesterday's Daily Note** — `mcp__obsidian__read_note({"path": "Daily Notes/<YYYY-MM>/<yesterday>.md"})` where `<YYYY-MM>` = yesterday's month folder (mind month rollover). If exists, parse unchecked items (`- [ ]`, `- [/]`, `- [?]`) as roll-forward **candidates**. A candidate is carried forward only if it is still open in Todoist AND has a deadline (see Roll-forward rule — liveness gate, then deadline gate).

7. **Build projectId → canonical tag map** — `mcp__todoist__find-projects({"limit": 100})`. Build lookup: `projectId → "[<Leaf Name>]"` per [[todoist-mapping]] canonical inline tag rule (leaf project/area name only, e.g. `[Easton Plus]`, `[Marriage]`, `[AskElephant]`).

## Compose rules

- **Focus (3 max)** — one per stream (Work, Projects, Home/Personal). Prioritize P0/P1. Each Focus item = one concrete task. Use `- [/]` (in-progress) for the task you're starting first; `- [ ]` for others.

- **Per-stream sections** — group by stream. Each line: `- [ ] [<tag>] <content> <!-- todoist:<id> --> [optional: deadline marker]`.

- **Inbox triage** — for stale items, propose a target project tag using the **proposed state** `[>]` (agent suggestion, awaiting affirm). Format: `- [>] <content> <!-- todoist:<id> --> → [<tag>]`. User affirms by flipping `[>]`→`[ ]` (then /sync moves it) or rejects with `[-]`.

- **Blocked/waiting** — collect tasks with label `waiting` + Project READMEs where `blocked_by` non-null. Use `- [?]` state.

- **Roll-forward (liveness + deadline gated)** — yesterday's unchecked + in-progress items are roll-forward *candidates*. Apply two gates per candidate, in order:
  1. **Liveness — drop if already done in Todoist.** A note line `[ ]`/`[/]` only reflects Obsidian state; a task completed directly in Todoist still shows unchecked in the note. If the line has a `<!-- todoist:<id> -->` comment, check live Todoist state: if `checked:true` (completed) or the ID 404s (gone), do NOT roll it forward — and reconcile the prior note's line to `[x]` so it stops resurfacing. Reuse the step 2 today+overdue capture; a candidate absent from the open-task set is presumed done — confirm with a targeted `fetch-object` before dropping. (This is the reverse-direction gap: Todoist→Obsidian completions aren't mirrored, so roll-forward must verify, not assume.)
  2. **Deadline — drop if undated.** Of the still-open candidates, carry forward **only those with a deadline**: a line deadline marker (`(deadline YYYY-MM-DD)` / `[deadline: …]`), or a non-null Todoist `deadlineDate` via the embedded ID. A due date is NOT a deadline.
  - **Open + has deadline** → append to `## Quick capture` (preserve ID comment + deadline marker).
  - **Open + no deadline** → do NOT roll forward; resurfaces via its own due/overdue query, not perpetual roll-forward.
  - **Already done/gone** → do NOT roll forward; reconcile prior note line to `[x]`.

## Canonical inline tags

Always inline at leaf level (per `Resources/conventions/todoist-mapping.md`):

```
- [ ] [Easton Plus] <task> <!-- todoist:ID -->         → Projects > Easton Plus
- [ ] [Marriage] <task> <!-- todoist:ID -->            → Areas > Home > Marriage
- [ ] [Training] <task> <!-- todoist:ID -->            → Areas > Personal > Training
- [ ] [Shopping] <task> <!-- todoist:ID -->            → Areas > Personal > Shopping
- [ ] [Goals] <task> <!-- todoist:ID -->               → Areas > Work, section Goals
- [ ] [AskElephant] <task> <!-- todoist:ID -->         → Areas > Work > Customers > AskElephant
```

Tasks from Inbox have no tag yet — surface in Inbox triage section with proposed tag.

## ID embedding

Every checkbox line sourced from Todoist MUST end with HTML comment:

```
<!-- todoist:<task-id> -->
```

Renders invisibly in Obsidian preview. Enables `/sync` to match unambiguously.

## Output

Write `Daily Notes/<YYYY-MM>/<date>.md` (month folder = first 7 chars of `<date>`; create it if absent). If file exists, back up to `Daily Notes/<YYYY-MM>/<date>.bak.md` via `mcp__obsidian__move_note` first.

Skeleton:

```markdown
---
date: <date>
generated_by: agent
tags:
  - type/daily
---

# <date>

## Calendar
- HH:MM — <event title>

## Focus (3 max)
- [/] [<tag>] <top priority task> <!-- todoist:ID -->
- [ ] [<tag>] <task> <!-- todoist:ID -->
- [ ] [<tag>] <task> <!-- todoist:ID -->

## Per-stream next actions

### Work
- [ ] [<tag>] <task> <!-- todoist:ID -->

### Projects
- [ ] [<tag>] <task> <!-- todoist:ID -->

### Home / Personal
- [ ] [<tag>] <task> <!-- todoist:ID -->

## Inbox triage (Todoist Inbox > 24h)
- [>] <task> <!-- todoist:ID --> → [<tag>]

## Quick capture
<rolled-forward items with preserved ID comments + empty for user>

## Blocked / waiting
- [?] [<tag>] <task> <!-- todoist:ID -->
```

## Log run to Supabase

After writing the Daily Note, log one `command_runs` row (`_shared/supabase-logging.md`): `command='daily-plan'`, `scope=<date>`, `status='applied'`, `applied_at=now()`. Counts = `{focus, next_actions, inbox_triage, rolled_forward}`; `applied_ops` = the planned sections summary. No proposal gate here (daily-plan writes directly), so a single applied row. Non-blocking — warn and continue if Supabase unauthed/unreachable.

## Behavior

- READ-ONLY on Todoist. No completes, no label changes.
- Write to `Daily Notes/<YYYY-MM>/<date>.md` (+ backup in same month folder).
- Calendar MCP unavailable → `> [!warning] Calendar unavailable` callout, skip Calendar section.
- Todoist MCP unavailable → same warning, still emit Project READMEs Per-stream section.
- After writing, print summary: `Daily plan written: N focus, M next-actions, K inbox triage, J rolled forward.`

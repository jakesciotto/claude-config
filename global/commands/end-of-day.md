---
description: Reconcile today's Daily Note with Todoist completions, propose project README updates
argument-hint: "[YYYY-MM-DD]"
---

You are running Jake's end-of-day reconcile for $1 (default: today).

## Context

PARA reference:
- `Resources/conventions/{para-structure,project-readme-fields,todoist-mapping}.md`
- `Resources/system-design/README.md`

## Gather

Run in parallel:

1. **Today's Daily Note** — `mcp__obsidian__read_note({"path": "Daily Notes/<date>.md"})`. Parse checked (`- [x]`) vs unchecked items per section.

2. **Todoist completed today** — `mcp__todoist__find-completed-tasks` since today 00:00 local. Capture content + projectId.

3. **All active project READMEs** — list `Projects/`, read each `<name>/README.md` frontmatter. Capture: `name`, `last_touched`, `next_action`, `blocked_by`, `status`.

## Reconcile

For each Todoist task completed today, find the matching project (via `@<project-slug>` label or projectId mapping to a Project README's `todoist_filter`):

- Propose `last_touched: <today>` update for that README.
- If the completed task content matches or supersedes the current `next_action`, propose a new `next_action` candidate from remaining `@next` tasks in that project.

For each Project with `last_touched` older than 7 days (no recent completion): flag as **neglected**.

## Output — Part 1: Append summary to today's Daily Note

Use `mcp__obsidian__patch_note` to insert at the end:

```markdown

## End-of-day reconcile

> [!info] Generated <timestamp>

**Completed today:**
- [x] <project> — <task>

**Rolled forward (uncompleted + in-progress):**
- [ ] <task>
- [/] <task>

**Project README updates proposed:**
- Projects/<name>/README.md — `next_action: "<new>"`, `last_touched: <today>`

**Neglected projects (> 7 days no touch):**
- [?] <name> — last touched <date>
```

## Output — Part 2: Wait for user confirm

Stop. Show the proposed README diffs in conversation. Ask:

> "Apply README updates? (y/N)"

If `y`: for each proposed update, use `mcp__obsidian__update_frontmatter` to patch. Confirm each write.

If `N` or blank: no-op, exit cleanly with message "No README changes applied."

## Behavior

- Do NOT mark Todoist tasks complete (user does that in Todoist).
- Do NOT auto-write README changes without confirmation.
- Read-only on Todoist apart from optional task completion confirmations.
- If Daily Note missing for `<date>`: report "No Daily Note for <date> — did you run /daily-plan?" and exit.

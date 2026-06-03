---
description: Reconcile today's completed tasks (from the vault), update project READMEs, optionally archive.
argument-hint: "[YYYY-MM-DD]"
---

You are running Jake's end-of-day reconcile for `$1` (default: today). **Offline-first — reads the vault. Todoist is not involved** (it's a capture inbox only; tasks live in Obsidian).

## Context
- Vault: `/Users/jakesciotto/Documents/Obsidian Vault` (`mcp__obsidian__*`)
- Conventions: `Resources/conventions/{para-structure,project-readme-fields,task-system}.md`
- Supabase archive: project `configs` / `jselgaytmwlstuuhrwzj`, table `archived_tasks` (`_shared/supabase-logging.md`)

## Gather

1. **Completed, not-yet-archived tasks** — scan `Areas/**/*.md` + `Projects/**/*.md` for `- [x]` lines (exclude `Templates/`, `Archives/`, `Areas/Work/Documentation/`, `Areas/Work/Scratch/`, `Projects/GTM Toolkit/csm-hud.md`). These are recent completions (pruned later by `/archive`). Parse content + inline fields (`[tier::]`, `[completion::]`); the file's path → its project.
2. **Active project READMEs** — list `Projects/`, read each `<name>/README.md` frontmatter: `name`, `status`, `last_touched`, `next_action`, `blocked_by`.

## Reconcile

For each project with a completed task today:
- Propose `last_touched: <today>`.
- If a completed task matches/supersedes the current `next_action`, propose a new `next_action` from that project's remaining open `[tier:: next]` (else `[tier:: now]`, else any open) task.

Projects with `last_touched` > 7 days and no completion → flag **neglected**.

## Output — Part 1: append summary to today's daily note

`mcp__obsidian__patch_note` to append (the daily note is a live Dataview view; this is a journal record, not a task list):

```markdown

## End-of-day reconcile
> [!info] Generated <timestamp>

**Completed today:**
- [x] <project> — <task>

**Project README updates proposed:**
- Projects/<name>/README.md — `next_action: "<new>"`, `last_touched: <today>`

**Neglected projects (> 7 days):**
- <name> — last touched <date>
```

## Output — Part 2: confirm README updates

Stop. Show proposed README diffs. Ask `Apply README updates? (y/N)`. On `y`: `mcp__obsidian__update_frontmatter` per project. On `N`/blank: no-op.

## Output — Part 3: offer to archive

Ask: `Sweep today's completed tasks to Supabase + prune from pages now? (y/N)` — on `y`, run the `/archive` flow.

## Log to Supabase

`command_runs`, `command='end-of-day'`, `scope=<date>` (`_shared/supabase-logging.md`): `proposed` at Part 2, `applied`/`vetoed` after. Non-blocking.

## Behavior
- Offline except Supabase logging + optional archive. **No Todoist.**
- The daily note is a live Dataview view — never parse it for task state; read the PARA pages.
- Never auto-write README changes without confirmation.
- If no daily note exists for `<date>`, still run the reconcile + create the note via `/daily` first (or skip the Part-1 append and report).

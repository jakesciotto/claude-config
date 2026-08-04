# Supabase run logging (shared)

Audit log for `/sync`, `/daily-plan`, `/end-of-day`, `/weekly-review`.
Table: `public.command_runs` (schema: `supabase-command-runs.sql`). One row per run, updated proposed → applied.

## Tool

Supabase MCP: `plugin:supabase:supabase`.
- Project: **`configs`** — `project_id = "jselgaytmwlstuuhrwzj"` (pass to every call).
- Insert/update via `mcp__plugin_supabase_supabase__execute_sql`. DDL/table-create via `mcp__plugin_supabase_supabase__apply_migration` (migration `command_runs` already applied 2026-05-29).

If the server shows `! Needs authentication` in `claude mcp list`, prompt the user to run `/mcp` → authenticate before logging. Never block the command on logging — if Supabase is unreachable, finish the command and warn.

## When

1. **At proposal** (after building the diff, before "Apply?"): insert one row, `status='proposed'`, fill `proposed_counts` + `proposed_ops`. Keep the returned `id`.
2. **At apply** (after writes succeed): update that row → `status='applied'`, `applied_at=now()`, fill `applied_counts` + `applied_ops`.
3. **If vetoed** (user answers N): update row → `status='vetoed'`. Leave `applied_*` null.

Dry-run-only invocations stop at step 1 (row stays `proposed`).

## Insert (proposal)

```sql
insert into public.command_runs
  (command, scope, run_date, status, proposed_counts, proposed_ops, notes)
values
  ($command, $scope, $run_date, 'proposed', $proposed_counts::jsonb, $proposed_ops::jsonb, $notes)
returning id;
```

## Update (apply / veto)

```sql
update public.command_runs
set status = $status,                 -- 'applied' | 'vetoed'
    applied_at = case when $status = 'applied' then now() else null end,
    applied_counts = $applied_counts::jsonb,
    applied_ops = $applied_ops::jsonb
where id = $id;
```

## Counts keys

For `/sync`: `creates, homings, moves, edits, completes, note_completes, deletes, gone`. For `/daily-plan`: `today, overdue, backlog, new_appended`. Omit zeros if desired.

## Op shape (proposed_ops / applied_ops)

```json
{ "type": "create|home|move-project|set-due|set-deadline|set-labels|update-content|complete|note-complete|delete|gone",
  "id": "<todoist id|null>", "content": "...", "target": "<project path|null>",
  "file": "Daily Notes/2026-05/2026-05-29.md", "line": 71 }
```

## Completed-task mirror — `public.archived_tasks`

Full mirror of Todoist completions, written by `/sync` (its final step). One row per task (`todoist_id` PK); recurring tasks collapse to latest with a `completion_count`. Same project (`configs` / `jselgaytmwlstuuhrwzj`).

```sql
insert into public.archived_tasks
  (todoist_id, content, project, priority, recurring, labels, completed_at, completed_date, last_source, last_run_id)
values ($id, $content, $project, $priority, $recurring, $labels::jsonb, $completed_at, $completed_date, 'sync', $run_id)
on conflict (todoist_id) do update set
  completed_at     = excluded.completed_at,
  completed_date   = excluded.completed_date,
  completion_count = public.archived_tasks.completion_count
    + (case when excluded.completed_at > public.archived_tasks.completed_at then 1 else 0 end),
  last_source = excluded.last_source,
  last_run_id = excluded.last_run_id,
  updated_at  = now();
```

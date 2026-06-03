---
description: Sweep completed Obsidian tasks into Supabase archived_tasks (one-way), then prune them from pages.
argument-hint: "[since YYYY-MM-DD]"
---

You are archiving Jake's completed tasks. **One-way: Obsidian → Supabase. Write-only; cannot drift.**

## Context
- Vault: `/Users/jakesciotto/Documents/Obsidian Vault` (`mcp__obsidian__*`)
- Supabase: project `configs` / `jselgaytmwlstuuhrwzj`, table `public.archived_tasks` (`_shared/supabase-logging.md`)
- Scope of scan: `Areas/**/*.md`, `Projects/**/*.md` (excl. `Templates/`, `Archives/`, `Meeting Notes/`). Window: since `$1` (default: since the previous `command='archive'` run, else last 7 days).

## Steps

1. **Find completed tasks:** scan scoped files for lines matching `^- \[x\] `. Parse content + inline fields (`[due::]`, `[deadline::]`, `[tier::]`, `[completion::]`).
2. **Upsert to Supabase** `public.archived_tasks` — key on a stable hash of `(file path + content)` (no Todoist id in this system). Store: content, project (derive from file path), tier, due, deadline, completed_date (`[completion::]` or today), source `obsidian`. Recurring n/a.
3. **Prune:** remove the archived `[x]` lines from their pages (`mcp__obsidian__patch_note`). Git retains history. Leave open tasks untouched.
4. **Report:** `Archived N completed task(s) to Supabase; pruned from M page(s).`
5. **Log** (`_shared/supabase-logging.md`): `command='archive'`, `status='applied'`, `applied_counts={archived:N}`. Non-blocking.

## Behavior
- DRY-RUN default — list what will be archived/pruned, ask `Apply? (y/N)` before writing.
- Never deletes open tasks. Only `[x]` lines are swept.
- If Supabase unavailable: report and stop (don't prune without a successful archive).

-- Migration: command_runs
-- Audit log for agent commands (/sync, /daily-plan, /end-of-day, /weekly-review).
-- One row per run. Captures the dry-run proposal AND the applied result.
-- Apply via: mcp supabase apply_migration (name: "command_runs")

create table if not exists public.command_runs (
  id              uuid primary key default gen_random_uuid(),
  command         text not null check (command in ('sync','daily-plan','end-of-day','weekly-review')),
  scope           text,                          -- e.g. 'today', '2026-05-29', explicit path
  run_date        date not null,                 -- logical date of the run (note date)

  status          text not null default 'proposed'
                    check (status in ('proposed','applied','vetoed')),

  proposed_at     timestamptz not null default now(),
  applied_at      timestamptz,                   -- null until applied; stays null if vetoed/dry-run

  -- Counts keyed by op type, e.g. {"creates":1,"completes":0,"moves":8,"updates":0,
  --   "labels":0,"deletes":0,"conflicts":4,"gone":0,"noops":27}
  proposed_counts jsonb not null default '{}'::jsonb,
  applied_counts  jsonb,

  -- Full staged op list and the subset actually applied.
  proposed_ops    jsonb not null default '[]'::jsonb,
  applied_ops     jsonb,

  notes           text
);

create index if not exists command_runs_command_run_date_idx
  on public.command_runs (command, run_date desc);
create index if not exists command_runs_status_idx
  on public.command_runs (status);

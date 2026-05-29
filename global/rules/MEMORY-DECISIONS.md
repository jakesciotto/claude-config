# MEMORY-DECISIONS.md

Dated log of decisions made during sessions. Each entry documents a choice with enough context to understand why it was made.

Format: `### YYYY-MM-DD — Decision title` followed by a brief description.

---

<!-- Add entries below as decisions are made -->

### 2026-05-29 — Archive completed tasks to Supabase (`archived_tasks`)
`/sync` mirrors Todoist completions into `public.archived_tasks` (project `configs`/`jselgaytmwlstuuhrwzj`). Full mirror (every completed Todoist task, any source), one row per `todoist_id` (PK); recurring tasks collapse to latest with `completion_count` incremented when a newer completion lands. FK `last_run_id → command_runs.id`. Backfilled 28 recent completions. Mirror is Step 12 of /sync, non-blocking, runs regardless of apply/veto. Window = since previous sync run's run_date (default last 7 days). Schema + upsert in `_shared/supabase-logging.md`.

### 2026-05-29 — Daily Notes foldered by month
Daily Notes now live in `Daily Notes/<YYYY-MM>/<YYYY-MM-DD>.md` (mirrors Meeting Notes layout), to avoid a flat dir as notes cross months. Migrated all 20 existing files (incl. `.bak.md`) into `2026-04/` and `2026-05/`. Updated path refs in all 4 commands (`/daily-plan`, `/end-of-day`, `/sync`, `/weekly-review`), `_shared/supabase-logging.md`, and vault conventions (`para-structure.md`, `agent-commands-usage.md`, `todoist-mapping.md`). Commands compute month folder = first 7 chars of date; roll-forward/last-7 windows may span two folders near a month boundary. Obsidian resolves `[[links]]` by filename so the move doesn't break links.

### 2026-05-29 — `[>]` proposed-state checkbox for agent suggestions
New Things-theme checkbox state `[>]` = "agent-proposed categorization/move, awaiting affirmation." Replaces the `→ suggest: [Tag]` text keyword. Lifecycle: `/daily-plan` writes Inbox-triage suggestions as `- [>] <task> <!--id--> → [Tag]`; `/sync` holds `[>]` (never writes to Todoist, surfaces under "Suggested (awaiting affirm)"). User affirms by flipping `[>]`→`[ ]` (same-run: /sync moves the Todoist task out of Inbox to the tagged project, rewrites note line to `→ moved: [Tag]`, logs `suggested:true, affirmed:true`); rejects with `[-]` (stays in Inbox, `affirmed:false`). Only open `[ ]` tagged lines auto-move — this gates the earlier blanket auto-move rule. Things theme supports these glyphs: `< > b c d D f i I k l M p P S u w X` (+ base ` / x - ? ! *`). Confirmed via `.obsidian/themes/Things/theme.css`.

### 2026-05-29 — Log command runs to Supabase
All four PARA commands (`/sync`, `/daily-plan`, `/end-of-day`, `/weekly-review`) write an audit row to Supabase table `public.command_runs`. Grain: one row per run, updated proposed→applied (status enum: proposed/applied/vetoed); captures both the dry-run proposal and the applied result. Schema + migration: `global/commands/_shared/supabase-command-runs.sql`. Shared logging convention: `global/commands/_shared/supabase-logging.md`. Logging is non-blocking. Supabase MCP is `plugin:supabase:supabase` (HTTP). Table created 2026-05-29 in project `configs` (`project_id=jselgaytmwlstuuhrwzj`) via `apply_migration`; calls use `mcp__plugin_supabase_supabase__execute_sql` with that project_id. First /sync run backfilled (row `6d5e43fa-da56-4de7-960f-eef66a14afc3`).

### 2026-05-29 — /sync behavior extensions (new daily-note template)
Three new rules, baked into `global/commands/sync.md`: (1) `[*]` star checkbox → `add-label: star`; (2) tagged items sitting in Todoist Inbox auto-move to mapped project via `update-tasks` projectId (the `project-move` tool only moves projects workspace↔personal, NOT tasks); (3) /sync now reconciles deadline/due date edits in the note, not just completes/creates. Also: dedupe tasks by Todoist ID across Focus/triage/per-stream sections; triage section routes via trailing `→ suggest: [Tag]`.

### 2026-05-14 — Switch from Codespaces to Flox for PostHog local dev
Codespaces too slow/laggy. Flox local chosen: `manifest.toml`-declared deps, `uv sync` for Python, `pnpm` for JS. Run `flox activate` per shell, then `hogli start`. Requires Docker/OrbStack with 8 GB RAM + 4 CPUs.
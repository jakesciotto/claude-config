# memory-decisions.md

Dated log of decisions made during sessions. Each entry documents a choice with enough context to understand why it was made.

Format: `### YYYY-MM-DD — Decision title` followed by a brief description.

### 2026-06-16 — Session summaries auto-logged to Supabase via SessionEnd hook
SessionEnd hook (`global/settings.json`) runs `~/.claude/hooks/session-summary.sh` (symlinked from `template/.claude/hooks/`). Script forks to background, flattens transcript.jsonl, summarizes via headless `claude -p --model claude-sonnet-4-6`, upserts to `configs` project (jselgaytmwlstuuhrwzj) table `public.claude_sessions` via PostgREST. Secret in `~/.claude/hooks/.session-summary.env` (chmod 600, NOT in git). Table RLS-on with no policies (service_role bypasses). Log at `~/.claude/hooks/session-summary.log`.

### 2026-06-10 — Obsidian workflow reduced to /capture only
Moved archive, daily, daily-plan, end-of-day, sync, weekly-review from `global/commands/` to `global/commands/deprecated/`. Only /capture remains active. `_shared/` kept in place since capture.md references it. Note: files in `deprecated/` still register as namespaced commands (`/deprecated:archive` etc.); delete the folder if they should disappear entirely.
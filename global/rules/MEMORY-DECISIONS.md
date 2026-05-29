# MEMORY-DECISIONS.md

Dated log of decisions made during sessions. Each entry documents a choice with enough context to understand why it was made.

Format: `### YYYY-MM-DD — Decision title` followed by a brief description.

---

<!-- Add entries below as decisions are made -->

### 2026-05-29 — /sync behavior extensions (new daily-note template)
Three new rules, baked into `global/commands/sync.md`: (1) `[*]` star checkbox → `add-label: star`; (2) tagged items sitting in Todoist Inbox auto-move to mapped project via `update-tasks` projectId (the `project-move` tool only moves projects workspace↔personal, NOT tasks); (3) /sync now reconciles deadline/due date edits in the note, not just completes/creates. Also: dedupe tasks by Todoist ID across Focus/triage/per-stream sections; triage section routes via trailing `→ suggest: [Tag]`.

### 2026-05-14 — Switch from Codespaces to Flox for PostHog local dev
Codespaces too slow/laggy. Flox local chosen: `manifest.toml`-declared deps, `uv sync` for Python, `pnpm` for JS. Run `flox activate` per shell, then `hogli start`. Requires Docker/OrbStack with 8 GB RAM + 4 CPUs.
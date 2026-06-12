# memory-decisions.md

Dated log of decisions made during sessions. Each entry documents a choice with enough context to understand why it was made.

Format: `### YYYY-MM-DD — Decision title` followed by a brief description.

### 2026-06-10 — Obsidian workflow reduced to /capture only
Moved archive, daily, daily-plan, end-of-day, sync, weekly-review from `global/commands/` to `global/commands/deprecated/`. Only /capture remains active. `_shared/` kept in place since capture.md references it. Note: files in `deprecated/` still register as namespaced commands (`/deprecated:archive` etc.); delete the folder if they should disappear entirely.
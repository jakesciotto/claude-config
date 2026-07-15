# memory-decisions.md

Dated log of decisions made during sessions. Each entry documents a choice with enough context to understand why it was made.

Format: `### YYYY-MM-DD — Decision title` followed by a brief description.

### 2026-07-15 — ff-pitfall-scan skill created
New skill at `posthog/ff-pitfall-scan/` — gitignored folder for PostHog-internal material (internal table names stay out of git; folder created same day) — symlinked into `~/.claude/skills/`. Hypothesizes feature-flag instrumentation pitfalls for an account from CSM-visible signals only. Design choices: hypotheses + customer-ready asks (not report-only), quantitative signals + cross-team flag metadata (no Slack/Vitally sweep), signature catalog + open reasoning pass, personal skill with hp dependency (Vitally fallback). 8-signature catalog in `references/signatures.md`, validated SQL in `references/queries.md` (key finding: `billing_usagereport.report` exposes `decide_requests` vs `local_evaluation_requests` split; `postgres_posthog_featureflag` + `postgres_posthog_team` give cross-team flag inventory incl. `evaluation_runtime`). Not committed yet.

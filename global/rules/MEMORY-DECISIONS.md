# MEMORY-DECISIONS.md

Dated log of decisions made during sessions. Each entry documents a choice with enough context to understand why it was made.

Format: `### YYYY-MM-DD — Decision title` followed by a brief description.

---

<!-- Add entries below as decisions are made -->

### 2026-05-14 — Switch from Codespaces to Flox for PostHog local dev
Codespaces too slow/laggy. Flox local chosen: `manifest.toml`-declared deps, `uv sync` for Python, `pnpm` for JS. Run `flox activate` per shell, then `hogli start`. Requires Docker/OrbStack with 8 GB RAM + 4 CPUs.
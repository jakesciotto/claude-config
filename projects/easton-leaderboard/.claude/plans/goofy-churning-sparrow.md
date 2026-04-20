# Plan: P1 Bundle, Rendering, Security, and Weight Class Fixes

## Context

8 P1 items from TODO.md. All independent, no DB migrations. Ordered low-risk to high-risk.

## Phase 1 -- Trivial (parallel)

### 1. Remove tbody key -- `components/leaderboard-table.jsx`
Remove `key={...}` from `<tbody>`. Rows already keyed by `competitor.id`.

### 2. Font display swap -- `app/layout.jsx`
Add `display: "swap"` to both `Geist()` and `Geist_Mono()` calls. Variable fonts don't need weight constraints.

### 3. React.memo on leaf components
Wrap exports with `memo()` in: `belt-badge.jsx`, `result-badge.jsx`, `stat-card.jsx`, `podium.jsx` (+ inner `PodiumCard`), `nav.jsx`.

## Phase 2 -- Dynamic imports (parallel)

### 4. Lazy-load Recharts -- `app/competitor/[id]/page.jsx`
Replace static imports of `CompetitorRadar` and `MatchTimeline` with `next/dynamic`, `ssr: false`, skeleton loading fallbacks.

### 5. Dynamic import MobileFilterSheet -- `components/filter-bar.jsx`
Replace static import with `next/dynamic`, `ssr: false`. No loading fallback needed (drawer transition covers it).

### 6. Defer PostHog -- new `components/posthog-provider.jsx` + `app/layout.jsx`
Create `AnalyticsProvider` wrapper that dynamic-imports `PostHogProvider` and `PostHogPageView` with `ssr: false`. Replace direct imports in layout.

## Phase 3 -- Security headers (sequential)

### 7. Security headers -- `next.config.mjs`
Add `async headers()` with: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-DNS-Prefetch-Control: on`, `Strict-Transport-Security`, and CSP allowing self + PostHog connect + unsafe-inline for styles/scripts.

## Phase 4 -- Weight class Unknown (sequential)

### 8. Weight class "Unknown" -- `dashboard.jsx`, `filter-bar.jsx`, `mobile-filter-sheet.jsx`, `competitor/[id]/page.jsx`
- In `dashboard.jsx` weightClasses useMemo: append `"__unknown__"` sentinel when entries have null weightClass
- In filter logic: when `filters.weight === "__unknown__"`, filter to `!e.weightClass`
- In both filter dropdowns: render `"Unknown"` label for `"__unknown__"` value
- On competitor profile: always render weight badge, show `"Unknown"` when null

## Verification

`npm run build` after each phase. Manual check: leaderboard renders, profile charts load, filters work, console clean, response headers include security headers.

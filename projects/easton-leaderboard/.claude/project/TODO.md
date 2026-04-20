# TODO.md

Open work items only. Design rationale and resolved items archived in `.claude/plans/archive/2026-04-01-technical-analysis.md`.

---

## Priority Matrix

| Item                                                         | Impact | Effort | Priority      |
| ------------------------------------------------------------ | ------ | ------ | ------------- |
| ~~Data layer algorithmic fixes~~                             | High   | Low    | Done (v0.5.1) |
| ~~Stale sheets.js cache (correctness bug)~~                  | High   | Low    | Done (v0.5.1) |
| ~~Supabase read client key precedence~~                      | Medium | Low    | Done (v0.5.1) |
| ~~Bundle optimization (Recharts, fonts, PostHog)~~           | Medium | Low    | Done (v0.5.2) |
| ~~Data layer pre-computation (ranks, peers, parseDivision)~~ | High   | Medium | Done (v0.5.2) |
| Weight class bucketing (remaining)                           | High   | Medium | P1            |
| ~~React rendering fixes (tbody key, memo)~~                  | Medium | Low    | Done (v0.5.2) |
| ~~Security headers + infrastructure~~                        | Medium | Low    | Done (v0.5.2) |
| ~~Point system + ERP~~ (core)                                | High   | High   | Done (v0.7.0) |
| ~~2023 data exclusion from rankings~~                        | High   | Low    | Done (v0.8.0) |
| ~~Competitor merge (school transfers)~~                      | High   | Medium | Done (v0.8.0) |
| ~~Search bar~~                                               | Medium | Low    | Done (v0.8.0) |
| Orphaned competitor cleanup (FK constraint bug)              | High   | Low    | P0            |
| Mobile card layout for leaderboard                           | Medium | Medium | P2            |
| Mobile stats grid redesign                                   | Medium | Medium | P2            |
| ~~Admin UI + Auth~~                                          | High   | High   | Done (v0.9.0) |
| Chart mobile optimizations                                   | Medium | Low    | P3            |
| Compact podium on mobile                                     | Low    | Medium | P3            |
| Opponent quality tracking                                    | Medium | High   | P3            |
| Data quality at scale                                        | Medium | High   | P3            |

---

## 1. Performance -- Data Layer

- [x] **Fix O(n^2) rank computation in `computePreviousRanks()`** -- `lib/data/index.js` (v0.5.1)
- [x] **Move `parseDivision()` from fetch path to sync path** -- `lib/data/index.js`, `app/api/sync/route.js` (v0.5.2)
  - Persists `weight_class` to entries table during sync. Removed `parseDivision()` call from `mapEntry()`.
  - Migration: `supabase/migrations/003_entries_weight_class.sql`
- [x] **Fix stale module-scoped cache in `sheets.js`** -- `lib/data/sheets.js` (v0.5.1)
- [x] **Single-pass `buildStatsMap()`** -- `lib/stats.js` (v0.5.1)
- [x] **Memoize Google Auth object** -- `lib/data/sheets.js` (v0.5.1)
- [x] **Fix Supabase read client key precedence** -- `lib/supabase.js` (v0.5.1)

- [x] **Pre-compute peer averages** by `{ageGroup}|{belt}` bucket during sync (v0.5.2)
  - Migration: `supabase/migrations/005_peer_averages.sql`
- [x] **Pre-compute rankings** (`rankOrder` field on competitor) during sync (v0.5.2)
  - Migration: `supabase/migrations/004_competitors_rank_order.sql`
- [x] **Monitor memory usage** on cold start (`process.memoryUsage().heapUsed`) (v0.5.2)

---

## 2. Performance -- Bundle & Loading

- [x] **Lazy-load Recharts via `next/dynamic`** -- `app/competitor/[id]/page.jsx` (v0.5.2)
  - ~300KB removed from initial profile page bundle. Dynamic import with loading placeholders.

- [x] **Exclude `googleapis` from client bundle** -- `next.config.mjs` (v0.5.2)
  - Added `serverExternalPackages: ["googleapis"]`. ~2-3MB excluded from client bundles.

- [x] **Constrain font weights** -- `app/layout.jsx` (v0.5.2)
  - Geist: 400-800. Geist_Mono: 400-500. Added `display: 'swap'`.

- [x] **Dynamic import `MobileFilterSheet`** -- `components/filter-bar.jsx` (v0.5.2)
  - Mobile-only component no longer downloaded on desktop.

- [x] **Defer PostHog initialization** -- `app/layout.jsx`, `components/posthog-wrapper.jsx` (v0.5.2)
  - Custom wrapper lazily imports `posthog-js` in `useEffect` after hydration.

---

## 3. Performance -- React Rendering

- [x] **Remove `tbody` key anti-pattern** -- `components/leaderboard-table.jsx` (v0.5.2)
  - Removed composite key that forced full unmount/remount on sort/page change.

- [x] **Add `React.memo()` to leaf components** -- `belt-badge.jsx`, `result-badge.jsx`, `stat-card.jsx`, `podium.jsx` (v0.5.2)

- [x] **Memoize chart data computations** -- `competitor-radar.jsx`, `match-timeline.jsx` (v0.5.2)
  - Wrapped `buildRadarData()` and timeline transforms in `useMemo`.

- [x] **Deduplicate `<Cell>` mapping in match timeline** -- `components/match-timeline.jsx` (v0.5.2)
  - Cell colors pre-computed once in `useMemo`, shared by both `<Bar>` components.

- [x] **Conditionally render activity feed entries** -- `components/activity-feed.jsx` (v0.5.2)
  - Entries only mount in DOM when feed is expanded.

---

## 4. Security & Infrastructure

- [x] **Add security headers via proxy** -- `proxy.js` (v0.5.2)
  - `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`. PostHog proxy moved to `next.config.mjs` rewrites.

- [x] **Static asset caching** -- handled by Next.js (v0.5.2)
  - Next.js already sets optimal `Cache-Control` for `_next/static` assets. Custom headers removed after warning.

- [x] **Add meaningful Suspense fallbacks** -- `app/competitor/[id]/page.jsx` (v0.5.2)
  - Replaced `fallback={null}` with `ProfileSkeleton` component (header, stats grid, chart placeholders).

- [x] **Add Supabase indexes** -- `supabase/migrations/006_entries_indexes.sql` (v0.5.2)
  - Indexes on `entries.competitor_id`, `entries.date`, `entries.competition_id`.

- [x] **Add try-catch around Sheets auth initialization** -- `lib/data/sheets.js` (v0.5.2)
- [x] **Validate env vars at startup** -- `lib/env.js` (v0.5.2)
- [ ] **Verify IAM scope** -- service account restricted to specific spreadsheets only
- [ ] **Document security model in ARCHITECTURE.md** -- React JSX auto-escaping, no raw HTML insertion
- [x] **Validate override fields before applying** -- `lib/data/index.js` (v0.5.2)
  - Allowlist: belt, age_division, age_group, gender, weight_class

---

## 5. Weight Class Bucketing (remaining)

Core work shipped in v0.5.0. See `.claude/plans/archive/2026-04-01-technical-analysis.md` for full design.

- [ ] Handle the "no weight" case -- show "Unknown" in the UI
- [ ] Test with real data across IBJJF names, pound ranges, NAGA numeric, F2W compact, AGF suffixed

---

## 6. Scoring Algorithm (remaining)

Core point system and percentile-based ERP shipped in v0.7.0. See `lib/points.js` for implementation.

- [x] Implement point formula: `(gold*9 + silver*3 + bronze*1) * eventMultiplier * yearMultiplier` (v0.7.0)
- [x] Implement percentile-based ERP with 4-metric composite and 3-entry minimum (v0.7.0)
- [x] Change ranking sort from wins to total points (v0.7.0)
- [ ] Add bracket size tracking to the data model
- [ ] Add "New" badge for competitors with fewer than 3 entries (unrated ERP)
- [ ] Implement belt transition decay for kids who promote between belt ranks
- [ ] Tune ERP metric weights based on real data analysis
- [ ] Consider adding bracket size / opponent quality as a 5th ERP metric

---

## 7. Mobile Experience

See `.claude/plans/archive/2026-04-01-technical-analysis.md` for detailed analysis and mockups.

### Leaderboard Table

- [ ] Switch to card layout on mobile (full-width two-line cards)
- [ ] Alternative: horizontal scroll with frozen Rank/Name columns
- [ ] Reduce padding on mobile (`px-2 py-2`)

### Competitor Profile Stats Grid

- [ ] Prioritize top 4-5 stats on mobile with "All Stats" expansion toggle
- [ ] Use 2-column layout with larger cards for key stats

### Chart Readability

- [ ] Reduce radar chart size on mobile (`h-[250px] sm:h-[300px]`)
- [ ] Abbreviate radar axis labels on mobile
- [ ] Make match timeline horizontally scrollable on mobile

### Podium Cards

- [ ] Compact horizontal 3-card layout on mobile

### General

- [ ] Test touch targets are at least 44x44px per Apple HIG / WCAG
- [ ] Add swipe-to-navigate on competitor profiles

---

## 8. Admin UI & Auth

### Auth (Done -- v0.9.0)

- [x] Install `@supabase/ssr` for cookie-aware auth clients
- [x] Create `lib/supabase-auth.js` -- server-only: `createServerAuthClient()`, `getAuthUser()` with `@eastontc.com` domain check
- [x] Create `lib/supabase-auth-client.js` -- browser-safe: `createBrowserAuthClient()` singleton
- [x] Integrate session refresh into `proxy.js` for `/admin` and `/auth` routes
- [x] Create `app/auth/callback/route.js` -- OAuth code exchange
- [x] Create `components/admin-login.jsx` -- Google sign-in button
- [x] Server-side auth gate in `app/admin/page.jsx`
- [x] `requireAdmin()` guard on `saveOverride` and `triggerSync` server actions
- [x] Remove client-side hostname check from `components/admin-panel.jsx`; add sign-out button
- [x] Auth-aware nav via `onAuthStateChange` listener in `components/nav.jsx`

### Belt Override UI (Done -- pre-v0.9.0)

- [x] `app/admin/page.jsx` -- admin page with competitor search and belt editing
- [x] `components/admin-panel.jsx` -- search, select, change belt, save override

### Remaining Admin Work

- [ ] Create `lib/sync.js` -- extract sync logic from route into shared function
- [ ] Create `sync_logs` table migration
- [ ] `app/admin/competitions/page.jsx` -- manage sync sources
- [ ] `app/admin/sync/page.jsx` -- sync history + manual trigger
- [ ] `app/admin/health/page.jsx` -- data health dashboard

---

## 9. Data Quality at Scale

- [x] ~~Duplicate detection~~ -- competitor ID changed from name+academy to name-only, merging school transfers automatically (v0.8.0)
- [ ] **Bug: orphaned competitor cleanup blocked by FK constraint** -- old academy-suffixed competitor records survive the sync cleanup step, likely due to `overrides` table foreign key references. Need to cascade-delete or detach overrides before deleting orphaned competitors. Visible as duplicate zero-stat entries on the leaderboard.
- [ ] Parse failure tracking (`parse_failures` table, transform validation, sync integration)
- [ ] Data health dashboard (`app/admin/health/page.jsx`)

---

## Point System

- [x] Medal Points: [Gold: 9, Silver: 3, Bronze: 1] (v0.7.0)
- [x] Tournament Multipliers: [Easton Open or Solid Series: 3, Fight 2 Win / F2W: 2, NAGA: 2, everything else: 1] (v0.7.0)
- [x] Year multiplier: [Current year: 3, previous year: 2, two years ago: 1] (v0.7.0)
- [x] Calculate per tournament and add for total (v0.7.0)
- [x] Include Pts and ERP columns in leaderboard table (v0.7.0)
- [x] Change ranking algorithm to sort by total points primarily (v0.7.0)
- [x] Display points and ERP prominently on competitor profile page (v0.7.0)
- [x] Per-entry Pts column in competitor profile Competition History table (v0.7.0)
- [x] ERP v1: linear normalization 1.0-10.0, recomputed on filter change (v0.7.0)
- [x] **ERP v2: percentile-based composite** -- replaced linear normalization with 4-metric percentile average (points-per-entry, win rate, podium rate, total points) for cross-academy comparability (v0.7.0)
- [x] Minimum entry threshold: 3+ entries required for rated ERP, unrated competitors show "--" in table and "Unrated" on profile (v0.7.0)
- [x] ERP tooltip on column header explaining the formula (v0.7.0)
- [x] Points and ERP displayed on podium tiles (v0.7.0)
- [ ] Tune ERP metric weights (currently equal 25% each) based on real data analysis
- [ ] Consider adding bracket size / opponent quality as a 5th ERP metric

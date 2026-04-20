# CHANGELOG.md

All notable changes to this project will be documented in this file.

---

## [0.9.0] -- 2026-04-20

### Added

- **Supabase Auth with Google OAuth** -- real authentication for admin routes, replacing the client-side `window.location.hostname` check
- `lib/supabase-auth.js` -- server-only auth helpers: `createServerAuthClient()` (cookie-aware, request-scoped) and `getAuthUser()` (validates JWT + rejects non-`@eastontc.com` emails)
- `lib/supabase-auth-client.js` -- browser-safe singleton client (`createBrowserAuthClient()`) for OAuth initiation, sign-out, and auth state listening
- `app/auth/callback/route.js` -- OAuth code exchange route; redirects to `/admin` on success, `/admin?auth_error=1` on failure
- `components/admin-login.jsx` -- "Sign in with Google" button with `hd: "eastontc.com"` hint to pre-filter Google account picker
- Server-side auth gate in `app/admin/page.jsx` -- calls `getAuthUser()` and renders `<AdminLogin />` when unauthenticated
- `requireAdmin()` guard in `app/actions.js` -- both `saveOverride` and `triggerSync` server actions reject unauthenticated callers
- Sign-out button with user email display in admin panel header
- Auth-aware nav -- Shield icon and sync button only appear when user has a valid `@eastontc.com` Supabase session

### Changed

- `proxy.js` -- integrated Supabase session cookie refresh for `/admin` and `/auth` routes (no separate `middleware.js`; Next.js 16 only supports `proxy.js`)
- `components/admin-panel.jsx` -- removed client-side `isAdmin` hostname check and "Not authorized" fallback; accepts `user` prop from server
- `components/nav.jsx` -- replaced `window.location.hostname` + `localStorage` checks with `supabase.auth.getUser()` + `onAuthStateChange` listener (uses async effect ignore flag pattern)

### Dependencies

- Added `@supabase/ssr` for cookie-aware Supabase client factories in Next.js server components, server actions, and proxy

### Deployment Notes

- **Before deploying**: complete these manual steps in order:
  1. Google Cloud Console: create OAuth 2.0 Client ID (Web Application) with redirect URI `https://jmangbmqxjjxyhlbdfto.supabase.co/auth/v1/callback`
  2. Supabase Dashboard > Authentication > Providers > Google: enable Google provider, paste Client ID and Secret
  3. Supabase Dashboard > Authentication > URL Configuration: set Site URL to production domain; add `http://localhost:3000/auth/callback` and production `/auth/callback` to Redirect URLs allowlist

---

## [0.8.0] -- 2026-04-14

### Added

- **Ranking cutoff** -- entries before 2024 are display-only: visible in competition history, round results, and timelines, but excluded from all stats, points, and ERP calculations. `RANKING_CUTOFF_YEAR` constant and `isRankingEligible()` helper in `lib/points.js`.
- **Profile page: Ranked Stats vs All-Time Stats** -- profile pages now show a "Ranked Stats" section (2024+ data, drives ERP and rankings) and an "All-Time Stats" section (shown only when pre-cutoff entries exist) using the same 9-metric StatCard layout.
- **Search bar** on the main leaderboard page -- text input with Search icon filters competitors by name (case-insensitive substring match), synced to URL via `?q=` param, cleared alongside other filters.
- `date` field added to client-side `entryIndex` payload for ranking cutoff filtering.

### Changed

- **Competitor deduplication**: ID scheme changed from `kebab-case(name + academy)` to `kebab-case(name)`. Competitors who transfer academies are now merged into a single record with their most recent school. Sync route includes orphaned competitor cleanup for old academy-suffixed records.
- **Old profile URL fallback**: `getCompetitorById()` and `getEntriesByCompetitor()` fall back to prefix matching when an exact ID is not found, so bookmarks like `/competitor/vesper-ortega-arvada` resolve to the merged `vesper-ortega` record.
- `lib/data/index.js` -- `getEnrichedLeaderboard()` filters entries to ranking-eligible (2024+) before building stats and ERP; `computePreviousRanks()` uses ranking-eligible entries only.
- `app/api/sync/route.js` -- ranking computation and peer averages use ranking-eligible entries only; orphaned competitor cleanup runs after all upserts.
- `components/dashboard.jsx` -- client-side stat recomputation excludes pre-cutoff entries; search state managed alongside filter state with URL sync.

---

## [0.7.0] -- 2026-04-12

### Added

- `lib/points.js` -- point system and ERP calculation module with five exports:
  - `getYearMultiplier(entryDate, referenceDate)` -- returns 3/2/1/0 based on year diff from reference
  - `computeEntryPoints(entry, eventMultiplier, yearMultiplier)` -- formula: `(gold*9 + silver*3 + bronze*1) * eventMultiplier * yearMultiplier`
  - `computeERPScores(competitors)` -- percentile-based composite ERP across 4 metrics (points-per-entry, win rate, podium rate, total points), returns Map of id->score; minimum 3 entries to qualify
  - `compareByPoints(a, b)` -- comparator: totalPoints desc, wins desc, winRate desc
- Pts column (purple-400, hidden on mobile) and ERP column (blue-400, visible on mobile) in leaderboard table after Belt column
- ERP column header tooltip (`?` indicator) with formula explanation on hover
- Points and ERP displayed prominently in competitor profile header card as two side-by-side tinted cards (purple for points, blue for ERP) with 3xl bold mono numbers
- Per-entry Pts column in competitor profile Competition History table (hidden on mobile)
- Points (purple) and ERP (blue) displayed on podium tiles with vertical divider, above win rate
- `points` field included in client-side entry index payload for filter recomputation
- Unrated state for competitors below 3-entry minimum: "Unrated" text on profile, "--" in table column

### Changed

- **Ranking algorithm**: primary sort changed from total wins to total points across the entire system:
  - `lib/data/index.js` -- `getEnrichedLeaderboard()` attaches `entry.points` before building stats, computes percentile-based ERP via `computeERPScores()`, sorts by `compareByPoints`; `computePreviousRanks()` accumulates `totalPoints` for accurate rank change indicators
  - `app/api/sync/route.js` -- `mappedEntries` get `entry.points` attached; `computeRankings()` sorts by `compareByPoints`; previous rank computation includes `totalPoints`
  - `components/dashboard.jsx` -- ERP recomputed via `computeERPScores()` relative to filtered set on every filter change; filtered results sorted by points; `totalPoints` and `erp` passed through to podium and table data
  - `components/leaderboard-table.jsx` -- default sort column changed from `wins` to `totalPoints`; COLUMNS array supports optional `tooltip` field rendered as `title` attribute with `?` indicator
- `lib/stats.js` -- `totalPoints` accumulator added to both `computeStatsFromEntries()` (zero-entries case, loop, return) and `buildStatsMap()` (accumulator init, loop, finalized stats)
- `components/podium.jsx` -- PodiumCard now renders points and ERP between medals and win rate sections
- Removed duplicate `compareByWins` functions from `lib/data/index.js` and `app/api/sync/route.js` in favor of shared `compareByPoints` from `lib/points.js`

---

## [0.6.0] -- 2026-04-11

### Added

- Google Sheets directory integration -- a master directory sheet (`GOOGLE_DIRECTORY_SHEET_ID`) now drives competition discovery instead of hardcoded `GOOGLE_SHEET_IDS` env var
- `lib/data/sheets.js` -- `fetchDirectoryEntries()` reads the directory sheet and extracts sheet IDs, event metadata, and multipliers from each row
- `lib/data/sheets.js` -- `resolveResultsTab()` dynamically resolves the correct tab name per sheet (tries "Results", then "All Results", then first tab)
- `lib/data/sheets.js` -- dynamic header row detection scans for "Academy" in column A instead of hardcoding row 67
- `lib/data/sheets.js` -- `normalizeDirectoryDate()` export for M/D/YY to ISO date conversion
- `supabase/migrations/007_competitions_multipliers.sql` -- `event_multiplier` and `year_multiplier` columns on competitions table
- `app/api/sync/route.js` -- `discoverFromDirectory()` function with three-tier fallback: directory sheet -> sync_sources table -> GOOGLE_SHEET_IDS env var
- `lib/env.js` -- optional var warnings for `GOOGLE_DIRECTORY_SHEET_ID` and `GOOGLE_WORKSPACE_ADMIN_EMAIL`

### Changed

- `lib/data/sheets.js` -- replaced `google.auth.GoogleAuth` with `google.auth.JWT` for domain-wide delegation support; `GOOGLE_WORKSPACE_ADMIN_EMAIL` env var provides the impersonation subject
- `lib/data/sheets.js` -- `fetchCompetitionResults()` now fetches `A1:R1000` with dynamic header detection instead of hardcoded `Results!A67:R1000`
- `app/api/sync/route.js` -- sync route now reads directory sheet first to discover all competition sheets, with metadata override for sheets with non-standard title formats; competition upsert includes `event_multiplier` and `year_multiplier`
- `lib/data/transform.js` -- `transformSheetData()` carries `eventMultiplier` and `yearMultiplier` through to competition objects
- `lib/data/index.js` -- `mapCompetition()` includes `eventMultiplier` and `yearMultiplier` fields; `fetchAllEntries()` paginates in 1000-row batches to handle datasets exceeding Supabase's default row limit

### Deployment Notes

- Migration 007 must be applied in Supabase before deploying
- Add `GOOGLE_DIRECTORY_SHEET_ID` and `GOOGLE_WORKSPACE_ADMIN_EMAIL` to Vercel env vars
- Domain-wide delegation must be configured in Google Workspace Admin for the service account's client ID with the `spreadsheets.readonly` scope
- After deploy, trigger a sync to import all competitions from the directory (24 competitions, up from 7)
- One orphaned competition (Tap Cancer Out 6/8/24) exists from the old env var that is not in the directory sheet

---

## [0.5.2] -- 2026-04-09

### Added

- `supabase/migrations/003_entries_weight_class.sql` -- `weight_class` column on entries table, populated during sync
- `supabase/migrations/004_competitors_rank_order.sql` -- `rank_order` and `rank_change` columns on competitors table, populated during sync
- `supabase/migrations/005_peer_averages.sql` -- `peer_averages` table for pre-computed per-bucket peer stats with RLS public read policy
- `supabase/migrations/006_entries_indexes.sql` -- indexes on `entries.competitor_id`, `entries.date`, `entries.competition_id`
- `components/posthog-wrapper.jsx` -- deferred PostHog initialization; lazily imports `posthog-js` in a `useEffect` after hydration, with route-change page view tracking
- `proxy.js` -- security headers proxy (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`)
- `lib/env.js` -- environment variable validation at import time for core vars, on-demand for sync vars
- `app/competitor/[id]/page.jsx` -- `ProfileSkeleton` Suspense fallback replacing `fallback={null}`
- Memory monitoring via `logMemory()` helper in sync route and data layer, logging RSS/heap at key checkpoints

### Changed

- `app/competitor/[id]/page.jsx` -- `CompetitorRadar` and `MatchTimeline` lazy-loaded via `next/dynamic` with loading placeholders
- `app/layout.jsx` -- constrained Geist font weights to 400-800, Geist_Mono to 400-500, added `display: "swap"`; replaced `@posthog/next` with deferred `PostHogWrapper`; `ThemeProvider` moved outside `PostHogWrapper` to prevent client-side script tag re-mount
- `next.config.mjs` -- added `serverExternalPackages: ["googleapis"]` to prevent client-side bundling of ~2-3MB package; added PostHog `/ingest` proxy via `rewrites()`
- `components/filter-bar.jsx` -- `MobileFilterSheet` lazy-loaded via `next/dynamic` (mobile-only, no SSR needed)
- `lib/data/transform.js` -- entry objects now include `weightClass` from `parseDivision()` output
- `lib/data/index.js` -- removed `parseDivision` import from fetch path; `mapEntry()` reads `weight_class` from DB column; `mapCompetitor()` includes `rankOrder`/`rankChange`; `getEnrichedLeaderboard()` uses pre-computed ranks when available with fallback; `getPeerAverages()` reads from `peer_averages` table with fallback to full-dataset computation; competitors query uses `select("*")` for backward compatibility before migration; override application uses field allowlist
- `app/api/sync/route.js` -- persists `weight_class` on entry rows; computes and persists rankings after entry upserts; computes and upserts peer averages per `{ageGroup}|{belt}` bucket; validates sync env vars before starting
- `lib/data/sheets.js` -- `getAuth()` validates credentials exist and wraps `GoogleAuth` construction in try-catch with clear error messages
- `proxy.js` -- replaced `@posthog/next` `postHogMiddleware` with security-headers-only proxy; PostHog `/ingest` rewrite moved to `next.config.mjs`

### Fixed

- Console error "Encountered a script tag while rendering React component" from `next-themes` -- caused by `ThemeProvider` being nested inside client-rendered `PostHogWrapper`, triggering client-side re-mount of the FOUC-prevention script tag
- `components/leaderboard-table.jsx` -- removed `tbody` key anti-pattern (`key={sortColumn-sortDirection-page-length}`) that forced full DOM unmount/remount of all rows on every sort, page, or filter change
- `components/activity-feed.jsx` -- entries no longer mounted in DOM when feed is collapsed; only rendered when expanded

### Performance

- `components/belt-badge.jsx`, `components/result-badge.jsx`, `components/stat-card.jsx`, `components/podium.jsx` -- wrapped in `React.memo()` to prevent re-renders when parent state changes but props are unchanged
- `components/competitor-radar.jsx` -- `buildRadarData()` output memoized with `useMemo`
- `components/match-timeline.jsx` -- data transform, domain computation, and cell colors pre-computed once in `useMemo`; cell color array shared between both `<Bar>` components instead of mapping `data` twice

### Deployment Notes

- Migrations 003-005 must be applied in Supabase dashboard before deploying this code
- After deploy, trigger a sync to populate the new columns (`weight_class`, `rank_order`, `rank_change`) and the `peer_averages` table
- Code is backward-compatible: builds and runs correctly before migrations are applied (uses fallback computation paths)

---

## [0.5.1] -- 2026-04-09

### Changed

- `lib/data/index.js` -- rewrote `computePreviousRanks()` with Map-based grouping and linear max-date scan, reducing complexity from O(C*E) to O(E)
- `lib/stats.js` -- rewrote `buildStatsMap()` as single-pass accumulation with running totals, eliminating intermediate array allocations
- `lib/data/sheets.js` -- removed stale module-scoped `_cachedData` and `clearCache()` export; function is now stateless
- `lib/data/sheets.js` -- memoized `GoogleAuth` instance at module scope (`_cachedAuth`) to avoid repeated PEM key parsing
- `lib/supabase.js` -- swapped key precedence in `getSupabase()` so the publishable/anon key is preferred over the service role key; read client now respects RLS
- `app/api/sync/route.js` -- removed `clearCache` import and call (follows from sheets.js cleanup)

### Performance

- `computePreviousRanks()`: O(C * E) + O(C * k log k) reduced to O(E) + O(C)
- `buildStatsMap()`: two-pass group-then-compute reduced to single-pass accumulation

---

## [0.5.0] -- 2026-04-01

### Added

- Per-entry weight class extraction -- `mapEntry()` in `lib/data/index.js` now parses each entry's division string via `parseDivision()` to extract its weight class, independent of the competitor-level field
- Conditional weight class filter -- dropdown only appears when a competition is selected, populated with weight classes from that competition's entries
- Weight class reference data for 6 tournament organizations (IBJJF, NAGA, AGF, Grappling Industries, Tap Cancer Out, Fight 2 Win) in `lib/data/weight-class-definitions.js`
- Supabase migration `002_weight_class_definitions.sql` -- `weight_class_definitions` table with RLS public read policy and seed data for all 6 orgs
- Fight 2 Win (F2W) weight class definitions derived from observed competition data, with note that values may change

### Changed

- `app/page.jsx` -- removed static `weightClasses` from filter options; added `weightClass` to entryIndex payload sent to client
- `components/dashboard.jsx` -- weight class options derived dynamically via `useMemo` from entries when a competition is selected; weight filter resets to "all" when competition changes; weight filtering moved into the entry-scoped `needsRecompute` block for per-entry accuracy
- `components/filter-bar.jsx` -- weight class `Select` conditionally rendered only when `weightClasses.length > 0`
- `components/mobile-filter-sheet.jsx` -- same conditional rendering for mobile weight class dropdown

### Design decisions

- Raw weight class values preserved as-is per organization (no cross-org normalization) -- a NAGA "50-59.9" and an IBJJF "Feather" are different data points for future weighted scoring
- Reference data is not used in the read path; exists for future validation and scoring modules

---

## [0.4.0] -- 2026-03-26

### Added

- `sync_sources` table in Supabase -- separates sync configuration (which sheets to fetch) from synced data, enabling new competition registration without redeploying
- Auto-seed logic in sync route -- on first run with an empty `sync_sources` table, populates it from `GOOGLE_SHEET_IDS` env var
- Per-source sync status tracking -- each `sync_sources` row records `last_synced_at`, `last_sync_status` (success/error/partial), and `last_sync_message`
- SQL migration file at `supabase/migrations/001_sync_sources.sql`

### Changed

- `vercel.json` -- cron schedule changed from hourly (`0 * * * *`) to weekly Monday 6 AM UTC (`0 6 * * 1`); competitions happen on weekends, Monday morning captures results
- `lib/data/sheets.js` -- `fetchAllCompetitionData()` now accepts a `sheetIds` parameter instead of reading `GOOGLE_SHEET_IDS` env var directly
- `app/api/sync/route.js` -- reads enabled sheet IDs from `sync_sources` table with env var fallback; updates per-source sync status after each run
- `proxy.js` -- middleware matcher excludes `/api/*` routes to prevent PostHog middleware from interfering with API auth headers

---

## [0.3.0] -- 2026-03-25

### Added

- Next.js 16 `'use cache'` directive on the data layer with `cacheLife('hours')` and `cacheTag('leaderboard')` for automatic hourly caching
- `lib/stats.js` shared stats module -- `computeStatsFromEntries()` and `buildStatsMap()` extracted for use by both server (data layer) and client (Dashboard filtering)
- `components/dashboard.jsx` client component -- all filtering, sorting, pagination now runs in pure JavaScript on the client with zero server round-trips
- Tag-based cache invalidation via `revalidateTag('leaderboard')` in the sync route
- `<Link prefetch>` on competitor names in the leaderboard table for instant profile navigation
- Partial Prerender on `/competitor/[id]` -- static shell streams immediately, data loads via Suspense

### Fixed

- Profile pages returning 404 on Vercel production -- non-cached wrapper functions calling `"use cache"` functions did not resolve the Data Cache during PPR streaming; fixed by adding `"use cache"` directives to all public API functions (`getCompetitorById`, `getEntriesByCompetitor`, `getStats`, `getPeerAverages`, `getCompetitions`)

### Changed

- `lib/data/index.js` -- fully rewritten. Single `getEnrichedLeaderboard()` function fetches all data in one cached call; all public API functions are themselves `"use cache"` functions that derive from the cached dataset
- `app/page.jsx` -- converted to thin server shell that passes the full dataset to the Dashboard client component; filter options and recent activity resolved server-side via Map lookups
- `app/competitor/[id]/page.jsx` -- split into Suspense wrapper + async inner component for compatibility with `cacheComponents`; removed `generateStaticParams` and `export const revalidate`
- `components/filter-bar.jsx` -- converted to controlled component accepting `filters`, `onFilterChange`, `onClear` props; removed `useSearchParams`, `useRouter`, `useTransition`
- `components/leaderboard-table.jsx` -- competitor name column now uses `<Link>` with prefetch instead of relying solely on row click handler
- `app/api/sync/route.js` -- added `revalidateTag('leaderboard')` to bust the `'use cache'` layer on sync
- `next.config.mjs` -- enabled `cacheComponents: true`

### Removed

- Request-scoped cache (`resetRequestCache()`) from the data layer -- replaced by framework-level `'use cache'`
- Server-side filtering via `router.push()` and URL search params triggering full re-renders -- replaced by client-side `useMemo` filtering
- `export const revalidate = 3600` from page routes -- incompatible with `cacheComponents`, replaced by `cacheLife('hours')`
- `generateStaticParams()` from competitor profile -- incompatible with `cacheComponents` when no IDs are known at build time

### Performance

- Dashboard filtering: from ~1-3s server round-trip per filter change to <16ms client-side recomputation
- Profile navigation: from full server render on click to prefetched instant navigation
- Data layer: from 3-5 independent Supabase HTTP calls per render to 1 cached call with hourly TTL
- Build output: `/` is static with 1h revalidation; `/competitor/[id]` uses Partial Prerender

---

## [0.2.0] -- 2026-03-24

### Added

- Supabase (Postgres) as serving layer between Google Sheets and the website
- Sync API route (`app/api/sync/route.js`) -- fetches Sheets, transforms, upserts to Supabase with CRON_SECRET auth
- Supabase client factory (`lib/supabase.js`) -- singleton with `server-only` guard, read client (publishable key) and admin client (service role key)
- Vercel Cron configuration (`vercel.json`) -- hourly sync at `:00`
- `clearCache()` export on `sheets.js` for forced refresh during sync
- Overrides table in Supabase replaces `lib/data/overrides.json` -- applied via LEFT JOIN + COALESCE at query time
- Weight class normalization function `normalizeWeightClass()` in `transform.js`
- `docs/project/CAPABILITIES.md` feature inventory
- `AGENTS.md` agent index with documentation pointers and workflow orchestration

### Changed

- `lib/data/index.js` -- rewritten to query Supabase instead of in-memory cache; stats computed from DB rows; overrides applied via foreign key join; all exported function signatures unchanged
- Data architecture: decoupled ingestion (Sheets -> sync job -> Supabase) from serving (Supabase -> Next.js)
- `sheets.js` and `transform.js` now only used by sync route, not by page rendering

### Fixed

- Competition filter now recomputes stats scoped to the selected competition instead of showing lifetime totals (`getLeaderboard()` in `index.js`)
- Competition + type filter intersection handled correctly -- stats reflect both filters combined
- "No Gi" display normalized to "Nogi" in filter bar and competitor profile type badges
- Removed incorrect belt keywords (`challenger`, `expert`, `colored`) from `BELT_KEYWORDS` in `transform.js`

---

## [0.1.1] -- 2026-03-23

### Added

- Google Sheets API integration via service account (`lib/data/sheets.js`)
- Data transformation layer with regex-based division parsing across 7 tournament formats (`lib/data/transform.js`)
- Async data access layer replacing static seed data (`lib/data/index.js`)
- Support for Grappling Industries, F2W, AGF, NAGA, Tap Cancer Out, and Submission Challenge division string formats
- Belt keyword detection including combined divisions (White/Grey, Yellow/Orange, Green/Blue), typo handling (Whuite, Ornage)
- IBJJF kids belt ranking system: white > grey > yellow > orange > green
- Academy mapping for all 8 Easton locations plus common aliases (Matrix Jiu Jitsu -> Castle Rock, Easton-prefixed names)
- Peer average computation for radar chart comparison by age group and belt
- ISR caching with `revalidate = 3600` on all page routes
- Module-scope caching for Sheets API responses and transformed data
- `docs/project/ARCHITECTURE.md` architecture reference
- `docs/project/CHANGELOG.md` (this file)

### Changed

- `app/page.jsx` -- converted to async server component fetching live data from Google Sheets
- `app/competitor/[id]/page.jsx` -- full rewrite for async data; new stats grid (wins, losses, win rate, gold, total medals, podium %, champ %, avg WFM, entries), round results visualization, radar + timeline charts, competition history table
- `components/filter-bar.jsx` -- receives filter options as props instead of fetching directly; replaced division toggle with gi/nogi type toggle; dynamic options from live data
- `components/leaderboard-table.jsx` -- new columns (gold, medals, podium %); removed streak, submission wins, points/match
- `components/activity-feed.jsx` -- changed from match-based to entry-based data model; shows W-L record, competition name, medal summary
- `components/podium.jsx` -- added gold count and total medal display
- `components/result-badge.jsx` -- added gold, silver, bronze medal badge variants
- `components/competitor-radar.jsx` -- 6 new dimensions (win rate, podium %, champ %, medals, activity, WFM) with peer average overlay
- `components/match-timeline.jsx` -- stacked bar chart per competition entry; gi (blue) vs nogi (violet) color coding; losses rendered as negative bars
- `lib/data/index.js` -- rewritten as async data access layer with computed stats

### Fixed

- Empty competition IDs causing duplicate React keys in filter bar
- WFM percentage read from correct column index (row[11], not row[12])
- Belt defaulting to white for all competitors when division strings lacked belt info
- Same-date entries not updating competitor profile
- Higher-belt entries overwritten by lower-belt entries from same competition
- Combined belt divisions (White/Grey) now correctly resolve to the lower belt rank
- "Matrix" and "Matrix Jiu Jitsu" academy names now map to Easton Training Center - Castle Rock
- Age parsing handles "yrs old" variant and skips experience ranges (0-1 years)
- XU age format (6U, 8U) takes priority over ambiguous range formats

---

## [0.1.0] -- 2026-03-05

### Added

- Initial release with static seed data (20 competitors, 88 matches)
- Next.js 16 App Router with React 19
- Dark-mode-first glass morphism UI with Tailwind CSS v4 and shadcn/ui
- Dashboard with podium (top 3), sortable/paginated leaderboard table, activity feed
- Competitor profile pages with stat cards, radar chart, match timeline, competition history
- URL-param-based filtering (division, belt, weight, competition, academy)
- Belt badge component with per-belt color indicators (white through green)
- Result badges (win, loss, draw, DQ)
- Theme toggle (light/dark) via next-themes
- Geist Sans + Geist Mono fonts
- Staggered row entrance animations
- Responsive layout with mobile-first column hiding
- PostHog analytics integration and proxy at `/ingest` route

## Template Entry

Copy and customize this template for new releases:

```
## [X.Y.Z] - YYYY-MM-DD

### Added

- New feature 1

### Changed

- Updated behavior of existing feature

### Fixed

- Bug fix 1

### Security

- Security fix 1
```

---

**Note:** Maintain this changelog by adding entries under `[Unreleased]` during development, then moving them to a versioned section at release time.

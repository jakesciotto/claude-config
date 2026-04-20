# ARCHITECTURE.md

Competition leaderboard for Easton BJJ tracking kids and adults results across Colorado academy locations.

## Tech Stack

- **Framework**: Next.js 16.2.0, App Router, React 19
- **Language**: JavaScript (.jsx/.js), no TypeScript
- **Styling**: Tailwind CSS v4, shadcn/ui (new-york style, zinc base)
- **Charts**: recharts v3 (radar, stacked bar)
- **Icons**: lucide-react
- **Fonts**: Geist Sans + Geist Mono (next/font)
- **Data**: Supabase (Postgres) serving layer, Google Sheets as source of truth via sync job
- **Sync**: googleapis (JWT auth with domain-wide delegation) for Sheets API, @supabase/supabase-js for DB writes
- **Analytics**: PostHog (proxied at /ingest)
- **Theming**: next-themes (attribute="class", defaultTheme="dark")

## Directory Structure

```
app/
  layout.jsx              Root layout (ThemeProvider, Nav, max-w-7xl container)
  page.jsx                Thin server shell -- fetches cached data, passes to Dashboard
  globals.css             Theme variables, belt colors, glass morphism, keyframes
  icon.svg                Favicon
  competitor/[id]/
    page.jsx              Suspense wrapper + async CompetitorProfile (Partial Prerender)
  api/
    sync/
      route.js            Sync job: Sheets -> Supabase (auth via CRON_SECRET)

components/
  dashboard.jsx           Client component -- filtering, sorting, pagination, all interactivity
  nav.jsx                 Sticky nav, glass morphism, theme toggle
  podium.jsx              Top 3 cards with gold/silver/bronze accents
  leaderboard-table.jsx   Sortable, paginated table (10/page), rank change arrows, Link prefetch
  filter-bar.jsx          Controlled filters (type, belt, weight, competition, academy)
  activity-feed.jsx       Recent entries collapsible accordion
  stat-card.jsx           Glass card with gradient border, colored stat numbers
  belt-badge.jsx          Muted badge with per-belt dot indicator
  result-badge.jsx        Win/loss/medal badges
  competitor-radar.jsx    6-dimension radar chart (vs peer average)
  match-timeline.jsx      Stacked bar chart (wins positive, losses negative)
  theme-provider.jsx      next-themes wrapper
  ui/                     shadcn/ui primitives (badge, button, card, select, etc.)

lib/
  data/
    index.js              Cached data access layer ('use cache' + cacheLife/cacheTag)
    sheets.js             Google Sheets API auth + fetch (used by sync route only)
    transform.js          Raw sheet parsing, division string extraction, dedup (sync route only)
    seed.js               Original placeholder data (unused, kept for reference)
  points.js               Point system: getYearMultiplier, computeEntryPoints, computeERP, compareByPoints
  stats.js                Shared stats computation (computeStatsFromEntries, buildStatsMap)
  supabase.js             Supabase client singleton factory
  utils.js                cn() utility, formatAcademy() helper

docs/
  project/                Architecture and changelog (this directory)
  plans/                  Design specs and implementation plans

vercel.json               Cron config: weekly sync Monday 6 AM UTC
```

## Data Flow

```
Directory Google Sheet (master index of all competitions)
        |
        v  (weekly Monday 6 AM UTC via Vercel Cron -> /api/sync)
app/api/sync/route.js -- discoverFromDirectory()
  - Reads GOOGLE_DIRECTORY_SHEET_ID env var
  - Fetches directory sheet via fetchDirectoryEntries()
  - Filters to rows where Scrape=TRUE and Results=TRUE
  - Extracts sheet IDs from Results Link URLs
  - Three-tier fallback: directory -> sync_sources table -> GOOGLE_SHEET_IDS env var
  - Upserts discovered sheets into sync_sources table
        |
        v
lib/data/sheets.js -- fetchAllCompetitionData()
  - Authenticates via JWT with domain-wide delegation (GOOGLE_WORKSPACE_ADMIN_EMAIL)
  - For each sheet ID (in parallel via Promise.allSettled):
    1. Fetches spreadsheet title, parses date + name via parseTitle()
    2. Resolves tab name: tries "Results", then "All Results", then first tab
    3. Fetches A1:R1000, scans for header row ("Academy" in col A)
    4. Returns rows after header
  - Directory metadata overrides title parsing when parseTitle() fails
        |
        v
lib/data/transform.js -- transformSheetData()
  [See ETL Reference below for column-level detail]
  - Parses each row: academy, name, division, rounds, placement, medals
  - parseDivision() extracts type/belt/age/gender/weight from 7+ formats
  - Deduplicates competitors by name+academy slug
  - Belt: highest belt from most recent competition date
  - Returns { competitors, entries, competitions }
        |
        v
app/api/sync/route.js -- upserts + ranking
  - Upserts competitions (with event_multiplier, year_multiplier)
  - Upserts competitors
  - Deletes + re-inserts entries per competition (handles row reordering)
  - Computes and persists rankings (rank_order, rank_change)
  - Computes and upserts peer averages by {ageGroup}|{belt}
  - Updates per-source sync status (success/error/partial)
  - Busts cache: revalidateTag('leaderboard'), revalidatePath()
        |
        v
Supabase (Postgres)
  - Tables: competitions, competitors, entries, overrides,
    sync_sources, peer_averages, weight_class_definitions
  - sync_sources: populated from directory sheet on each sync,
    tracks per-source status (last_synced_at, last_sync_status)
  - Adding new competitions: add a row to the directory Google Sheet
  - Overrides applied via LEFT JOIN + COALESCE at query time
  - RLS: public read, service role write
        |
        v
lib/data/index.js ('use cache' + cacheLife('hours') + cacheTag('leaderboard'))
  - getEnrichedLeaderboard(): single cached function fetches all tables in
    parallel via Promise.all, computes stats via buildStatsMap(), sorts,
    computes rank changes, returns { competitors, entries, competitions }
  - All public API functions derive from the cached dataset
  - Entries fetched with pagination (1000 rows per page) to avoid Supabase default limit
  - Cache TTL: hourly (cacheLife('hours')), busted on sync via revalidateTag
        |
        v
Server Components -> Client Components (unchanged)
```

## Data Models

### Competitor

```js
{
  id: "nash-caley",                   // kebab-case(name) -- academy-independent
  name: "Nash Caley",
  academy: "Easton Training Center - Arvada",  // most recent academy
  belt: "grey",                       // highest from most recent competition
  ageDivision: "kids",
  ageGroup: "6-7",
  gender: null,
  weightClass: "-45 lbs",
  // computed stats (from ranking-eligible entries only, i.e. 2024+):
  wins, losses, winRate,
  goldMedals, totalMedals,
  podiumRate, champRate,
  avgWfm, totalEntries,
  totalPoints,                        // sum of entry.points across ranking-eligible entries
  erp                                 // Easton Ranking Potential (1.0-10.0 percentile composite, null if < 3 entries)
}
```

### Entry (Competition Registration)

```js
{
  id: "2024-01-20-grappling-industries-denver-kids-results-0",
  competitorId: "nash-caley-arvada",
  competitionId: "2024-01-20-grappling-industries-denver-kids-results",
  date: "2024-01-20",
  competitionName: "Grappling Industries Denver Kids Results",
  type: "nogi",                       // "gi" or "nogi"
  division: "No Gi Kids / Beginner (White) / 6 - 7 years / -45 lbs",
  bracketType: "Round Robin - True round robin",
  rounds: ["W", "W", "W", "W", "W"],
  wins: 5, losses: 0,
  placement: 1,
  podium: true, champion: true,
  medals: { gold: 1, silver: 0, bronze: 0 },
  wfm: 1.0,
  points: 27                          // (gold*9 + silver*3 + bronze*1) * eventMult * yearMult
}
```

### Competition

```js
{
  id: "2024-01-20-grappling-industries-denver-kids-results",
  name: "Grappling Industries Denver Kids Results",
  date: "2024-01-20",
  spreadsheetId: "1DcsQ_khEvInCD7vvM15C17qY3WOcM4XRSxiJCIAQXi0",
  eventMultiplier: 1,         // from directory sheet (null for 2023)
  yearMultiplier: 1           // from directory sheet (null for 2023)
}
```

## Division String Parsing

The same athlete data arrives in 7+ division string formats across tournament organizers. `parseDivision()` handles all of them with regex-based extraction:

| Format          | Example                                                    | Source               |
| --------------- | ---------------------------------------------------------- | -------------------- |
| Standard        | `No Gi Kids / Beginner (White) / 6 - 7 years / -45 lbs`    | Grappling Industries |
| Slash-separated | `No Gi / Grey Belt / 50-59 lbs / 7-8 Years old / Female`   | Submission Challenge |
| Compact         | `6U NOGI 0-1 years`                                        | F2W (nogi section)   |
| Compact + belt  | `8U Grey Belt 65lbs`                                       | F2W (gi section)     |
| Arrow-separated | `No Gi > Kids > Grey > Little Kids > Feather I`            | AGF                  |
| Slash-name      | `Junior / 6-7 Years Old / White-Grey / Feather`            | Tap Cancer Out       |
| NAGA            | `Children No-Gi (Male) / Beginner / 50 - 59.9 / 6-7 years` | NAGA                 |

**Belt resolution rules (IBJJF kids order: white, grey, yellow, orange, green)**:

- Combined divisions (White/Grey, Yellow/Orange) map to the **lower** belt
- If a competitor has an explicit higher-belt entry, the highest belt wins
- NoGi entries without belt info do not overwrite existing belt data

## ETL Reference

This section documents the full extraction, transformation, and loading pipeline for making manual changes to the transformation layer. All ETL code lives in three files: `lib/data/sheets.js` (extract), `lib/data/transform.js` (transform), and `app/api/sync/route.js` (load).

### Extract: sheets.js

**Authentication**: `google.auth.JWT` with domain-wide delegation. The service account (`GOOGLE_SERVICE_ACCOUNT_EMAIL`) impersonates `GOOGLE_WORKSPACE_ADMIN_EMAIL` to access sheets shared with that user. When the env var is unset, JWT falls back to direct service account auth (only works for sheets explicitly shared with the service account).

**Directory sheet** (`fetchDirectoryEntries()`): Reads `Sheet1!A2:G200` from `GOOGLE_DIRECTORY_SHEET_ID`. Each row maps to:

| Column | Index | Field | Type | Notes |
|--------|-------|-------|------|-------|
| A | 0 | date | string | Raw "M/D/YY" format |
| B | 1 | event | string | Event name |
| C | 2 | eventMultiplier | float/null | Empty for 2023 entries |
| D | 3 | yearMultiplier | float/null | Empty for 2023 entries |
| E | 4 | scrape | boolean | "TRUE"/"FALSE" string |
| F | 5 | results | boolean | "TRUE"/"FALSE" string |
| G | 6 | resultsLink | string | Full Google Sheets URL |

Empty rows (year separators) are skipped. Sheet ID extracted from URL via `/spreadsheets/d/([a-zA-Z0-9_-]+)/`.

**Tab resolution** (`resolveResultsTab()`): Priority order: "Results" > "All Results" > first tab. Two 2023 sheets have non-standard tabs: "All Results" (8/12/23 GI), "Athlete List" (8/26/23 F2W).

**Header detection** (`fetchCompetitionResults()`): Fetches `'{tab}'!A1:R1000`, scans column A for a cell containing "Academy" (case-insensitive). Returns all rows after the header. Header positions vary: row 58-59 for 2023 sheets, row 66 for 2024+ sheets.

**Title parsing** (`parseTitle()`): Extracts date and name from spreadsheet titles matching `M/D/YY Competition Name`. Fails on non-standard titles (e.g., "NAGA Denver 10/7/23 List & Results"). When it fails (returns empty date), the sync route overrides from directory metadata.

### Transform: transform.js

**Row-level column mapping** (`parseRow()`): Each data row from a competition sheet has 18 columns (A-R):

| Column | Index | Field | Extraction | Notes |
|--------|-------|-------|------------|-------|
| A | 0 | academy | `resolveAcademy()` | Must match `ACADEMY_MAP`; row skipped if unrecognized |
| B | 1 | name | direct trim | Required; row skipped if empty |
| C | 2 | division | `parseDivision()` | Raw string preserved + parsed into type/belt/age/gender/weight |
| D | 3 | bracketType | direct trim | "Round Robin", "Best of three", "RR", etc. |
| E-J | 4-9 | rounds | W/L filter | Only "W" and "L" values kept; other values (blank, draws) ignored |
| K | 10 | placement | parseInt | 1, 2, 3, etc.; null if empty |
| L | 11 | wfm | `parseWfm()` | Win-for-match percentage; handles "#DIV/0!" and blanks |
| M | 12 | (unused) | -- | Blank column between WFM and Podium |
| N | 13 | podium | "y"/"n" check | Boolean |
| O | 14 | champion | "y"/"n" check | Boolean |
| P | 15 | bronze | parseInt | Medal count (0 if empty) |
| Q | 16 | silver | parseInt | Medal count (0 if empty) |
| R | 17 | gold | parseInt | Medal count (0 if empty) |

**Row filtering**: A row is discarded if any of these are true:
- Column A (academy) is empty
- Column B (name) is empty
- Column C (division) is empty
- Academy string doesn't match any key in `ACADEMY_MAP` (line 4-22)

**Academy resolution** (`ACADEMY_MAP`): Maps raw academy strings (case-insensitive) to canonical names. Supports 8 Easton locations + aliases. To add a new academy, add a new key-value pair to the map. Non-Easton academies are silently dropped.

**Division parsing** (`parseDivision()`): Extracts 5 fields from a single division string using regex. Detection order matters -- each field has a priority chain:

1. **type**: nogi if `/no[\s-]?gi|nogi/i` matches, else gi
2. **belt**: First match in `BELT_KEYWORDS` array (ordered: compound before simple). Combined divisions like "White/Grey" map to lower belt. `null` if no belt found.
3. **ageGroup**: (a) XU format first (`6U` -> `4-6`), (b) range format (`6-7 years`), (c) single age (`8 yrs old` -> `8-8`). Ranges below 3 are treated as experience, not age.
4. **gender**: "Female" if female/women/girl match, "Male" if male/boy match, else `null`
5. **weightClass**: (a) pounds format (`-85 lbs`), (b) IBJJF names (`Feather`), (c) numeric ranges (`50-59.9`). Normalized via `normalizeWeightClass()`.

**Competitor deduplication** (`transformSheetData()`): Key = `makeCompetitorId(name)` which is `kebab-case(name)`. Academy is not part of the key -- competitors who transfer schools are merged into a single record. Sheets are processed in date order. For each competitor:

- **First appearance**: Belt defaults to parsed belt or "white"
- **Later competition date**: Belt updates to parsed belt (or keeps previous if null); academy updates to current school
- **Same competition date**: Belt = whichever is higher per `BELT_RANK` order
- **ageGroup, gender, weightClass, academy**: Latest non-null value wins

**Entry construction**: Each parsed row becomes one entry. Entry ID = `{competitionId}-{entryIndex}` where entryIndex is a per-competition counter. Entries are not deduplicated -- one competitor can have multiple entries per competition (gi + nogi, multiple weight classes).

### Load: sync/route.js

**Upsert strategy**:
- `competitions`: upsert on `id` (kebab-case of date + name)
- `competitors`: upsert on `id` (kebab-case of name); orphaned records from old academy-suffixed IDs cleaned up post-sync
- `entries`: delete-and-reinsert per competition (handles row reordering in sheets)
- `peer_averages`: upsert on `id` ("`{ageGroup}|{belt}`" key)
- All batched at 500 rows max per Supabase request

**Ranking computation** (`computeRankings()`):
1. Attach `entry.points` to each mapped entry via `computeEntryPoints()` with event/year multipliers
2. Enrich competitors with stats from `buildStatsMap()` (includes `totalPoints`)
3. Sort by points (desc), then wins (desc), then win rate (desc) for current rank
4. Recompute stats excluding each competitor's most recent competition (includes `totalPoints`)
5. Sort again for previous rank using same comparator
6. `rank_change = previousRank - currentRank`

**Peer averages** (`computePeerAverages()`): Groups competitors by `{ageGroup}|{belt}` bucket. Computes average win_rate, podium_rate, champ_rate, total_medals, competition_count, avg_wfm per bucket.

### Common Manual Changes

**Adding a new academy**: Add a key-value pair to `ACADEMY_MAP` in `transform.js:4-22`. Key is the lowercase string as it appears in the spreadsheet's column A. Value is the canonical "Easton Training Center - Location" name.

**Adding a new belt keyword**: Add a `[regex, beltName]` pair to `BELT_KEYWORDS` in `transform.js:27-45`. Order matters -- compound patterns (e.g., "white/grey") must appear before their components.

**Fixing a division parsing bug**: The `parseDivision()` function at `transform.js:94-171` has 5 extraction blocks. Each can be modified independently. Test by running a sync and checking the entries table for the affected competition.

**Adding a new column to the sheet data**: Modify `parseRow()` at `transform.js:185-238` to read the new column index. Add the field to the return object, then propagate through the entry construction in `transformSheetData()` (line 299-317), the entry row mapping in `sync/route.js` (line 264-285), and `mapEntry()` in `index.js`.

**Changing the header detection**: The header row is found by scanning for "Academy" in column A (`sheets.js` line 98). If the header keyword changes, update the comparison string there.

## Point System

Points are computed at fetch time from existing database fields -- no schema changes required.

### Ranking Cutoff

Entries before `RANKING_CUTOFF_YEAR` (2024) are display-only: visible in competition history, round results, and timelines, but excluded from all stats, points, and ERP calculations. The constant and `isRankingEligible(entry)` helper live in `lib/points.js`. Profile pages show a separate "All-Time Stats" section when pre-cutoff entries exist.

### Formula

```
entryPoints = (gold * 9 + silver * 3 + bronze * 1) * eventMultiplier * yearMultiplier
```

- **Medal points**: gold=9, silver=3, bronze=1
- **Event multiplier**: from `competitions.event_multiplier` (null defaults to 1). Easton Open/Solid Series: 3, F2W: 2, NAGA: 2, everything else: 1
- **Year multiplier**: computed dynamically from entry date. Current year: 3, previous year: 2, two years ago: 1, older: 0

### ERP (Easton Ranking Potential)

Percentile-based composite score across four equally-weighted metrics, mapped to a 1.0-10.0 scale. Designed for cross-academy comparability -- a 7.0 at one academy means the same relative standing as a 7.0 at another.

**Metrics** (25% weight each):

| Metric | What it measures | Why it matters |
|--------|-----------------|----------------|
| Points per entry | `totalPoints / totalEntries` | Efficiency -- rewards quality over volume |
| Win rate | `wins / (wins + losses)` | Competitive quality |
| Podium rate | `podiumFinishes / totalEntries` | Consistency at the top |
| Total points | Sum of all entry points | Volume -- credit for showing up |

**Algorithm**:
1. Filter to competitors with >= 3 entries (minimum threshold for meaningful rates)
2. For each metric, sort all qualified competitors and assign percentile ranks (0-100). Ties receive the average percentile of their tied positions.
3. Average the four percentile ranks
4. Map to 1.0-10.0: `round(1 + (avgPercentile / 100) * 9, 1)`

**Unrated competitors**: Those with fewer than 3 entries receive `erp = null`. Displayed as "Unrated" on profile pages and "--" in the table.

**Recomputation on filter**: ERP is recomputed on every filter change using only the filtered population, so it reflects relative standing within the filtered group rather than the global dataset.

### Computation flow

1. `getEnrichedLeaderboard()` (server): after fetching entries and competitions, builds a competition lookup map, loops ALL entries to attach `entry.points` via `computeEntryPoints()`. Then filters to ranking-eligible entries (2024+) and calls `buildStatsMap()` on the filtered set. All entries (including pre-cutoff) are returned for display.
2. `computeERPScores(enriched)` computes percentile-based ERP across all competitors using ranking-eligible stats only, returning a Map of id -> score (or null for unrated).
3. On the client, when filters are active, `computeStatsFromEntries()` re-sums `totalPoints` from filtered ranking-eligible entries, and `computeERPScores()` recomputes ERP relative to the filtered population.

## Ranking Algorithm

1. Primary sort: total points (descending)
2. Tiebreaker 1: total wins (descending)
3. Tiebreaker 2: win rate (descending)
4. Rank change: current rank minus rank computed by excluding each competitor's most recent competition date (using point-based sort). Positive = moved up, negative = dropped.

## Filtering

All filtering runs client-side in `components/dashboard.jsx`. The full competitor dataset and an `entryIndex` (entries grouped by competitor ID, including `date` for cutoff filtering) are passed as props from the server. A search bar (`?q=` param) filters competitors by name via case-insensitive substring match. Attribute filters (belt, weight, academy, type, competition) combine with AND logic via `useMemo`. For simple attribute filters (belt, weight, academy), stats are preserved from the server. For type/competition filters, stats are recomputed client-side using `computeStatsFromEntries()` from `lib/stats.js`, with pre-cutoff entries excluded. URL search params (`?q=nash&belt=grey&type=nogi&academy=...`) are synced via `window.history.replaceState()` for shareable links, but `useState` is the rendering source of truth -- no server round-trips occur on filter change. When no filters or search are active, the podium (top 3) displays and the table starts at rank 4.

## Theme System

CSS custom properties defined in `globals.css` under `:root` (light) and `.dark` (dark) scopes. No Tailwind `dark:` variants -- everything references variables.

Key variable groups:

- **Page**: `--page-bg`, `--text-primary`, `--text-secondary`, `--text-muted`
- **Glass morphism**: `--glass-bg`, `--glass-border`, `--glass-hover`, `--glass-highlight`
- **Belt colors**: `--belt-white` through `--belt-green` (9 colors, HSL)
- **Result colors**: `--result-win`, `--result-loss`, `--result-draw`, `--result-dq`

Standard glass card pattern:

```
bg-[var(--glass-bg)] backdrop-blur-xl border border-[var(--glass-border)]
```

with gradient top border accent.

## Caching Strategy

- **Data layer cache**: `lib/data/index.js` uses the Next.js 16 `'use cache'` directive with `cacheLife('hours')` and `cacheTag('leaderboard')`. All Supabase reads go through the cached `getEnrichedLeaderboard()` function. The framework caches the return value with an hourly TTL and 1-day stale-while-revalidate window.
- **Cache invalidation**: The sync route calls `revalidateTag('leaderboard')` to bust the data cache on demand, plus `revalidatePath()` for ISR page invalidation.
- **Config**: `cacheComponents: true` in `next.config.mjs` enables the `'use cache'` directive globally.
- **Profile pages**: Use Partial Prerender -- the static shell (layout, back link, Suspense fallback) renders instantly; data streams in via the async inner component.
- **Sync job**: Weekly Vercel Cron (Monday 6 AM UTC) calls `/api/sync` which reads enabled spreadsheet IDs from the `sync_sources` table (with env var fallback), fetches fresh Sheets data, upserts to Supabase, updates per-source sync status, and triggers cache + ISR revalidation.
- **Manual sync**: Admin-only button in nav (gated by `localStorage.admin === "1"`). Calls server action in `app/actions.js` which invokes `/api/sync` with the `CRON_SECRET`. Icon spins during sync, turns green on success, red on failure. Page data refreshes automatically via `router.refresh()` on success.
- **CLI sync** (local dev): `CRON_SECRET=$(grep '^CRON_SECRET=' .env.local | cut -d'=' -f2 | tr -d '"') && curl -s -H "Authorization: Bearer $CRON_SECRET" http://localhost:3000/api/sync`
- **Error resilience**: `Promise.allSettled` in `sheets.js` allows individual sheet failures without blocking the sync.

## Known Performance Constraints

Documented from codebase audit (2026-04-09). See `TODO.md` for the actionable backlog.

### Data Layer

- **`computePreviousRanks()` is O(n^2)**: Filters the entire entries array per competitor. Becomes a bottleneck past ~200 competitors. Fix requires pre-grouping entries into a Map.
- **`parseDivision()` runs on fetch, not sync**: 17-pattern regex extraction executes on every cache miss (~5,000+ regex ops) to derive `weightClass` from division strings. This should be persisted to the database during sync.
- **`buildStatsMap()` two-pass allocation**: Groups entries into arrays, then iterates groups to compute stats. A single-pass accumulator would halve memory allocations.
- **Module-scoped JWT auth in `sheets.js`**: Cached auth instance survives across warm lambda invocations. Not a data staleness risk since auth tokens auto-refresh, but the impersonation subject is fixed at init time.
- **Supabase default row limit**: All three fetch functions (`fetchAllEntries`, `fetchCompetitorsWithOverrides`, `fetchAllCompetitions`) now paginate at 1000 rows per page. Any new Supabase `.select()` returning variable-length results must also paginate.

### Bundle

- **Recharts (~300KB)** is eagerly imported on profile pages. Should be dynamically imported with a skeleton fallback.
- **`googleapis` (~2-3MB)** is used only in the weekly sync route. Tree-shaking must be verified to ensure it does not leak into client bundles.
- **Font weights unconstrained**: `Geist()` and `Geist_Mono()` load all available weights. Only 3-4 weights are used in practice.

### React Rendering

- **`tbody` key anti-pattern** in `leaderboard-table.jsx`: Composite key on `<tbody>` forces full unmount/remount on every sort, page, or data change instead of allowing React to diff rows.
- **Missing `React.memo()`** on leaf components (`BeltBadge`, `ResultBadge`, `StatCard`, `PodiumCard`, `Nav`): Causes cascading re-renders from parent filter/sort state changes.
- **Chart data not memoized**: `buildRadarData()` and timeline transforms recompute on every render without `useMemo`.

### Infrastructure

- **No security headers**: Missing `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, CSP. No `middleware.js` exists.
- **No `Cache-Control` on static assets**: Immutable hashed assets are not explicitly marked as cacheable.
- **Supabase read client key precedence**: Falls back to service role key for read operations, potentially bypassing RLS.

## Component Patterns

- **Server components** fetch data and pass to client components as props
- **Client components** handle interactivity (sorting, pagination, filtering, theme toggle)
- **Staggered animations**: 40ms delay per row via inline `animationDelay` style
- **Responsive**: Mobile-first, columns hidden via `hidden md:table-cell`
- **Muted badge pattern**: `bg-{color}/10 text-{color}/70 ring-1 ring-inset ring-{color}/15`

## Environment Variables

| Variable                         | Required | Purpose                                                             |
| -------------------------------- | -------- | ------------------------------------------------------------------- |
| `SUPABASE_URL`                   | Yes      | Supabase project URL                                                |
| `SUPABASE_SERVICE_ROLE_KEY`      | Yes      | Service role key (bypasses RLS for sync writes)                     |
| `CRON_SECRET`                    | Yes      | Bearer token for sync route auth (Vercel Cron)                      |
| `GOOGLE_SERVICE_ACCOUNT_EMAIL`   | Yes      | Service account email for Sheets API                                |
| `GOOGLE_PRIVATE_KEY`             | Yes      | PEM key, newline-escaped                                            |
| `GOOGLE_SHEET_IDS`               | No       | Comma-separated spreadsheet IDs (fallback when directory is unset)  |
| `GOOGLE_DIRECTORY_SHEET_ID`      | No       | Directory sheet ID for competition discovery                        |
| `GOOGLE_WORKSPACE_ADMIN_EMAIL`   | No       | Email for JWT domain-wide delegation (impersonation subject)        |
| `NEXT_PUBLIC_POSTHOG_KEY`        | No       | PostHog project API key                                             |
| `NEXT_PUBLIC_POSTHOG_HOST`       | No       | PostHog host URL                                                    |

## Academy Locations

8 Easton Training Center locations across Colorado:

| Short Name                | Canonical Name                       |
| ------------------------- | ------------------------------------ |
| Arvada                    | Easton Training Center - Arvada      |
| Boulder                   | Easton Training Center - Boulder     |
| Centennial                | Easton Training Center - Centennial  |
| Denver                    | Easton Training Center - Denver      |
| Littleton                 | Easton Training Center - Littleton   |
| Longmont                  | Easton Training Center - Longmont    |
| Lowry                     | Easton Training Center - Lowry       |
| Matrix / Matrix Jiu Jitsu | Easton Training Center - Castle Rock |

Displayed as "ETC {Location}" via `formatAcademy()`.

# Performance Optimization Design

**Date:** 2026-03-25
**Status:** Draft
**Goal:** Eliminate server round-trips from filtering and profile navigation, making both interactions feel instant.

---

## Problem Statement

Every filter interaction and profile click triggers a full Next.js server component re-render, which makes sequential Supabase HTTP calls, computes stats, generates HTML, and transfers it back to the client. With 1000+ competitors and 7+ data layer calls per page render, this produces 2-5 second latencies on filter changes and 1-3 second latencies on profile navigation.

The underlying data changes once per hour (via the sync cron job). The architecture pays the cost of a live database query on every user interaction for data that hasn't changed.

## Architecture Principle

Treat the data as effectively static between sync intervals. Cache the read path aggressively. Move interactive filtering to the client. Pre-render profile pages as static HTML.

Supabase remains the source of truth and write layer. It should not be the read path for every user interaction.

---

## Section 1: Data Layer -- Cached Pre-computation

### Current State

`lib/data/index.js` uses module-scope variables (`_cachedCompetitors`, `_cachedEntries`) as a request-scoped cache. `resetRequestCache()` is called at the top of every page render, so every request starts cold and hits Supabase.

### New Design

Replace the request-scoped cache with the `'use cache'` directive (Next.js 16's compiler-driven caching, which replaces the deprecated `unstable_cache`). Use `cacheTag()` for tag-based revalidation and `cacheLife()` for TTL control.

**Core cached function -- `getEnrichedLeaderboard()`:**

1. Fetches all competitors with overrides in one Supabase query
2. Fetches all entries in one Supabase query
3. Fetches all competitions in one Supabase query
4. Computes stats per competitor via `buildStatsMap()`
5. Computes rank changes for the default (unfiltered) sort
6. Returns `{ competitors, entries, competitions }` -- the full enriched dataset

```js
async function getEnrichedLeaderboard() {
  'use cache'
  cacheLife('hours')    // TTL matches sync interval
  cacheTag('leaderboard')

  const supabase = getSupabase()
  const [competitorsRaw, entriesRaw, competitionsRaw] = await Promise.all([
    fetchCompetitorsWithOverrides(supabase),
    fetchAllEntries(supabase),
    fetchAllCompetitions(supabase),
  ])
  // ... compute stats, rank changes, return enriched dataset
}
```

**Constraint:** `'use cache'` functions cannot access `cookies()`, `headers()`, or `searchParams`. This is fine -- `getEnrichedLeaderboard()` has no request-specific dependencies. Dynamic values (like filter params) are read in the Page component and passed as arguments to downstream functions.

**Supporting functions (all derived from the cached dataset, no additional Supabase calls):**
- `getCompetitions()` -- returns `competitions` from the cached result
- `getAcademies()` -- extracts unique academies from the cached competitors
- `getStats()` -- sums `totalEntries`, `totalMedals`, `totalGoldMedals` from the cached entries
- `getCompetitorById(id)` -- finds by ID in the cached competitors, attaches per-competitor entries
- `getEntriesByCompetitor(id)` -- filters from the cached entries array
- `getPeerAverages(ageGroup, belt)` -- computed from the cached dataset

**Functions removed:**
- `resetRequestCache()` -- `'use cache'` handles invalidation via tags
- `getCachedCompetitors()` / `getCachedEntries()` -- replaced by the single cached function
- `getAcademies()` standalone Supabase query -- derived from cached data instead

**Internal functions retained (moved or kept in `index.js`):**
- `computeStatsFromEntries()` -- stays, used by enrichment logic
- `buildStatsMap()` -- stays, used by enrichment logic
- `computePreviousRanks()` -- stays, used to pre-compute default rank changes server-side
- `mapCompetitor()` / `mapEntry()` / `mapCompetition()` -- stay, used by fetch functions

**Net effect:** Supabase is queried 3 times per cache miss (competitors, entries, competitions -- fired in parallel via `Promise.all`). All calls within the cache lifetime read from the Next.js server cache with zero network overhead.

---

## Section 2: Dashboard -- Client-Side Filtering

### Current State

`app/page.jsx` is a server component that parses URL search params, calls 7+ data functions, and passes pre-filtered results to client components. `filter-bar.jsx` calls `router.push()` on every filter change, triggering a full server re-render.

### New Design

**Server component (`app/page.jsx`):**
- Calls `getEnrichedLeaderboard()` (hits cache on warm requests)
- Builds filter option lists from the dataset (unique belts, weight classes, academies)
- Resolves recent activity competitor names via a single `Map` lookup (replacing the sequential `getCompetitorById` loop)
- Passes the full dataset + filter options + activity feed as props to a new client component

**Client payload shape:**

```js
{
  // Full enriched competitor array (~1000+ items, each ~20 fields)
  competitors: [
    {
      id, name, academy, belt, ageDivision, ageGroup, gender, weightClass,
      wins, losses, winRate, goldMedals, totalMedals, podiumRate, champRate,
      avgWfm, totalEntries, rankChange
    },
    ...
  ],

  // Entries grouped by competitor ID for type/competition scoping
  // Shape matches server-side mapEntry() output (subset) so computeStatsFromEntries() works unchanged
  entryIndex: {
    "competitor-id": [
      { type, competitionId, wins, losses, podium, champion, medals: { gold, silver, bronze }, wfm },
      ...
    ],
    ...
  },

  // Filter options
  filterOptions: {
    belts: ["white", "grey", "yellow", ...],
    weightClasses: ["-45 lbs", "-50 lbs", ...],
    academies: ["Easton Training Center - Arvada", ...],
    competitions: [{ id, name, date }, ...],
  },

  // Pre-resolved activity feed (10 items)
  recentActivity: [
    { id, competitorId, competitorName, wins, losses, medals, competitionName, champion, date },
    ...
  ],

  // Global stats (unfiltered)
  globalStats: { totalCompetitors, totalEntries, totalMedals, totalGoldMedals },
}
```

The `entryIndex` is included so the client can recompute stats when type or competition filters are applied. The entry shape preserves the nested `medals` object from the server-side `mapEntry()` so that the shared `computeStatsFromEntries()` function (extracted to `lib/stats.js`) works identically on both server and client without adaptation. Each entry is trimmed to only the fields needed for stat computation (~10 fields instead of ~15). At 1000 competitors with ~5 entries each, this adds ~200KB raw, ~40KB gzipped.

**Client component (`components/dashboard.jsx`):**
- Receives the payload above as props
- Manages filter state via `useState`, initialized from `useSearchParams()` on mount
- Filters, sorts, and paginates data using `useMemo` keyed on the filter state
- When type or competition filters are active, recomputes per-competitor stats from `entryIndex` using the shared `computeStatsFromEntries()` function (extracted to `lib/stats.js` for use by both server and client) and filters out competitors with zero entries
- When only belt/weight/academy filters are active, filters the pre-computed `competitors` array directly (no stat recomputation needed)
- Renders podium (only when no filters are active, slicing top 3 and passing remainder to table with `rankOffset = 3`), stat cards, leaderboard table, activity feed, and filter bar
- Filter bar fires callbacks; `dashboard.jsx` updates state and syncs the URL via `window.history.replaceState()`

**URL param sync pattern:**

`window.history.replaceState()` does not trigger React re-renders or update Next.js's `useSearchParams()` hook. Therefore, `useState` is the source of truth for rendering, and `replaceState` is a side effect for URL shareability only.

Since `replaceState` (not `pushState`) is used, no browser history entries are created -- the back button navigates away from the page entirely, not to a previous filter state. This avoids the stale-closure issue with `useSearchParams()` mirrors.

```js
const searchParams = useSearchParams()

// useState is the rendering source of truth; initialized from URL on mount
const [filters, setFilters] = useState({
  belt: searchParams.get('belt') || 'all',
  type: searchParams.get('type') || 'all',
  weight: searchParams.get('weight') || 'all',
  competition: searchParams.get('competition') || 'all',
  academy: searchParams.get('academy') || 'all',
})

// Update state (triggers re-render) + sync URL (for shareability)
function updateFilter(key, value) {
  setFilters(prev => ({ ...prev, [key]: value }))

  const params = new URLSearchParams(window.location.search)
  if (value === 'all') params.delete(key)
  else params.set(key, value)
  const qs = params.toString()
  window.history.replaceState(null, '', qs ? `/?${qs}` : '/')
}
```

Users landing on a shared URL (e.g., `/?belt=grey&type=nogi`) get the server-rendered page with the full dataset. The client component initializes filter state from the URL params on mount, showing the correct filtered view immediately.

### Rank Changes Under Filters

Rank changes (`rankChange` field) are pre-computed server-side for the default unfiltered sort order. This answers "how has this competitor's overall ranking changed since their last competition" -- a global metric independent of the current filter state.

When filters are applied client-side, rank change values remain the same. This is intentional: a competitor's rank delta is a measure of their overall trajectory, not their position within an arbitrary filter subset. Re-computing rank changes per filter combination would be confusing (a competitor could show "+5" under one filter and "-2" under another for the same time period).

### Server-Side `sortBy` Parameter

The current `getLeaderboard(filters, sortBy)` accepts a `sortBy` parameter for primary sort. This is intentionally dropped. The client-side `LeaderboardTable` already has its own sort logic (column header clicks). The server returns competitors in a default sort order; the client re-sorts as needed.

**What gets removed from `page.jsx`:**
- All filter parsing and conditional logic
- The `getCompetitors()` call for filter option lists
- The `getAcademies()` standalone call
- The sequential `getCompetitorById` loop for the activity feed
- Conditional podium vs filtered table slicing

---

## Section 3: Profile Pages -- Static Generation + Prefetching

### Current State

`app/competitor/[id]/page.jsx` is a server component that makes 3 sequential calls on every visit: `getCompetitorById`, `getEntriesByCompetitor`, `getPeerAverages`. No prefetching -- the leaderboard table uses `router.push()` instead of `<Link>`.

### New Design

**Static generation with ISR:**
- Add `generateStaticParams()` returning an empty array. With `dynamicParams = true` (the default), profile pages are generated on-demand on first visit and cached. This avoids building all 1000+ pages at build time.
- Keep `revalidate = 3600` for ISR regeneration
- On first visit, the page renders server-side using the `'use cache'` layer (no Supabase calls on cache hit) and gets stored as static HTML
- Subsequent visits within the revalidation window serve cached HTML (from Vercel's CDN on Vercel deployments, or from the Node.js server cache otherwise)

```js
export async function generateStaticParams() {
  return []  // All pages generated on-demand via dynamicParams = true
}
```

**Prefetching via `<Link>` in the leaderboard table:**

Replace `router.push()` with a `<Link>` in the name column for prefetching, plus a row-level click handler for full-row interactivity:

```jsx
<tr onClick={(e) => {
  if (e.target.closest('a')) return
  router.push(`/competitor/${competitor.id}`)
}}>
  <td>
    <Link href={`/competitor/${competitor.id}`} prefetch>
      {competitor.name}
    </Link>
  </td>
  ...
</tr>
```

Next.js prefetches `<Link>` targets when they enter the viewport. By the time the user clicks, the RSC payload is already in the browser's router cache.

**Profile data calls:**
All three functions (`getCompetitorById`, `getEntriesByCompetitor`, `getPeerAverages`) derive from the `'use cache'` layer. On cache hits, zero Supabase calls.

---

## Section 4: Sync Route Integration

### Current State

`/api/sync/route.js` calls `revalidatePath('/')` and `revalidatePath('/competitor/[id]')` after upserting data.

### Changes

Add `revalidateTag("leaderboard")` to invalidate the `'use cache'` entries from the data layer. Keep existing `revalidatePath` calls.

After a sync:
1. `revalidateTag("leaderboard")` busts the data layer cache (next request rebuilds from Supabase)
2. `revalidatePath('/')` busts the dashboard ISR page
3. `revalidatePath('/competitor/[id]')` busts profile ISR pages

---

## Section 5: What Stays the Same

- Supabase schema, tables, RLS policies
- Sync job logic (Sheets fetch, transform, upsert)
- Visual components (podium, stat cards, belt badges, radar chart, match timeline)
- `lib/supabase.js` client singleton
- PostHog analytics
- Theme system
- `lib/data/transform.js` and `lib/data/sheets.js`

---

## Files Modified

| File | Change |
|------|--------|
| `next.config.mjs` | Enable `cacheComponents: true` (top-level, required for `'use cache'`) |
| `lib/stats.js` | **New** -- extract `computeStatsFromEntries()` from `lib/data/index.js` so it can be imported by both server (`index.js`) and client (`dashboard.jsx`) code |
| `lib/data/index.js` | Replace request-scoped cache with `'use cache'` directive; add `getEnrichedLeaderboard()`; remove `resetRequestCache()`, `getCachedCompetitors()`, `getCachedEntries()`, standalone `getAcademies()` query; import `computeStatsFromEntries` from `lib/stats.js` |
| `app/page.jsx` | Simplify to fetch full dataset via cached layer, delegate to client component |
| `components/dashboard.jsx` | **New** -- client component with filtering, sorting, pagination, URL sync |
| `components/filter-bar.jsx` | Update to accept filter callbacks from `dashboard.jsx` instead of using `router.push()` |
| `components/leaderboard-table.jsx` | Add `<Link>` in name column for prefetching; keep row click handler for full-row interactivity |
| `app/competitor/[id]/page.jsx` | Add `generateStaticParams()` (returns empty array); data calls use cached layer |
| `app/api/sync/route.js` | Add `revalidateTag("leaderboard")` after upsert |

**Components with unchanged interfaces but noted for awareness:**
- `components/podium.jsx` -- `dashboard.jsx` must replicate the guard that only renders podium when no filters are active and passes exactly 3 items
- `components/activity-feed.jsx` -- data shape unchanged; receives pre-resolved rows from server
- `components/stat-card.jsx` -- interface unchanged; stat values now computed from filtered client data

---

## Expected Performance Impact

| Interaction | Current | After |
|-------------|---------|-------|
| Filter change | 2-5s (server round-trip) | <16ms (client-side JS) |
| Profile click | 1-3s (server render + Supabase) | <100ms (prefetched static page) |
| Initial page load | 2-4s (7+ Supabase calls) | 500ms-1s (3 cached calls via Promise.all + JSON payload) |
| Repeat page load within hour | Same as initial | <200ms (ISR cached HTML) |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Dataset grows beyond client-side payload budget | At 1000+ competitors with entries, ~80KB gzipped. Budget is ~500KB. Monitor payload size; add server-side pagination if dataset reaches 5000+ competitors. Consider `useDeferredValue` for filter responsiveness at large scale. |
| URL params out of sync with client state on back/forward | `useState` is the rendering source of truth, initialized from `useSearchParams()` on mount. `replaceState` (not `pushState`) avoids creating history entries -- back button navigates away from the page, not to a previous filter state. |
| `generateStaticParams` build time | Returns empty array; all pages generated on-demand via `dynamicParams = true`. Zero build-time cost. |
| `'use cache'` is relatively new in Next.js 16 | The directive is the official replacement for `unstable_cache` and is documented as stable. Tag-based revalidation uses the same `revalidateTag()` API. |
| Malformed URL params (e.g., `?belt=invalid`) | Client filters against the known options list; an unrecognized value matches nothing, which renders the empty state. Functionally equivalent to "no results." |

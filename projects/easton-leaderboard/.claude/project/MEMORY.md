# LESSONS.md

Design principles and patterns captured from past corrections and debugging sessions.

---

## Latency Is a Feature -- Always Cache at the Serving Layer

**Date:** 2026-03-24
**Context:** Migrated the leaderboard from an in-memory Google Sheets cache to Supabase (Postgres via PostgREST). The original code fetched all data once and cached it in module scope. The new code made independent Supabase HTTP calls from every exported function -- ~31 round-trips per page load. Each round-trip adds ~50-200ms of network latency. The page took multiple seconds to render and filter interactions froze the UI entirely.

**Root cause:** Treated the database migration as a 1:1 function rewrite without considering that the original architecture had implicit batching (one fetch, many reads from memory). The new architecture replaced fast memory reads with slow HTTP calls without adding any caching layer.

**What was missing:**

1. **Request-scoped caching** -- Multiple functions in the data layer (`getLeaderboard`, `getStats`, `getCompetitorById` x10 for activity feed, `getPeerAverages`) all independently fetched the same competitors and entries tables. A module-scope cache that persists within a single server render eliminates duplicate calls, reducing ~31 round-trips to ~3.
2. **`useTransition` on navigation** -- `router.push()` in filter bar components triggers a full server re-render. Without `useTransition`, React blocks the UI during the navigation, making buttons and dropdowns unresponsive. Wrapping `router.push()` in `startTransition()` keeps the current UI interactive while the new page renders in the background.
3. **Cache invalidation** -- Module-scope caches in serverless environments persist across requests within the same warm lambda. Without explicit `resetRequestCache()` at the start of each page render, a second request could serve stale data from a previous request.

**Rules:**

1. When migrating from in-memory data to a remote database, the first question is: "How many network round-trips does a single page render make?" Count them. If it is more than 3-5, add request-scoped caching so functions that read the same tables share a single fetch.
2. Never use bare `router.push()` for filter/sort interactions. Always wrap in `startTransition()` so the UI remains responsive during server re-renders. Add `isPending` visual feedback so the user knows the app is working.
3. User-perceived latency is not optional. A page that loads in 5 seconds instead of 200ms is a broken page, regardless of whether the data is "correct." Performance regressions are bugs, not trade-offs.
4. Test latency, not just correctness. After any data layer migration, open the page in a browser with DevTools Network tab and count requests and measure total load time.

**Update (2026-03-25):** The request-scoped cache and `useTransition` approach from v0.2.0 was itself a half-measure. The correct architecture for data that changes hourly is to treat it as static between sync intervals: cache the entire dataset at the framework level (`'use cache'` with `cacheLife('hours')`), move filtering to the client, and use `<Link prefetch>` for navigation. This reduced the data layer from 3-5 Supabase calls per render to 1 cached call, and eliminated server round-trips for filtering entirely. See v0.3.0 changelog.

---

## Next.js 16 cacheComponents Constraints

**Date:** 2026-03-25
**Context:** Enabling `cacheComponents: true` in `next.config.mjs` to support the `'use cache'` directive introduced three build errors that are not well-documented:

1. **`export const revalidate` is incompatible with `cacheComponents`.** The build fails with a clear error. Fix: remove the export and use `cacheLife()` inside cached functions instead.
2. **`generateStaticParams()` must return at least one result.** With `cacheComponents`, an empty array from `generateStaticParams` causes a build error. If you cannot enumerate all IDs at build time, remove `generateStaticParams` entirely and let the framework handle dynamic rendering.
3. **`await params` counts as uncached data access.** In a page component, `const { id } = await props.params` is treated as dynamic data access. If the page wraps its content in `<Suspense>`, the `await` must happen inside the Suspense boundary, not in the page wrapper. The fix: make the page export non-async, pass `props.params` (the Promise) into the async inner component, and `await` it there.

**Rules:**

1. When enabling `cacheComponents`, run `npm run build` immediately and fix errors iteratively. Do not assume existing page-level caching patterns (`revalidate`, `generateStaticParams`) will survive.
2. For dynamic routes with `cacheComponents`, always split into a non-async wrapper (provides Suspense) and an async inner component (awaits params and fetches data). The wrapper must not `await` anything.
3. Use `next build --debug-prerender` to get precise stack traces when the standard error message only points to layout-level components.

---

## Supabase Default Row Limit Applies to Every Query

**Date:** 2026-04-12
**Context:** After adding pagination to `fetchAllEntries()` to fix the 1000-row cap, the same fix was not applied to `fetchCompetitorsWithOverrides()` or `fetchAllCompetitions()`. Supabase's PostgREST layer silently returns only the first 1000 rows on any `.select()` call without an explicit `.range()`. The entries fix worked correctly, but the identical problem remained in the other two queries because each was fixed independently rather than auditing all queries at once.

**Root cause:** Treating the pagination fix as a single-function problem instead of auditing every Supabase `.select()` in the codebase. When one query hits the limit, all queries that could grow beyond 1000 rows are equally vulnerable.

**Rules:**

1. Every Supabase `.select()` that returns a variable number of rows must use pagination with `.range()` and a while loop. There are no exceptions -- even tables that "probably" won't exceed 1000 rows today will grow.
2. When fixing a row-limit bug in one query, audit every other `.select()` in the same file and any other files in the data layer. The fix is never local.
3. The default Supabase row limit (1000) is silent -- no error, no warning. The only symptom is missing data. Always test with production-scale data counts, not dev fixtures.

---

## Linear Normalization Breaks Cross-Group Comparability

**Date:** 2026-04-12
**Context:** The initial ERP implementation used linear normalization (`1 + (points / maxPoints) * 9`) to map total points to a 1-10 scale. This meant one dominant competitor anchored the scale at 10.0, compressing everyone else. A 7.0 at one academy had no relation to a 7.0 at another because the denominators differed. The metric also rewarded volume (more entries = more points) without accounting for efficiency.

**Root cause:** Linear normalization against a single metric (total points) is sensitive to outliers and rewards one dimension (volume) disproportionately. It is not comparable across subgroups with different distributions.

**Fix:** Replaced with percentile-based composite scoring across 4 metrics (points-per-entry, win rate, podium rate, total points). Percentile ranks are naturally comparable across groups because they measure relative standing on multiple axes. A minimum entry threshold (3) prevents meaningless rates from distorting rankings.

**Rules:**

1. When a rating needs to be comparable across independent groups (academies, belt levels, age groups), use percentile-based or z-score-based normalization rather than linear min/max normalization.
2. Composite scores should blend rate metrics (efficiency) with volume metrics (activity) to avoid rewarding either dimension exclusively.
3. Any rate-based metric (win rate, podium rate) needs a minimum sample size to be meaningful. Define the threshold upfront.

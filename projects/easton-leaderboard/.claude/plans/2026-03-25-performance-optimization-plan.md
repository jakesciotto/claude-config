# Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate server round-trips from filtering and profile navigation by caching the data layer with `'use cache'`, moving filtering to the client, and prefetching profile pages.

**Architecture:** Server fetches all data once per cache interval (hourly), ships the full enriched dataset to a client component that handles filtering/sorting/pagination in pure JS. Profile pages use `generateStaticParams()` + ISR for on-demand static generation, with `<Link>` prefetching in the leaderboard table.

**Tech Stack:** Next.js 16 (`'use cache'` directive, `cacheTag`, `cacheLife`), React 19 (`useSearchParams`, `useMemo`), Supabase (unchanged)

**Spec:** `docs/plans/2026-03-25-performance-optimization-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `next.config.mjs` | Modify | Enable `cacheComponents: true` |
| `lib/stats.js` | Create | Shared `computeStatsFromEntries()` + `buildStatsMap()` for server and client |
| `lib/data/index.js` | Rewrite | `'use cache'`-backed data layer with `getEnrichedLeaderboard()` |
| `app/page.jsx` | Rewrite | Thin server shell: fetch cached data, build payload, render `<Dashboard>` |
| `components/dashboard.jsx` | Create | Client component: filtering, sorting, pagination, URL sync |
| `components/filter-bar.jsx` | Modify | Accept callbacks + filter values as props instead of `router.push()` |
| `components/leaderboard-table.jsx` | Modify | Add `<Link>` prefetching in name column |
| `app/competitor/[id]/page.jsx` | Modify | Add `generateStaticParams()`, remove `resetRequestCache()` (done in Task 3) |
| `app/api/sync/route.js` | Modify | Add `revalidateTag("leaderboard")` |

---

### Task 1: Enable Cache Components

**Files:**
- Modify: `next.config.mjs`

- [ ] **Step 1: Add `cacheComponents: true` to Next.js config**

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  cacheComponents: true,
};

export default nextConfig;
```

- [ ] **Step 2: Verify dev server starts**

Run: `npm run dev`
Expected: Server starts without errors. No behavioral changes yet.

- [ ] **Step 3: Commit**

```bash
git add next.config.mjs
git commit -m "Enable cacheComponents for use cache directive"
```

---

### Task 2: Extract Shared Stats Utilities

**Files:**
- Create: `lib/stats.js`
- Modify: `lib/data/index.js`

- [ ] **Step 1: Create `lib/stats.js` with `computeStatsFromEntries` and `buildStatsMap`**

Extract these two functions verbatim from `lib/data/index.js` (lines 86-202). No logic changes.

```js
// Shared stats computation -- used by both server (lib/data/index.js)
// and client (components/dashboard.jsx) code.

export function computeStatsFromEntries(competitorEntries) {
  const totalEntries = competitorEntries.length;

  if (totalEntries === 0) {
    return {
      wins: 0,
      losses: 0,
      winRate: 0,
      goldMedals: 0,
      totalMedals: 0,
      podiumRate: 0,
      champRate: 0,
      avgWfm: null,
      totalEntries: 0,
    };
  }

  let wins = 0;
  let losses = 0;
  let goldMedals = 0;
  let totalMedals = 0;
  let podiumCount = 0;
  let champCount = 0;
  let wfmSum = 0;
  let wfmCount = 0;

  for (const entry of competitorEntries) {
    wins += entry.wins;
    losses += entry.losses;
    goldMedals += entry.medals.gold;
    totalMedals += entry.medals.gold + entry.medals.silver + entry.medals.bronze;
    if (entry.podium) podiumCount++;
    if (entry.champion) champCount++;
    if (entry.wfm !== null) {
      wfmSum += entry.wfm;
      wfmCount++;
    }
  }

  const totalRounds = wins + losses;
  const winRate = totalRounds > 0 ? Math.round((wins / totalRounds) * 1000) / 1000 : 0;
  const podiumRate = Math.round((podiumCount / totalEntries) * 1000) / 1000;
  const champRate = Math.round((champCount / totalEntries) * 1000) / 1000;
  const avgWfm = wfmCount > 0 ? Math.round((wfmSum / wfmCount) * 1000) / 1000 : null;

  return {
    wins, losses, winRate, goldMedals, totalMedals,
    podiumRate, champRate, avgWfm, totalEntries,
  };
}

export function buildStatsMap(entries) {
  const grouped = new Map();
  for (const entry of entries) {
    if (!grouped.has(entry.competitorId)) {
      grouped.set(entry.competitorId, []);
    }
    grouped.get(entry.competitorId).push(entry);
  }

  const statsMap = new Map();
  for (const [competitorId, competitorEntries] of grouped) {
    statsMap.set(competitorId, computeStatsFromEntries(competitorEntries));
  }
  return statsMap;
}
```

- [ ] **Step 2: Update `lib/data/index.js` to import from `lib/stats.js`**

Replace the local `computeStatsFromEntries` and `buildStatsMap` function definitions (lines 86-202) with:

```js
import { computeStatsFromEntries, buildStatsMap } from "../stats.js";
```

Remove the deleted function bodies. All other code in `index.js` stays unchanged for now.

- [ ] **Step 3: Verify dev server still works**

Run: `npm run dev`
Expected: Dashboard and profile pages load identically. No behavioral changes -- this is a pure refactor.

- [ ] **Step 4: Commit**

```bash
git add lib/stats.js lib/data/index.js
git commit -m "Extract computeStatsFromEntries and buildStatsMap to shared module"
```

---

### Task 3: Rewrite Data Layer with `'use cache'`

**Files:**
- Modify: `lib/data/index.js`

This is the largest task. Replace the entire request-scoped caching system with a single `'use cache'` function.

- [ ] **Step 1: Rewrite `lib/data/index.js`**

Replace the full file contents. Key changes from current:
- Remove: `_cachedCompetitors`, `_cachedEntries`, `_cachedPeerAverages` module variables
- Remove: `getCachedCompetitors()`, `getCachedEntries()`, `resetRequestCache()`
- Remove: `getAcademies()` standalone Supabase query
- Remove: `getLeaderboard()` (replaced by pre-computed data)
- Remove: `getCompetitors()` (no longer needed)
- Add: `getEnrichedLeaderboard()` with `'use cache'` directive
- Keep: `fetchCompetitorsWithOverrides()` (no filters param -- always fetches all), `fetchAllEntries()`, `mapCompetitor()`, `mapEntry()`, `mapCompetition()`, `computePreviousRanks()`
- Change: `getCompetitorById()`, `getEntriesByCompetitor()`, `getCompetitions()`, `getPeerAverages()`, `getStats()` all derive from `getEnrichedLeaderboard()`

```js
// Data Access Layer for Easton BJJ Competition Leaderboard
// Queries Supabase (Postgres) for all data. Stats are computed from entry rows.
// Uses Next.js 'use cache' directive for hourly caching with tag-based invalidation.
// All functions are async. Components should only import from this file.

import { cacheLife, cacheTag } from "next/cache";
import { getSupabase } from "../supabase.js";
import { computeStatsFromEntries, buildStatsMap } from "../stats.js";

// -- Column mapping helpers (snake_case -> camelCase) --

function mapCompetitor(row) {
  return {
    id: row.id,
    name: row.name,
    academy: row.academy,
    belt: row.belt,
    ageDivision: row.age_division,
    ageGroup: row.age_group,
    gender: row.gender,
    weightClass: row.weight_class,
  };
}

function mapEntry(row) {
  return {
    id: row.id,
    competitorId: row.competitor_id,
    competitionId: row.competition_id,
    date: row.date,
    competitionName: row.competition_name,
    type: row.type,
    division: row.division,
    bracketType: row.bracket_type,
    rounds: row.rounds,
    wins: row.wins,
    losses: row.losses,
    placement: row.placement,
    podium: row.podium,
    champion: row.champion,
    medals: { gold: row.gold, silver: row.silver, bronze: row.bronze },
    wfm: row.wfm !== null ? parseFloat(row.wfm) : null,
  };
}

function mapCompetition(row) {
  return {
    id: row.id,
    name: row.name,
    date: row.date,
    spreadsheetId: row.spreadsheet_id,
  };
}

// -- Fetch functions (raw Supabase queries) --

async function fetchCompetitorsWithOverrides(supabase) {
  const { data, error } = await supabase
    .from("competitors")
    .select(`
      id, name, academy, belt, age_division, age_group, gender, weight_class,
      overrides (belt, age_division, age_group, gender, weight_class)
    `);
  if (error) throw new Error(`Failed to fetch competitors: ${error.message}`);

  return data.map((row) => {
    const o = Array.isArray(row.overrides) ? row.overrides[0] : row.overrides;
    return mapCompetitor({
      ...row,
      belt: o?.belt || row.belt,
      age_division: o?.age_division || row.age_division,
      age_group: o?.age_group || row.age_group,
      gender: o?.gender || row.gender,
      weight_class: o?.weight_class || row.weight_class,
    });
  });
}

async function fetchAllEntries(supabase) {
  const { data, error } = await supabase
    .from("entries")
    .select("*")
    .order("date", { ascending: false });
  if (error) throw new Error(`Failed to fetch entries: ${error.message}`);
  return data.map(mapEntry);
}

async function fetchAllCompetitions(supabase) {
  const { data, error } = await supabase
    .from("competitions")
    .select("*")
    .order("date", { ascending: true });
  if (error) throw new Error(`Failed to fetch competitions: ${error.message}`);
  return data.map(mapCompetition);
}

// -- Rank change computation --

function computePreviousRanks(competitors, allEntries) {
  const prevStats = competitors.map((c) => {
    const competitorEntries = allEntries
      .filter((e) => e.competitorId === c.id)
      .sort((a, b) => b.date.localeCompare(a.date));

    if (competitorEntries.length === 0) {
      return { id: c.id, wins: 0, winRate: 0 };
    }

    const mostRecentDate = competitorEntries[0].date;
    const previousEntries = competitorEntries.filter(
      (e) => e.date !== mostRecentDate
    );

    const wins = previousEntries.reduce((sum, e) => sum + e.wins, 0);
    const losses = previousEntries.reduce((sum, e) => sum + e.losses, 0);
    const totalRounds = wins + losses;
    const winRate =
      totalRounds > 0 ? Math.round((wins / totalRounds) * 1000) / 1000 : 0;

    return { id: c.id, wins, winRate };
  });

  prevStats.sort((a, b) => {
    const primary = b.wins - a.wins;
    if (primary !== 0) return primary;
    return b.winRate - a.winRate;
  });

  const map = new Map();
  prevStats.forEach((entry, index) => {
    map.set(entry.id, index + 1);
  });
  return map;
}

// -- Core cached function --
// Fetches all data from Supabase, computes stats and rank changes.
// Cached for 1 hour; invalidated via revalidateTag("leaderboard") in sync route.

export async function getEnrichedLeaderboard() {
  "use cache";
  cacheLife("hours");
  cacheTag("leaderboard");

  const supabase = getSupabase();
  const [competitors, entries, competitions] = await Promise.all([
    fetchCompetitorsWithOverrides(supabase),
    fetchAllEntries(supabase),
    fetchAllCompetitions(supabase),
  ]);

  // Enrich competitors with stats
  const statsMap = buildStatsMap(entries);
  const enriched = competitors.map((c) => ({
    ...c,
    ...(statsMap.get(c.id) || computeStatsFromEntries([])),
  }));

  // Sort by wins (default), then win rate tiebreaker
  enriched.sort((a, b) => {
    const primary = b.wins - a.wins;
    if (primary !== 0) return primary;
    return b.winRate - a.winRate;
  });

  // Compute rank changes for the default unfiltered sort
  const prevRanks = computePreviousRanks(enriched, entries);
  const ranked = enriched.map((competitor, index) => {
    const currentRank = index + 1;
    const previousRank = prevRanks.get(competitor.id) || currentRank;
    return { ...competitor, rankChange: previousRank - currentRank };
  });

  return { competitors: ranked, entries, competitions };
}

// -- Public API (all derived from the cached dataset) --

export async function getCompetitorById(id) {
  const { competitors, entries } = await getEnrichedLeaderboard();
  const competitor = competitors.find((c) => c.id === id);
  if (!competitor) return null;

  const competitorEntries = entries.filter((e) => e.competitorId === id);
  return { ...competitor, ...computeStatsFromEntries(competitorEntries) };
}

export async function getEntriesByCompetitor(competitorId) {
  const { entries } = await getEnrichedLeaderboard();
  return entries.filter((e) => e.competitorId === competitorId);
}

export async function getCompetitions() {
  const { competitions } = await getEnrichedLeaderboard();
  return competitions;
}

export async function getStats() {
  const { competitors, entries } = await getEnrichedLeaderboard();

  let totalMedals = 0;
  let totalGoldMedals = 0;
  for (const entry of entries) {
    totalMedals += entry.medals.gold + entry.medals.silver + entry.medals.bronze;
    totalGoldMedals += entry.medals.gold;
  }

  return {
    totalCompetitors: competitors.length,
    totalEntries: entries.length,
    totalMedals,
    totalGoldMedals,
  };
}

export async function getPeerAverages(ageGroup, belt) {
  const { competitors, entries } = await getEnrichedLeaderboard();

  const peers = competitors.filter(
    (c) => c.ageGroup === ageGroup && c.belt === belt
  );

  if (peers.length === 0) {
    return {
      winRate: 0, podiumRate: 0, champRate: 0,
      totalMedals: 0, competitionCount: 0, avgWfm: 0,
    };
  }

  const peerIds = new Set(peers.map((p) => p.id));
  const peerEntries = entries.filter((e) => peerIds.has(e.competitorId));
  const peerStatsMap = buildStatsMap(peerEntries);
  const peerStats = peers.map(
    (p) => peerStatsMap.get(p.id) || computeStatsFromEntries([])
  );

  const count = peerStats.length;
  const avg = (arr, fn) =>
    Math.round((arr.reduce((s, x) => s + fn(x), 0) / count) * 1000) / 1000;

  return {
    winRate: avg(peerStats, (s) => s.winRate),
    podiumRate: avg(peerStats, (s) => s.podiumRate),
    champRate: avg(peerStats, (s) => s.champRate),
    totalMedals: avg(peerStats, (s) => s.totalMedals),
    competitionCount: avg(peerStats, (s) => s.totalEntries),
    avgWfm: avg(peerStats, (s) => s.avgWfm || 0),
  };
}
```

- [ ] **Step 2: Update `app/competitor/[id]/page.jsx` to remove `resetRequestCache`**

The profile page still imports `resetRequestCache` from `@/lib/data`, which no longer exists. Fix it now to avoid a broken intermediate state.

Change the import at the top:

```js
import {
  getCompetitorById,
  getEntriesByCompetitor,
  getPeerAverages,
} from "@/lib/data";
```

(Remove `resetRequestCache` from the import.)

Remove the `resetRequestCache()` call from the `CompetitorProfilePage` function body (line 57 of the current file).

Add `generateStaticParams` below the `revalidate` export:

```js
export async function generateStaticParams() {
  return [];
}
```

- [ ] **Step 3: Verify the profile page still loads**

Run: `npm run dev`
Navigate to a known competitor profile (e.g., `/competitor/nash-caley-arvada` or any ID from the database).
Expected: Profile page renders with stats, entries, radar chart, and timeline.

Note: The dashboard (`/`) will break at this point because it still imports `resetRequestCache`, `getLeaderboard`, `getAcademies`, and `getCompetitors` which no longer exist. This is expected -- Task 8 will fix it.

- [ ] **Step 4: Commit**

```bash
git add lib/data/index.js app/competitor/[id]/page.jsx
git commit -m "Replace request-scoped cache with use cache directive in data layer"
```

---

### Task 4: Update Sync Route with `revalidateTag`

**Files:**
- Modify: `app/api/sync/route.js`

- [ ] **Step 1: Add `revalidateTag` import and call**

At the top of the file, add `revalidateTag` to the import:

```js
import { revalidatePath, revalidateTag } from "next/cache";
```

After the existing `revalidatePath` calls (line 108-109), add:

```js
revalidateTag("leaderboard");
```

- [ ] **Step 2: Commit**

```bash
git add app/api/sync/route.js
git commit -m "Add revalidateTag to sync route for use cache invalidation"
```

---

### Task 5: Update Filter Bar to Accept Callbacks

**Files:**
- Modify: `components/filter-bar.jsx`

- [ ] **Step 1: Rewrite `filter-bar.jsx` to accept filter values and callbacks as props**

Remove `useSearchParams`, `useRouter`, `useTransition`. The component becomes a controlled component driven by its parent.

```jsx
"use client";

import { Button } from "@/components/ui/button";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { formatAcademy } from "@/lib/utils";

const TYPE_OPTIONS = [
  { label: "All", value: "all" },
  { label: "Gi", value: "gi" },
  { label: "Nogi", value: "nogi" },
];

function capitalize(text) {
  if (!text) return "";
  return text.charAt(0).toUpperCase() + text.slice(1);
}

export function FilterBar({
  filters,
  onFilterChange,
  onClear,
  academies,
  competitions,
  weightClasses,
  belts,
}) {
  const hasActiveFilters =
    filters.type !== "all" ||
    filters.belt !== "all" ||
    filters.weight !== "all" ||
    filters.competition !== "all" ||
    filters.academy !== "all";

  return (
    <div className="flex flex-wrap items-center gap-2 md:gap-3">
      {/* Type Toggle (Gi / Nogi) */}
      <div className="flex gap-1">
        {TYPE_OPTIONS.map((t) => (
          <Button
            key={t.value}
            variant={filters.type === t.value ? "default" : "outline"}
            size="sm"
            className="transition-all duration-150"
            onClick={() => onFilterChange("type", t.value)}
          >
            {t.label}
          </Button>
        ))}
      </div>

      {/* Belt Select */}
      <Select
        value={filters.belt}
        onValueChange={(value) => onFilterChange("belt", value)}
      >
        <SelectTrigger className="min-w-0 w-full sm:w-[140px]">
          <SelectValue placeholder="Belt" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All Belts</SelectItem>
          {belts.map((b) => (
            <SelectItem key={b} value={b}>
              {capitalize(b)}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      {/* Weight Class Select */}
      <Select
        value={filters.weight}
        onValueChange={(value) => onFilterChange("weight", value)}
      >
        <SelectTrigger className="min-w-0 w-full sm:w-[160px]">
          <SelectValue placeholder="Weight Class" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All Weights</SelectItem>
          {weightClasses.map((w) => (
            <SelectItem key={w} value={w}>
              {w}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      {/* Competition Select */}
      <Select
        value={filters.competition}
        onValueChange={(value) => onFilterChange("competition", value)}
      >
        <SelectTrigger className="min-w-0 w-full sm:w-[240px]">
          <SelectValue placeholder="Competition" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All Competitions</SelectItem>
          {competitions.map((c) => (
            <SelectItem key={c.id} value={c.id}>
              {c.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      {/* Academy Select */}
      <Select
        value={filters.academy}
        onValueChange={(value) => onFilterChange("academy", value)}
      >
        <SelectTrigger className="min-w-0 w-full sm:w-[220px]">
          <SelectValue placeholder="Academy" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All Academies</SelectItem>
          {academies.map((a) => (
            <SelectItem key={a} value={a}>
              {formatAcademy(a)}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      {/* Clear Filters */}
      {hasActiveFilters && (
        <Button
          variant="ghost"
          size="sm"
          className="transition-all duration-150"
          onClick={onClear}
        >
          Clear filters
        </Button>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add components/filter-bar.jsx
git commit -m "Update FilterBar to accept filter values and callbacks as props"
```

---

### Task 6: Add Link Prefetching to Leaderboard Table

**Files:**
- Modify: `components/leaderboard-table.jsx`

- [ ] **Step 1: Add `Link` import and update the name cell + row click**

Add at the top, alongside existing imports:

```js
import Link from "next/link";
```

Replace the `<tr>` `onClick` (line 141) with a guarded version that defers to the `<Link>`:

```jsx
onClick={(e) => {
  if (e.target.closest("a")) return;
  router.push(`/competitor/${competitor.id}`);
}}
```

Replace the name `<td>` content (lines 161-163) with a `<Link>`:

```jsx
<td className="px-3 py-3 md:px-6 md:py-4 text-sm font-medium text-[var(--text-primary)]">
  <Link
    href={`/competitor/${competitor.id}`}
    prefetch
    className="hover:underline"
    onClick={(e) => e.stopPropagation()}
  >
    {competitor.name}
  </Link>
</td>
```

- [ ] **Step 2: Commit**

```bash
git add components/leaderboard-table.jsx
git commit -m "Add Link prefetching to leaderboard table name column"
```

---

### Task 7: Create Dashboard Client Component

**Files:**
- Create: `components/dashboard.jsx`

This is the core client component that handles all filtering, sorting, and rendering.

- [ ] **Step 1: Create `components/dashboard.jsx`**

```jsx
"use client";

import { useState, useMemo } from "react";
import { useSearchParams } from "next/navigation";
import { computeStatsFromEntries, buildStatsMap } from "@/lib/stats";
import { StatCard } from "@/components/stat-card";
import { ActivityFeed } from "@/components/activity-feed";
import { FilterBar } from "@/components/filter-bar";
import { LeaderboardTable } from "@/components/leaderboard-table";
import { Podium } from "@/components/podium";
import { Users, Trophy, Medal } from "lucide-react";

const DEFAULT_FILTERS = {
  belt: "all",
  type: "all",
  weight: "all",
  competition: "all",
  academy: "all",
};

function syncFiltersToUrl(filters) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(filters)) {
    if (value !== "all") params.set(key, value);
  }
  const qs = params.toString();
  window.history.replaceState(null, "", qs ? `/?${qs}` : "/");
}

export function Dashboard({
  competitors,
  entryIndex,
  filterOptions,
  recentActivity,
  globalStats,
}) {
  const searchParams = useSearchParams();

  const [filters, setFilters] = useState({
    belt: searchParams.get("belt") || "all",
    type: searchParams.get("type") || "all",
    weight: searchParams.get("weight") || "all",
    competition: searchParams.get("competition") || "all",
    academy: searchParams.get("academy") || "all",
  });

  function updateFilter(key, value) {
    const next = { ...filters, [key]: value };
    setFilters((prev) => ({ ...prev, [key]: value }));
    syncFiltersToUrl(next);
  }

  function clearFilters() {
    setFilters({ ...DEFAULT_FILTERS });
    syncFiltersToUrl(DEFAULT_FILTERS);
  }

  const hasActiveFilters = Object.values(filters).some((v) => v !== "all");

  // Type/competition filters require stat recomputation from entries
  const needsRecompute = filters.type !== "all" || filters.competition !== "all";

  const filteredData = useMemo(() => {
    let result = competitors;

    // Belt filter (matches pre-computed field)
    if (filters.belt !== "all") {
      result = result.filter((c) => c.belt === filters.belt);
    }
    // Weight filter
    if (filters.weight !== "all") {
      result = result.filter((c) => c.weightClass === filters.weight);
    }
    // Academy filter
    if (filters.academy !== "all") {
      result = result.filter((c) => c.academy === filters.academy);
    }

    // Type/competition filters: recompute stats from scoped entries
    if (needsRecompute) {
      result = result.map((c) => {
        const entries = entryIndex[c.id] || [];
        let scoped = entries;
        if (filters.type !== "all") {
          scoped = scoped.filter((e) => e.type === filters.type);
        }
        if (filters.competition !== "all") {
          scoped = scoped.filter((e) => e.competitionId === filters.competition);
        }
        return { ...c, ...computeStatsFromEntries(scoped) };
      });
      // Remove competitors with no entries in the scoped set
      result = result.filter((c) => c.totalEntries > 0);
    }

    return result;
  }, [competitors, entryIndex, filters, needsRecompute]);

  // Stats derived from the filtered set
  const stats = useMemo(() => {
    if (!hasActiveFilters) return globalStats;

    let totalEntries = 0;
    let totalMedals = 0;
    let totalGoldMedals = 0;

    for (const c of filteredData) {
      totalEntries += c.totalEntries;
      totalMedals += c.totalMedals;
      totalGoldMedals += c.goldMedals;
    }

    return {
      totalCompetitors: filteredData.length,
      totalEntries,
      totalMedals,
      totalGoldMedals,
    };
  }, [filteredData, globalStats, hasActiveFilters]);

  // Podium: top 3 when no filters active
  const podiumData = !hasActiveFilters && filteredData.length >= 3
    ? filteredData.slice(0, 3).map(
        ({ id, name, belt, wins, losses, winRate, totalMedals, goldMedals }) => ({
          id, name, belt, wins, losses, winRate, totalMedals, goldMedals,
        })
      )
    : null;

  // Table data: skip top 3 when podium is shown
  const tableOffset = podiumData ? 3 : 0;
  const tableData = filteredData.slice(tableOffset).map(
    ({ id, name, belt, wins, losses, winRate, goldMedals, totalMedals, podiumRate, rankChange }) => ({
      id, name, belt, wins, losses, winRate, goldMedals, totalMedals, podiumRate, rankChange,
    })
  );

  return (
    <div className="space-y-8">
      {/* Stats Row */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard
          label="Total Competitors"
          value={stats.totalCompetitors}
          icon={Users}
          delay={0}
          color="blue"
        />
        <StatCard
          label="Total Entries"
          value={stats.totalEntries}
          icon={Trophy}
          delay={75}
          color="blue"
        />
        <StatCard
          label="Total Medals"
          value={stats.totalMedals}
          icon={Medal}
          delay={150}
          color="amber"
        />
      </div>

      {/* Podium -- only when no filters are active */}
      {podiumData && <Podium competitors={podiumData} />}

      {/* Recent Activity */}
      <ActivityFeed entries={recentActivity} />

      {/* Filters */}
      <FilterBar
        filters={filters}
        onFilterChange={updateFilter}
        onClear={clearFilters}
        academies={filterOptions.academies}
        competitions={filterOptions.competitions}
        weightClasses={filterOptions.weightClasses}
        belts={filterOptions.belts}
      />

      {/* Leaderboard Table */}
      <LeaderboardTable data={tableData} rankOffset={tableOffset} />
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add components/dashboard.jsx
git commit -m "Add Dashboard client component with client-side filtering and URL sync"
```

---

### Task 8: Rewrite Dashboard Server Component

**Files:**
- Modify: `app/page.jsx`

- [ ] **Step 1: Rewrite `app/page.jsx` as a thin server shell**

```jsx
import { Suspense } from "react";
import { getEnrichedLeaderboard, getStats } from "@/lib/data";
import { Dashboard } from "@/components/dashboard";

export const revalidate = 3600;

export default async function Home() {
  const { competitors, entries, competitions } = await getEnrichedLeaderboard();
  const globalStats = await getStats();

  // Build entry index grouped by competitor ID (trimmed for client payload)
  const entryIndex = {};
  for (const entry of entries) {
    if (!entryIndex[entry.competitorId]) {
      entryIndex[entry.competitorId] = [];
    }
    entryIndex[entry.competitorId].push({
      type: entry.type,
      competitionId: entry.competitionId,
      wins: entry.wins,
      losses: entry.losses,
      podium: entry.podium,
      champion: entry.champion,
      medals: entry.medals,
      wfm: entry.wfm,
    });
  }

  // Build filter options from the dataset
  const belts = [...new Set(competitors.map((c) => c.belt).filter(Boolean))];
  const weightClasses = [
    ...new Set(competitors.map((c) => c.weightClass).filter(Boolean)),
  ].sort();
  const academies = [
    ...new Set(competitors.map((c) => c.academy).filter(Boolean)),
  ].sort();

  // Resolve recent activity (last 10 entries with competitor names)
  const competitorMap = new Map(competitors.map((c) => [c.id, c.name]));
  const recentActivity = entries.slice(0, 10).map((entry) => ({
    id: entry.id,
    competitorId: entry.competitorId,
    competitorName: competitorMap.get(entry.competitorId) || "Unknown",
    wins: entry.wins,
    losses: entry.losses,
    medals: entry.medals,
    competitionName: entry.competitionName,
    champion: entry.champion,
    date: entry.date,
  }));

  return (
    <Suspense fallback={null}>
      <Dashboard
        competitors={competitors}
        entryIndex={entryIndex}
        filterOptions={{ belts, weightClasses, academies, competitions }}
        recentActivity={recentActivity}
        globalStats={globalStats}
      />
    </Suspense>
  );
}
```

- [ ] **Step 2: Verify the dashboard loads and filtering works**

Run: `npm run dev`
Navigate to `/`
Expected:
- Stat cards, podium, activity feed, filter bar, and leaderboard table render
- Clicking a filter (e.g., belt dropdown -> "grey") instantly filters the table with no loading spinner or page reload
- URL updates (e.g., `/?belt=grey`) without page navigation
- "Clear filters" resets everything
- Type toggle (All/Gi/Nogi) filters and recomputes stats correctly
- Podium hides when any filter is active
- Clicking a competitor name navigates to their profile

- [ ] **Step 3: Commit**

```bash
git add app/page.jsx
git commit -m "Rewrite dashboard as thin server shell with client-side Dashboard component"
```

---

### Task 9: End-to-End Verification

No file changes. Manual testing to verify the full optimization works.

- [ ] **Step 1: Cold start test**

Stop the dev server. Run `npm run dev`. Open the dashboard.
Expected: Page loads. Check browser DevTools Network tab -- the page should make a single document request, no client-side Supabase calls.

- [ ] **Step 2: Filter interaction test**

Click through all filters: type toggle, belt, weight, competition, academy.
Expected: Each filter applies instantly (no network requests in the Network tab). URL updates in the address bar. "Clear filters" resets to the default view with podium visible.

- [ ] **Step 3: Profile navigation test**

Hover over a competitor name in the table. Wait 1 second.
Expected: A prefetch request appears in the Network tab (RSC payload for the profile page). Click the name.
Expected: Profile page loads near-instantly.

- [ ] **Step 4: Shareable URL test**

Apply filters (e.g., `/?belt=grey&type=nogi`). Copy the URL. Open in a new tab.
Expected: Page loads with the correct filters pre-applied.

- [ ] **Step 5: Build test**

Run: `npm run build`
Expected: Build succeeds with no errors. Dashboard and profile pages are listed as static/ISR routes.

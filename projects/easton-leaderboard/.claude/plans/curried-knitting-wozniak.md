# Plan: Merge Competitors Who Changed Academies

## Context

Competitor IDs are `kebab-case(name + academy)` (e.g., `vesper-ortega-arvada`). When a kid transfers academies, a new competitor record is created, fragmenting their history across multiple leaderboard entries. The user reported "Vesper Ortega" appearing 4 times -- once per academy they competed under.

The fix: change the competitor ID to be name-only, so all entries for the same person merge regardless of which academy they were at when they competed. Academy becomes a mutable field that reflects their most recent school.

Name collisions across 8 Colorado academies in a kids BJJ league are unlikely. If one occurs, the user can disambiguate via the existing overrides table or by adjusting names in the source sheet.

## Files to Modify

### 1. `lib/data/transform.js` -- Name-only competitor ID

**`makeCompetitorId()` (line 71)**: Drop the `location` parameter. The function becomes:
```js
function makeCompetitorId(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}
```

**`transformSheetData()` (line 261)**: Change the call from `makeCompetitorId(parsed.name, parsed.academyShort)` to `makeCompetitorId(parsed.name)`.

The existing dedup logic already handles the rest correctly -- sheets are processed in date order, and the code updates academy/belt/ageGroup/etc. to the most recent value. With name-only IDs, a competitor seen at Arvada in 2023 and Boulder in 2024 will now merge into one record with academy = Boulder.

### 2. `app/api/sync/route.js` -- Clean up orphaned competitors

After all upserts complete, the database will contain old academy-suffixed competitor records (e.g., `vesper-ortega-arvada`, `vesper-ortega-boulder`) that no longer have entries pointing to them (since entries are deleted and re-inserted with new name-only competitor IDs on each sync).

Add a cleanup step after the entry upserts:
1. Collect all new competitor IDs into a Set from the `competitors` array
2. Fetch all existing competitor IDs from Supabase
3. Delete any competitor whose ID is not in the new set

### 3. `lib/data/index.js` -- Graceful fallback for old profile URLs

In `getCompetitorById()`, if the exact ID isn't found, try matching against old-style IDs by checking if the requested ID starts with any competitor's name-only ID:
```js
const competitor = competitors.find((c) => c.id === id)
  || competitors.find((c) => id.startsWith(c.id + "-"));
```

This handles the transition period where old bookmarks like `/competitor/vesper-ortega-arvada` still resolve to the merged `/competitor/vesper-ortega` record.

## What stays unchanged

- Entry IDs (based on competition + index, not competitor)
- Competition IDs (based on date + name)
- All UI components (they use whatever ID they receive)
- The dedup logic for belt/ageGroup/weightClass resolution (already correct)

## Verification

1. `npm run build` -- no build errors
2. Verify `makeCompetitorId("Vesper Ortega")` produces `vesper-ortega`
3. Trace through `transformSheetData()` mentally: two entries for "Vesper Ortega" from different academies should merge into one competitor with the most recent academy
4. Verify the orphan cleanup logic won't accidentally delete competitors that should exist
5. Test old-style URL fallback: `/competitor/vesper-ortega-arvada` should resolve to the merged competitor

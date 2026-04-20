# Technical Analysis (2026-04-01)

Design reference document archived from TODO.md consolidation (2026-04-09). Contains detailed analysis, design decisions, and resolved items that informed the current architecture. Open action items have been migrated to `TODO.md`.

---

## Scalability -- Resolved Items

### Caching Strategy (v0.2.0)

Module-scope caches in `sheets.js` and `index.js` caused stale data and cold-start bottlenecks. Resolved by migrating to Supabase as the serving layer with `'use cache'` + `cacheLife('hours')` + `cacheTag('leaderboard')` at the framework level.

### Data Pipeline Bottlenecks (v0.2.0 - v0.3.0)

Double leaderboard computation, O(C*E) rank changes, and triple `computeStats()` calls per render were resolved by:
- Single cached `getEnrichedLeaderboard()` call (v0.3.0)
- `buildStatsMap()` + `computeStatsFromEntries()` (v0.2.0)
- `idx_entries_competitor` index in Supabase (v0.2.0)

### Client-Side Rendering (v0.3.0)

Full dataset serialization concern addressed by:
- Client-side filtering/pagination via useMemo (no server round-trips)
- Searchable Combobox for competition select (feature/mobile-ux)
- Field trimming at call site in `app/page.jsx`

### Database Selection (v0.2.0)

Evaluated Firestore, Supabase, PlanetScale, and Turso. Chose Supabase (Postgres) for relational data fit, SQL query flexibility, and flat pricing. Overrides table implemented with `competitor_id`, `belt`, `weight_class`, `age_group`, `gender`, `age_division`, `reason`, timestamps.

---

## Security Assessment

### Credential Handling

- Credentials in env vars, not hardcoded. `.env*` in `.gitignore`.
- `?.` optional chaining on `GOOGLE_PRIVATE_KEY` prevents crash on undefined.
- Scopes correctly restricted to `spreadsheets.readonly`.

### Injection Vectors

- All user-controlled strings from Sheets rendered via React JSX (auto-escaped). No raw HTML insertion found.
- `competitor.id` slugified to `[a-z0-9-]` via `makeCompetitorId()` -- no URL injection risk.
- Search param handling uses explicit key checks -- no prototype pollution.

### PostHog Proxy (v0.4.0)

Middleware matcher tightened to exclude `/api/*` routes. Full restriction to `/ingest/:path*` deferred to Phase 2 middleware rewrite.

---

## Weighted Scoring Algorithm Design

### Current Limitations

Raw win count ranking with win rate tiebreaker. Problems: no competition prestige weighting, no recency decay, no bracket size factor, no opponent quality signal.

### Proposed Formula

```
EntryScore = BasePoints * DifficultyMultiplier * PlacementMultiplier * RecencyDecay + ActivityBonus

BasePoints = (wins * 10) + 2

DifficultyMultiplier = CompetitionPrestige * BracketSizeFactor
  CompetitionPrestige: IBJJF=1.5, AGF=1.2, GI/NAGA=1.1, Other=1.0
  BracketSizeFactor: 1.0 + (0.1 * min(bracketSize - 2, 8))

PlacementMultiplier: Gold=1.5, Silver=1.25, Bronze=1.1, Other=1.0

RecencyDecay = e^(-0.002 * daysSinceCompetition)
  // Half-life ~347 days. 6mo=0.70x, 1yr=0.48x, 2yr=0.23x

ActivityBonus = min(uniqueCompDatesLast365 * 5, 30)
```

### Pseudocode

```js
function computeWeightedScore(competitor, entries, today) {
  let totalScore = 0;
  for (const entry of entries) {
    const base = entry.wins * 10 + 2;
    const prestige = getCompetitionPrestige(entry.competitionName);
    const bracketFactor = 1.0 + 0.1 * Math.min((entry.bracketSize || 2) - 2, 8);
    const difficulty = prestige * bracketFactor;
    let placement = 1.0;
    if (entry.champion) placement = 1.5;
    else if (entry.medals.silver > 0) placement = 1.25;
    else if (entry.medals.bronze > 0) placement = 1.1;
    const daysSince = (today - new Date(entry.date)) / (1000 * 60 * 60 * 24);
    const recency = Math.exp(-0.002 * daysSince);
    totalScore += base * difficulty * placement * recency;
  }
  const recentDates = new Set(
    entries.filter(e => (today - new Date(e.date)) / 86400000 <= 365).map(e => e.date)
  );
  totalScore += Math.min(recentDates.size * 5, 30);
  return Math.round(totalScore * 10) / 10;
}
```

### Tunable Weights

```js
const SCORING_CONFIG = {
  pointsPerWin: 10,
  participationPoints: 2,
  recencyLambda: 0.002,
  activityBonusPerEvent: 5,
  activityBonusCap: 30,
  placementGold: 1.5,
  placementSilver: 1.25,
  placementBronze: 1.1,
  bracketSizeFactor: 0.1,
  bracketSizeCap: 8,
  wfmWeight: 10,
  beltDecay: [1.0, 0.5, 0.25, 0.1],
  competitionPrestige: { ibjjf: 1.5, agf: 1.2, grapplingIndustries: 1.1, naga: 1.1, default: 1.0 },
};
```

### Cold-Start

Competitors with fewer than 2 entries get a "New" badge instead of a rank. Win rate shown with lower-confidence indicator under 5 total rounds.

### Belt Transition Decay (Kids)

When a kid promotes, historical entries at the previous belt carry reduced weight: same belt=1.0, one below=0.5, two below=0.25, three+=0.1.

### WFM Integration

`WFM_Bonus = avgWfm * 10` (0-10 points added to total score).

---

## Weight Class Bucketing Design

### Problem

Tournament organizers use incompatible weight class naming: IBJJF names (Rooster, Feather), NAGA numeric ranges (50-59.9), F2W compact (65lbs), GI dash-prefix (-45 lbs).

### Canonical Buckets

IBJJF weight class names as canonical system. Adult buckets:

| Name | Max lbs | Max kg |
|------|---------|--------|
| Rooster | 127.6 | 57.5 |
| Light Feather | 141.6 | 64.0 |
| Feather | 154.3 | 70.0 |
| Light | 167.5 | 76.0 |
| Middle | 181.4 | 82.3 |
| Medium Heavy | 195.0 | 88.3 |
| Heavy | 207.8 | 94.3 |
| Super Heavy | 222.2 | 100.5 |
| Ultra Heavy | Inf | Inf |

Kids buckets defined by age group with pound-range boundaries (see `lib/data/weight-buckets.js`).

### Mapping Algorithm

1. Extract numeric value from raw weight string
2. If already an IBJJF name, return directly
3. If numeric, find nearest bucket (age-aware for kids)
4. Fallback: return raw value as-is

### Display

- Competitor profile: canonical bucket name
- Leaderboard filter: canonical buckets (not raw strings)
- Competition history: raw division string for accuracy

---

## Mobile Experience Analysis

### Resolved

- Filter bar collapse into bottom sheet (feature/mobile-ux)
- Type toggle visible on mobile (feature/mobile-ux)
- Clear button in filter sheet (feature/mobile-ux)

### Open Pain Points

- **Table readability**: 6 columns squeezed on 375px. Card layout or horizontal scroll with frozen columns recommended.
- **Stats grid**: 9 stat cards in 3-col on mobile. Prioritize top 5 with expansion toggle.
- **Charts**: Radar labels overlap. Timeline bars too narrow with 10+ entries. Responsive sizing and abbreviation needed.
- **Podium**: 3 full-width stacked cards take excessive vertical space. Compact horizontal row recommended.

---

## Data Pipeline Phases

### Phase 1: Done (v0.4.0)

Weekly cron, sync_sources table, per-source status tracking, middleware matcher fix.

### Phase 2: Admin UI + Auth (Open)

Auth.js with Google provider + email allowlist. Admin pages for sync sources, overrides, sync history. Sync logic extraction to `lib/sync.js`. `sync_logs` table.

### Phase 3: Data Quality (Open)

Duplicate detection with Levenshtein distance. Parse failure tracking. Data health dashboard.

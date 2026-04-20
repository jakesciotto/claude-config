# Google Sheets Integration Design

## Overview

Replace the static seed data with real competition results fetched from Google Sheets at build time. The data source is a master spreadsheet ("Overall Stats - Kids BJJ Comp Program") that aggregates academy-level stats, with 8 sub-spreadsheets containing individual athlete results per competition.

## Data Source

### Master Spreadsheet
- ID: `1oHQK7gs_iuMqCuJhz0z2e6F0kuHpUgLqLwMrRi5b_bI`
- Contains academy-level aggregate stats (participation, W/L, medals, podium/champ rates)
- Per-academy tabs (Arvada, Boulder, Centennial, Denver, Littleton, Longmont, Lowry, Matrix)
- Cross-academy summary tabs (Participants, Registrations, Wins & Losses, W/L %, Medal Data, etc.)

### Competition Sub-Spreadsheets (Individual Results)
Each competition has its own spreadsheet with a "Results" tab containing individual athlete data.

| Date | Competition | Spreadsheet ID | Access |
|------|------------|----------------|--------|
| 2024-01-20 | Grappling Industries | `1DcsQ_khEvInCD7vvM15C17qY3WOcM4XRSxiJCIAQXi0` | OK |
| 2024-02-10 | F2W | `1JY5XNDVcrbcUe0OSpcUHvLlYCaAS2CaCgDrGdJMkHPA` | OK |
| 2024-02-24 | NAGA | `1auIdEvZmWA5VV-v_oFd0iNsAjnS5Im8zKne4rLEZMZI` | OK |
| 2024-03-09 | Easton Open | `1lL1XfjdIQQc-LEggeRdrBZp3hODXWnrZdUCyafp8q6o` | BLOCKED (needs sharing) |
| 2024-04-06 | Submission Challenge | `17S84WePH-etjKxKH-MnMXISXajJuoDv1fZZ1R9ALWVI` | OK |
| 2024-04-13 | AGF | `1kku3Geh1VSHbwR8L6KrSZ4bHB-9N9ODg9PgxzM46N7M` | OK |
| 2024-06-08 | Tap Cancer Out | `1GT1Oy1am4vTuMtDytKGA1jFxZ2BSWcibA4jvhufxWKc` | OK |
| 2024-06-22 | Fight 2 Win | `1fJi01c2vOn6KT46ryePhSPyvG6SPM74CaHGeAI0tcO4` | OK |

7 of 8 accessible. The Easton Open sheet needs to be shared with the service account.

### Results Tab Structure (per sub-spreadsheet)

- Rows 1-65: Academy-level aggregate data (same as master sheet)
- Row 66: Header row for individual data
- Rows 67+: Individual athlete entries (No Gi block first, then Gi block)

The No Gi and Gi blocks are NOT separated by a delimiter row. The parser determines Gi vs No Gi from the division string prefix ("No Gi Kids /..." vs "Gi Kids /..."), so block boundary detection is not needed.

Columns:
```
A: Academy (Easton location short name, e.g. "Arvada", "Boulder")
B: Athlete (full name)
C: Division (encodes Gi/NoGi, belt, age group, gender, weight class)
D: Bracket Type
E-J: M1-M6 (individual round results: "W" or "L", empty if no match)
K: Result (final placement number)
L: (empty)
M: WFM (win finish percentage as string like "66.7%")
N: Podium ("y" or "n")
O: Champ ("y" or "n")
P: Bronze (medal count)
Q: Silver (medal count)
R: Gold (medal count)
```

### Competition Metadata Resolution

Competition name and date are read from the sub-spreadsheet's aggregate section:
- Row 2, Column B: date string (e.g. "1/20/24")
- Row 3, Column B: competition name (e.g. "1/20/24 Grappling Industries")

The competition name is cleaned by stripping the leading date prefix to produce the display name (e.g. "Grappling Industries").

### Division String Format

Patterns:
- No Gi: `"No Gi Kids / Beginner (White) / 6 - 7 years / -45 lbs"`
- No Gi with gender: `"No Gi Kids / Advanced (Yellow/Orange) / 12 - 13 years (Female) / -85 lbs"`
- Gi: `"Gi Kids / Grey / 6 - 7 years / -45 lbs"`
- Gi with gender: `"Gi Kids / Grey / 12 - 13 years (Female) / -85 lbs"`

Belt mapping:
- "Beginner" or "White" -> white
- "Grey" or "Intermediate (Grey)" -> grey
- "Advanced (Yellow/Orange)" or "Yellow/Orange" -> yellow
- "Green" -> green

If a division string does not match any known pattern, the entry is logged as a parse warning and skipped.

### Academy Name Normalization

Sheet column A contains short location names (e.g. "Arvada", "Boulder"). These are normalized to the full canonical format:

| Sheet Value | Canonical Name |
|------------|----------------|
| Arvada | Easton Training Center - Arvada |
| Boulder | Easton Training Center - Boulder |
| Centennial | Easton Training Center - Centennial |
| Denver | Easton Training Center - Denver |
| Littleton | Easton Training Center - Littleton |
| Longmont | Easton Training Center - Longmont |
| Lowry | Easton Training Center - Lowry |
| Matrix | Easton Training Center - Matrix |

"Matrix" is a valid Easton location included in the data. If a location value is not in this mapping, the entry is logged and skipped.

### WFM Definition

WFM stands for "Win Finish Match" -- the percentage of wins where the competitor finished (won outright in a decisive round vs. winning on decision/advantage). The sheet stores it as a formatted percentage string like "66.7%" or "#DIV/0!" (for competitors with no matches). Parsing: strip the "%" suffix and divide by 100. If the value is "#DIV/0!" or empty, store as `null`.

## Data Model

### Competitor
Deduplicated by name + academy across all competitions and Gi/NoGi entries.

```js
{
  id: "nash-caley-arvada",    // slug: kebab-case(name + location)
  name: "Nash Caley",
  academy: "Easton Training Center - Arvada",
  belt: "white",
  ageDivision: "kids",        // all sheet data is kids
  ageGroup: "6-7",
  gender: null,               // "Female", "Male", or null
  weightClass: "-45 lbs",
}
```

Competitor IDs are generated as a stable slug from `kebab-case(name)-kebab-case(location)`. Example: "Gwyneth Clement" at Arvada -> `"gwyneth-clement-arvada"`. This is deterministic across rebuilds, URL-friendly, and human-readable.

If a competitor appears at different belt levels or weight classes across competitions (e.g. promoted mid-season), the most recent competition's values are used.

### CompetitionEntry
One per competitor per Gi/NoGi per competition.

```js
{
  id: "entry-001",
  competitorId: "nash-caley-arvada",
  competitionId: "2024-01-20-grappling-industries",
  date: "2024-01-20",
  competitionName: "Grappling Industries",
  type: "nogi",               // "nogi" or "gi"
  division: "No Gi Kids / Beginner (White) / 6 - 7 years / -45 lbs",
  bracketType: "Multistage - Best of one pool",
  rounds: ["W", "W", "W", "W", "W"],
  wins: 5,
  losses: 0,
  placement: 1,
  podium: true,
  champion: true,
  medals: { gold: 1, silver: 0, bronze: 0 },
  wfm: 1.0,
}
```

### Competition
One per event.

```js
{
  id: "2024-01-20-grappling-industries",  // date-slug(name)
  name: "Grappling Industries",
  date: "2024-01-20",
  spreadsheetId: "1DcsQ_khEvInCD7vvM15C17qY3WOcM4XRSxiJCIAQXi0",
}
```

### Ranking Metrics

Leaderboard ranked by total wins with win rate as tiebreaker (same principle as current app, adapted to new data):

- Total wins (sum of all W rounds across all entries)
- Total losses (sum of all L rounds)
- Win rate (wins / total rounds)
- Gold medals
- Total medals (gold + silver + bronze)
- Podium rate (entries with podium=true / total entries)
- Championship rate (entries with champion=true / total entries)
- WFM average (mean of non-null wfm values)

## Architecture

### File Structure

```
lib/
  data/
    index.js            -- data access layer (async, same exported function names, new source)
    sheets.js           -- Google Sheets API auth + fetch
    transform.js        -- parse raw sheet rows into Competitor/CompetitionEntry/Competition
    seed.js             -- kept as fallback/reference, no longer imported by default
```

### Data Flow

```
Google Sheets API (7 accessible sub-spreadsheets)
        |
        v
lib/data/sheets.js       -- authenticate, fetch Results tab rows 66+ from each sheet
        |
        v
lib/data/transform.js    -- parse division strings, deduplicate competitors, build entries
        |
        v
lib/data/index.js        -- async data access functions, module-scope cache
        |
        v
Server Components        -- await data access calls (all data fetching in server components)
```

### Async Data Access Pattern

All data access functions in `index.js` become `async`. Since all page components are server components, this is straightforward -- they can `await` directly.

Client components (`filter-bar.jsx`, `leaderboard-table.jsx`, `activity-feed.jsx`, etc.) do NOT call data access functions. They receive data as props from their parent server components. This is the existing pattern -- filter-bar receives `academies`, `competitions` etc. as props from `page.jsx`.

The current filter-bar calls `getAcademies()` directly on line 110. This must change: the parent server component (`app/page.jsx`) fetches the data and passes it as a prop.

### Credential Handling

Service account credentials stored as environment variables (not the JSON file):
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`: `easton-leaderboard-service-acc@easton-leaderboard.iam.gserviceaccount.com`
- `GOOGLE_PRIVATE_KEY`: the PEM private key string

The JSON key file (`easton-leaderboard-3c23107889a3.json`) stays in `.gitignore` and is used locally for reference only. Production deployments (Vercel, etc.) set these as environment variables.

### Caching Strategy

- Data fetched once per build (static generation) or via ISR with `revalidate = 3600` (hourly)
- Module-scope caching: once fetched and transformed, the data is stored in module-level variables
- No runtime Sheets API calls during page renders
- Next.js fetch caching handles deduplication across components in the same render

### Fetch at Build Time

`lib/data/sheets.js` exports an async `fetchAllCompetitionData()` function. This is called lazily on first data access in server components. Next.js caches the result for the build lifecycle.

## Division String Parsing

```js
function parseDivision(divisionStr) {
  // Input: "No Gi Kids / Beginner (White) / 6 - 7 years (Female) / -85 lbs"
  const parts = divisionStr.split(" / ");

  const type = parts[0].toLowerCase().startsWith("no gi") ? "nogi" : "gi";
  const belt = extractBelt(parts[1]); // maps "Beginner (White)" -> "white", etc.
  const { ageGroup, gender } = extractAgeAndGender(parts[2]); // "6 - 7 years (Female)" -> { ageGroup: "6-7", gender: "Female" }
  const weightClass = parts[3] || null; // "-85 lbs"

  return { type, belt, ageGroup, gender, weightClass };
}
```

## Data Access Layer Changes

`lib/data/index.js` keeps the same exported function names but all become `async`.

### getCompetitors(filters)
- Source changes from `competitors` array to transformed sheets data
- New filter option: `filters.type` ("gi" or "nogi") filters by entries, not competitors
- `filters.ageGroup` added
- Returns competitors enriched with computed stats (same shape, new stat fields)

### getCompetitorById(id)
- Same signature, returns competitor with computed stats from CompetitionEntry data
- Stats: wins, losses, winRate, goldMedals, totalMedals, podiumRate, champRate, avgWfm, totalEntries

### getLeaderboard(filters, sortBy)
- `sortBy` options change: "wins", "winRate", "medals", "podiumRate", "champRate"
- Rank change: compare current ranking to ranking excluding each competitor's most recent competition

### getEntries(filters)
Replaces `getMatches()`. Returns CompetitionEntry objects.
- `filters`: competitorId, competitionId, type
- Sorted by date descending

### getEntriesByCompetitor(id)
Replaces `getMatchesByCompetitor()`. Returns entries for a single competitor, sorted by date descending.

### getCompetitions()
New. Returns list of Competition objects sorted by date.

### getAcademies()
Same signature. Derived from competitor data.

### getStats()
Returns new aggregate metrics:
```js
{
  totalCompetitors: 96,
  totalEntries: 340,
  totalMedals: 120,         // gold + silver + bronze
  totalGoldMedals: 45,
}
```

### getPeerAverages(ageGroup, belt)
Replaces `getDivisionAverages()`. Returns average stats for competitors in the same age group and belt, used as the baseline for the radar chart comparison.
```js
{
  winRate: 0.52,
  podiumRate: 0.45,
  champRate: 0.18,
  totalMedals: 2.1,
  competitionCount: 3.2,
  avgWfm: 0.41,
}
```

## Component Data Contracts

### leaderboard-table.jsx
Receives `competitors` array from server component. Each competitor object:
```js
{
  id, name, academy, belt, ageGroup, weightClass,
  wins, losses, winRate,
  goldMedals, totalMedals,
  podiumRate, champRate,
  rankChange,
}
```

### activity-feed.jsx
Receives `entries` array (replaces `matches`). Each entry object:
```js
{
  id, competitorId, competitorName,
  competitionName, date, type,
  wins, losses, placement,
  podium, champion,
  medals: { gold, silver, bronze },
}
```
No opponent info, no method, no points. The feed shows: "{name} competed at {competition} ({type}) -- {wins}W-{losses}L, placed {placement}" with medal/podium badges.

### result-badge.jsx
Adapts to two modes:
- **Round result**: receives `result="W"` or `result="L"` for individual round display
- **Medal**: receives `medal="gold"`, `medal="silver"`, or `medal="bronze"` for medal display
- **Podium**: receives `podium={true}` for podium indicator

The old "win"/"loss"/"draw"/"dq" values are no longer used.

### competitor profile page
Server component fetches:
```js
const competitor = await getCompetitorById(id);    // includes computed stats
const entries = await getEntriesByCompetitor(id);   // competition history
const peerAvg = await getPeerAverages(competitor.ageGroup, competitor.belt);
```
Passes data as props to client sub-components (radar, timeline, stats).

### filter-bar.jsx
Receives all filter options as props from the parent server component:
- `academies`: from `getAcademies()`
- `competitions`: from `getCompetitions()`
- `types`: `["gi", "nogi"]` (hardcoded, new filter)

Weight class and belt filters use values derived from the actual competitor data, not hardcoded IBJJF lists.

### competitor-radar.jsx
Receives `competitor` (with stats) and `peerAvg` as props. Six radar dimensions:
1. Win rate (competitor.winRate vs peerAvg.winRate)
2. Podium rate (competitor.podiumRate vs peerAvg.podiumRate)
3. Championship rate (competitor.champRate vs peerAvg.champRate)
4. Medal count (competitor.totalMedals vs peerAvg.totalMedals)
5. Competition count (competitor.totalEntries vs peerAvg.competitionCount)
6. WFM (competitor.avgWfm vs peerAvg.avgWfm)

### match-timeline.jsx
Renamed conceptually to "competition timeline." Receives `entries` array. Shows a bar per competition entry: positive bar height = wins, negative = losses. X-axis = competition dates. Color-coded by Gi/NoGi.

## Environment Variables

Add to `.env.local`:
```
GOOGLE_SERVICE_ACCOUNT_EMAIL=easton-leaderboard-service-acc@easton-leaderboard.iam.gserviceaccount.com
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
GOOGLE_SHEET_IDS=1DcsQ_khEvInCD7vvM15C17qY3WOcM4XRSxiJCIAQXi0,1JY5XNDVcrbcUe0OSpcUHvLlYCaAS2CaCgDrGdJMkHPA,1auIdEvZmWA5VV-v_oFd0iNsAjnS5Im8zKne4rLEZMZI,17S84WePH-etjKxKH-MnMXISXajJuoDv1fZZ1R9ALWVI,1kku3Geh1VSHbwR8L6KrSZ4bHB-9N9ODg9PgxzM46N7M,1GT1Oy1am4vTuMtDytKGA1jFxZ2BSWcibA4jvhufxWKc,1fJi01c2vOn6KT46ryePhSPyvG6SPM74CaHGeAI0tcO4
```

Note: The blocked Easton Open sheet (`1lL1XfjdIQQc-LEggeRdrBZp3hODXWnrZdUCyafp8q6o`) is excluded until sharing is fixed. Add it to `GOOGLE_SHEET_IDS` once the service account has access.

## Error Handling

- If a sub-spreadsheet fails to load (permission, network), skip it and log a warning. The app renders with whatever data it can get.
- If all sheets fail, fall back to empty state (not seed data) with a visible indicator.
- Division string parsing failures: log the unparseable string, skip the entry.
- Missing/empty cells in round results (M1-M6): treat as no match played for that round.
- WFM values of "#DIV/0!" or empty: store as `null`, exclude from averages.

## Risks and Mitigations

1. **Easton Open sub-sheet access**: one of 8 sheets is blocked. Mitigation: excluded for now, easy to add once shared.
2. **Division string format changes**: if future competitions use different division formatting, the parser will fail silently. Mitigation: log parse failures, add format variants as discovered.
3. **Athlete name collisions**: two different athletes with the same name at the same academy would be merged. Mitigation: unlikely in a kids program at a single location; can add age group to dedup key if needed.
4. **Google Sheets API rate limits**: fetching 7 sheets at build time is well within limits. No concern at current scale.
5. **Belt/weight class changes across competitions**: a competitor may be promoted or change weight class mid-season. Mitigation: use the most recent competition's values for the competitor profile.

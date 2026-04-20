# Easton BJJ Leaderboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a public competition leaderboard for Easton BJJ gym with dashboard, filterable leaderboard table, and competitor profiles.

**Architecture:** Next.js 16 App Router with shadcn/ui components and Tailwind CSS. Static seed data behind an abstracted data access layer. Dark mode default. Three pages: dashboard, leaderboard, competitor profile.

**Tech Stack:** Next.js 16, JavaScript (.jsx), shadcn/ui (new-york style, zinc base), Tailwind CSS, Turbopack, Lucide icons

---

### Task 1: Project Scaffolding

**Files:**
- Create: project root via create-next-app
- Modify: `components.json` (set tsx: false)
- Create: `jsconfig.json` (path aliases)

**Step 1: Create Next.js project**

Run from the project directory:
```bash
cd /Users/jakesciotto/github/easton-leaderboard
npx create-next-app@latest . --js --eslint --tailwind --app --no-src-dir --import-alias "@/*" --turbopack
```

Select NO for TypeScript when prompted.

**Step 2: Initialize shadcn/ui**

```bash
npx shadcn@latest init
```

When prompted:
- Style: New York
- Base color: Zinc
- CSS variables: Yes

Then verify `components.json` has `"tsx": false`.

**Step 3: Install shadcn/ui components needed**

```bash
npx shadcn@latest add button card badge table select separator tabs dropdown-menu
```

**Step 4: Install additional dependencies**

```bash
npm install lucide-react next-themes
```

**Step 5: Verify dev server starts**

```bash
npm run dev
```

Expected: App loads at http://localhost:3000 with default Next.js page.

---

### Task 2: Theme and Layout Setup

**Files:**
- Modify: `app/globals.css` (dark mode colors, belt colors as CSS variables)
- Create: `components/theme-provider.jsx` (next-themes wrapper)
- Modify: `app/layout.jsx` (add ThemeProvider, metadata, font setup)
- Create: `components/nav.jsx` (top navigation with dark mode toggle)

**Step 1: Update globals.css with custom theme**

Add belt color CSS variables and result color variables to the existing shadcn/ui
CSS variables block. Set dark mode as default via the `dark` class on `:root`.

Belt color variables to add:
```
--belt-white: 0 0% 96%;
--belt-blue: 221 72% 40%;
--belt-purple: 271 76% 47%;
--belt-brown: 28 84% 30%;
--belt-black: 0 0% 9%;
--belt-grey: 220 9% 46%;
--belt-yellow: 48 96% 53%;
--belt-orange: 21 90% 48%;
--belt-green: 142 72% 37%;
--result-win: 142 72% 37%;
--result-loss: 0 84% 60%;
--result-draw: 38 92% 50%;
--result-dq: 240 5% 65%;
```

**Step 2: Create ThemeProvider component**

`components/theme-provider.jsx` -- wraps next-themes ThemeProvider with
attribute="class", defaultTheme="dark", enableSystem=false.

**Step 3: Create Nav component**

`components/nav.jsx` -- contains:
- Left: "Easton BJJ" text logo + "Leaderboard" subtitle
- Center: nav links (Dashboard, Leaderboard) using Next.js Link
- Right: dark/light mode toggle button (Sun/Moon icons from lucide-react)
- Sticky top, backdrop blur, border-bottom

**Step 4: Update app/layout.jsx**

- Import Geist Sans font (from next/font/google or geist package)
- Wrap children in ThemeProvider
- Add Nav component above {children}
- Set metadata: title="Easton BJJ Leaderboard", description="Competition results..."
- Max-width container wrapper (max-w-7xl mx-auto px-4)

---

### Task 3: Seed Data

**Files:**
- Create: `lib/data/seed.js`

**Step 1: Create seed data file**

`lib/data/seed.js` -- export two arrays: `competitors` (12 adults + 8 kids = 20)
and `matches` (3-6 matches per competitor, ~80 total matches).

Competitors should use:
- Realistic names
- Academy: most are "Easton BJJ" (home gym)
- Adults: white/blue/purple/brown/black belts
- Kids: white/grey/yellow/orange/green belts
- Weight classes: Rooster, Light Feather, Feather, Light, Middle, Medium Heavy, Heavy, Super Heavy, Ultra Heavy
- Kids weight classes: Rooster, Light Feather, Feather, Light, Middle, Medium Heavy, Heavy

Matches should use:
- Dates spread across 2025-2026
- Competitions: "IBJJF Denver Open 2025", "Grappling Industries Denver",
  "NAGA Denver", "Good Fight Sub Only", "Colorado State Championship 2025",
  "IBJJF Denver Spring Open 2026", "Grappling Industries Boulder"
- Results: mix of wins and losses (bias toward wins ~60%)
- Methods: submission (armbar, triangle, RNC, bow and arrow, guillotine, kimura,
  americana, omoplata, ezekiel, loop choke), points, decision, advantage
- Opponent names and academies: realistic names, various academies
  (Gracie Barra, 10th Planet, Atos, Alliance, CheckMat, Brasa, Carlson Gracie)
- Points: 0-12 range, advantages 0-4, penalties 0-2
- Duration: "3:00" to "10:00" range

Use deterministic UUIDs (e.g. "comp-01" through "comp-20" for competitors,
"match-001" through "match-xxx" for matches) so they are stable and linkable.

---

### Task 4: Data Access Layer

**Files:**
- Create: `lib/data/index.js`

**Step 1: Implement data access functions**

All functions import from `./seed.js` and compute derived data:

```javascript
export function getCompetitors(filters = {})
// Returns competitors filtered by: ageDivision, belt, weightClass
// Each competitor object is enriched with computed stats (wins, losses, etc.)

export function getCompetitorById(id)
// Returns single competitor with full computed stats

export function getMatches(filters = {})
// Returns matches filtered by: competitorId, competition, dateFrom, dateTo, result

export function getMatchesByCompetitor(competitorId)
// Returns all matches for a competitor, sorted by date descending

export function getLeaderboard(filters = {}, sortBy = "wins")
// Returns competitors sorted by ranking metric
// Enriches each with: wins, losses, draws, winRate, submissionRate,
// avgPointsScored, avgPointsAgainst, pointDifferential
// Default sort: wins desc, then winRate desc for ties

export function getStats()
// Returns: { totalCompetitors, totalMatches, totalSubmissions }
```

Helper function `computeStats(competitorId, matches)`:
- Filter matches for competitor
- Count wins, losses, draws
- Calculate winRate = wins / (wins + losses + draws)
- Calculate submissionRate = submission wins / total wins
- Calculate avgPointsScored, avgPointsAgainst from all matches
- Calculate pointDifferential = avgPointsScored - avgPointsAgainst

---

### Task 5: Shared UI Components

**Files:**
- Create: `components/belt-badge.jsx`
- Create: `components/result-badge.jsx`
- Create: `components/stat-card.jsx`

**Step 1: BeltBadge component**

Props: `belt` (string)
- Uses shadcn Badge component
- Background color mapped from belt name to CSS variable
- White belt gets dark text, all others white text
- Capitalizes belt name as label

**Step 2: ResultBadge component**

Props: `result` (string)
- Uses shadcn Badge component
- "win" = green bg, "loss" = red bg, "draw" = amber bg, "dq" = muted gray bg
- Capitalizes result as label (DQ stays uppercase)

**Step 3: StatCard component**

Props: `label` (string), `value` (string|number), `icon` (optional Lucide icon)
- Uses shadcn Card
- Large monospace value, smaller muted label below
- Optional icon top-right

---

### Task 6: Dashboard Page

**Files:**
- Modify: `app/page.jsx`

**Step 1: Build dashboard layout**

The root page (`/`) contains:

1. Page title: "Competition Dashboard"
2. Stats row: 3 StatCard components in a grid
   - Total Competitors (Users icon)
   - Total Matches (Swords/Trophy icon)
   - Total Submissions (Target icon)
   - Data from `getStats()`

3. Two-column grid below stats:
   - Left column:
     - "Top Adults" Card: top 5 adults by wins from `getLeaderboard({ ageDivision: "adult" })`
       Each row: rank number, name (link to /competitor/[id]), BeltBadge, win count
     - "Top Kids" Card: same but `{ ageDivision: "kids" }`
   - Right column:
     - "Recent Results" Card: last 10 matches sorted by date desc from `getMatches()`
       Each row: date, competitor name (link), ResultBadge, "vs" opponent name, method

4. Responsive: 2-col on desktop, single column stacked on mobile

---

### Task 7: Leaderboard Page

**Files:**
- Create: `app/leaderboard/page.jsx`
- Create: `components/filter-bar.jsx`
- Create: `components/leaderboard-table.jsx`

**Step 1: Create FilterBar component**

`components/filter-bar.jsx` -- client component ("use client")
- Age division: two toggle buttons (Adults / Kids / All)
- Belt: shadcn Select dropdown with belt options (adapts based on age division)
- Weight class: shadcn Select dropdown
- Competition: shadcn Select dropdown (populated from unique competition names in data)
- All filters read from and write to URL search params via useSearchParams/useRouter
- "Clear filters" button resets all

**Step 2: Create LeaderboardTable component**

`components/leaderboard-table.jsx` -- client component
- shadcn Table with columns: Rank (#), Name, Belt (BeltBadge), Weight Class,
  W (wins), L (losses), Win %, Sub (submission count), Pts/Match (avg points scored)
- Win % formatted as percentage with 1 decimal
- Pts/Match formatted to 1 decimal
- Click column headers to toggle sort (asc/desc)
- Click row to navigate to /competitor/[id]
- Alternating row shading in dark mode for readability

**Step 3: Create leaderboard page**

`app/leaderboard/page.jsx`
- Page title: "Leaderboard"
- FilterBar at top
- LeaderboardTable below with data from getLeaderboard(filters, sortBy)
- Read filters from searchParams (server component reads, passes to client children)

---

### Task 8: Competitor Profile Page

**Files:**
- Create: `app/competitor/[id]/page.jsx`

**Step 1: Build competitor profile**

`app/competitor/[id]/page.jsx`

1. Fetch competitor via `getCompetitorById(params.id)`
2. Fetch matches via `getMatchesByCompetitor(params.id)`
3. If not found, call `notFound()`

4. Header section:
   - Name (large heading), BeltBadge, academy, weight class, age division badge

5. Stats grid (7 StatCards in a responsive row):
   - Wins, Losses, Draws, Win Rate (%), Submission Rate (%), Avg Pts Scored, Avg Pts Against

6. Match history section:
   - "Match History" heading
   - shadcn Table: Date, Competition, Opponent, Opp. Academy, Result (ResultBadge),
     Method, Pts For, Pts Against, Advantages, Penalties, Duration
   - Sorted by date descending

---

### Task 9: Responsive Polish and Final Review

**Files:**
- Modify: various component files as needed

**Step 1: Mobile responsiveness pass**

- Dashboard: stats cards wrap to 1-column on mobile, two-column layout stacks
- Leaderboard: filter bar stacks vertically, table horizontally scrollable or collapses to cards
- Competitor profile: stats grid wraps from 7-across to 2-3 column on mobile
- Nav: responsive sizing, possibly hamburger on very small screens

**Step 2: Visual polish**

- Verify dark mode default works correctly
- Check all belt badge colors render properly in both themes
- Verify hover states on table rows and links
- Confirm filter state persists in URL
- Check page transitions are smooth

**Step 3: Run dev server and manual QA**

```bash
npm run dev
```

Walk through all three pages, test all filters, click through competitor profiles,
toggle dark/light mode, test at mobile breakpoints.

---

## Execution Notes

- No git commits during implementation. Full prototype reviewed before any commits.
- All data access through lib/data/index.js -- never import seed.js directly from components.
- Use "use client" directive only on components that need interactivity (filters, sort, theme toggle).
- Server components by default for pages that just read data.

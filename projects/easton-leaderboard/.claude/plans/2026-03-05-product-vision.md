# Easton BJJ Competition Leaderboard -- Product Vision

Date: 2026-03-05

## Core Thesis

The Easton Competition Leaderboard should be the single place where competitors,
coaches, parents, and gym owners go to see how Easton athletes are performing
across the Colorado competition circuit -- updated after every tournament,
browsable by anyone, and useful enough that people check it without being asked.

---

## Where V1 Stands

Working product with solid bones. 20 seed competitors, 88 matches, filterable
leaderboard table, individual competitor profiles with full match history. Glass
morphism dark/light UI. Clean data access layer abstracted behind `lib/data/index.js`,
ready for Firestore swap. Static data, no auth, no data entry pipeline.

**What works well:**
- Data model is sound. Competitor + Match schema handles IBJJF, NAGA, Grappling Industries
  without modification
- Filter system covers the major axes (division, belt, weight, competition, academy)
- Competitor profiles show everything a competitor cares about: record, rates, match log
- URL-persisted filters make pages shareable

**What is missing:**
- No way to add or update data without code changes
- No concept of time (seasons, streaks, momentum)
- No reason to come back after the first visit
- Nothing shareable on social media
- No coach/owner view
- No SEO -- competitors cannot find themselves via search

---

## V2 Feature Set

### Theme 1: Data Pipeline (foundation for everything else)

The entire product is blocked on getting real data in. Without this, nothing else
matters.

**Google Sheets as intake form:**
- Coaches/admins enter results in a shared Google Sheet after each tournament
- Columns map 1:1 to the existing Match schema: competitor name, date, competition,
  result, method, opponent, points, duration
- A "Sync" Cloud Function (or Next.js API route with cron) reads the sheet via
  Google Sheets API, validates rows, and writes to Firestore
- Sheet serves as the human-readable audit log. Firestore is the source of truth
  for the app
- New competitors are auto-created on first match entry (name + academy + belt +
  weight + division)
- A simple admin page (behind basic auth -- even just a shared password) shows
  sync status: last run, rows processed, validation errors

**Firestore schema:**
- `competitors` collection: same fields as current seed data, plus `createdAt`,
  `updatedAt`
- `matches` collection: same fields as current seed data, plus `competitorRef`
  (document reference), `createdAt`, `syncedFromSheet` (boolean)
- `competitions` collection (new): `name`, `date`, `location`, `organization`
  (IBJJF/NAGA/GI/etc.), `matchCount` -- enables competition-level pages
- `seasons` collection (new): `year`, `startDate`, `endDate` -- enables yearly
  boundaries

**Why Sheets and not a custom admin UI:**
- Coaches already live in spreadsheets. Meet them where they are
- A Sheet is shareable across all 9 locations without building role-based auth
- Copy/paste from tournament brackets is natural in a spreadsheet
- The sync function is simple to build and simple to debug
- If the Sheet format ever becomes a bottleneck, a proper admin UI can be layered
  on top of the same Firestore backend

### Theme 2: Competitor Identity and Shareability

The profile page is where competitors develop attachment to the product. If a
competitor cannot find their own page via Google and share it, the app fails its
core audience.

**SEO and discoverability:**
- Generate proper `<title>` and `<meta>` tags per competitor:
  `"Marcus Rivera | Brown Belt | Easton BJJ Competition Record"`
- Open Graph images auto-generated per competitor (name, record, belt color,
  academy logo) -- this is what shows up when someone pastes a link in iMessage,
  Instagram stories, or Facebook
- Sitemap generation (`/sitemap.xml`) listing all competitor profile URLs
- Structured data (JSON-LD) for each competitor page -- helps Google understand
  the content even if it does not render a rich card

**Shareable competition cards:**
- After each tournament, generate a "Competition Recap" image for each competitor
  who competed: their name, results from that day (2-1, gold medal, etc.), belt,
  academy
- This is the "Instagram story" moment. Competitors screenshot or share the URL
  and get a proper preview card
- Framing: "Marcus Rivera went 2-0 at IBJJF Denver Spring Open. See full results
  on the Easton Leaderboard."
- A `/share/[competitorId]/[competitionSlug]` route that renders a focused view:
  just that competitor's matches from that one tournament, optimized for mobile
  screenshot and OG image

**Competitor profile enhancements:**
- Win/loss streak indicator (current streak: W3, L1, etc.)
- "Last competed" date -- shows who is active
- Belt promotion history (when data is available) -- a timeline showing
  white -> blue -> purple with approximate dates
- Career record vs. Easton-only record (competitors face non-Easton opponents)
- Head-to-head records if two tracked competitors have faced each other
  (the seed data already has cross-references: comp-10 Samuel Park beat
  "Tomas Guerrero" from "Easton BJJ")

### Theme 3: Time and Momentum

Static rankings are boring. Rankings that change are interesting.

**Seasons:**
- Competition year runs January through December (or follows IBJJF season if
  Easton prefers)
- Season selector in the nav/filter bar: "2025", "2026", "All Time"
- Leaderboard defaults to current season. All-time is always available
- Previous season data is archived but browsable. Competitors build a career
  history across seasons

**Activity and recency:**
- "Months since last competition" indicator on competitor profiles
- Leaderboard can sort by "most active" (most matches in current season) -- this
  incentivizes competing, which is good for the gym
- "Rising" flag on competitors with improving win rate over last 3 tournaments
  vs. their career average
- Optional: decay factor on rankings so that a competitor who went 5-0 eighteen
  months ago does not sit at the top forever. But this is controversial and
  should be configurable

**Competition calendar (lightweight):**
- A `/competitions` page listing past and upcoming tournaments
- Each past competition links to a results page: who from Easton competed,
  results, medals
- Upcoming competitions sourced from a simple list (Sheets column or Firestore
  collection). Not a full calendar app -- just "these tournaments are coming up"

### Theme 4: Academy and Coach Views

Gym owners and coaches are the decision-makers. They choose where to allocate
comp class time, which students to push toward competition, and how to market the
gym's competitive success. Give them data they cannot get anywhere else.

**Academy roll-up stats:**
- `/academy/[slug]` pages for each Easton location (Boulder, Denver, Arvada, etc.)
- Aggregate stats: total competitors, total matches, win rate, submission rate,
  active competitors
- Ranked list of that location's competitors
- Cross-location comparison on the main dashboard: "Boulder: 14 competitors,
  68% win rate. Denver: 22 competitors, 55% win rate."
- This creates healthy inter-location competition. Coaches notice

**Coach dashboard (future, behind auth):**
- Which students have not competed recently but were previously active
  (retention signal)
- Students improving vs. declining (win rate trend over last N tournaments)
- Which weight classes and belt levels have the most representation
  (tells coaches where their comp team is strong/weak)
- None of this requires complex analytics. It is all derivable from the existing
  match data with simple aggregation

### Theme 5: Ranking System Upgrade

The current "sort by wins" is a V1 simplification. At scale, it penalizes people
who compete less frequently but win at a higher rate, and rewards people who
compete often but lose a lot.

**Weighted point system:**
- Submission finish: 5 points
- Points/decision win: 3 points
- Advantage/referee decision win: 2 points
- Draw: 1 point
- Loss: 0 points
- DQ (against): -1 point

**Leaderboard ranking = total weighted points in current season.** This rewards
both volume and quality. A competitor who goes 3-0 with 2 submissions scores
10+3 = 13. A competitor who goes 5-2 with 1 submission scores 5+3+3+3+3 = 17
but also had 2 losses.

Offer the user a toggle: "Ranked by: Points | Wins | Win Rate | Activity" so
different views serve different audiences. Coaches might prefer win rate. Students
might prefer total points. Parents might prefer activity (is my kid actually
competing?).

**Normalization concern:** Do not penalize competitors who compete in harder
divisions (open weight, absolute, belt-up). This is a future problem that
requires tagging matches with difficulty metadata. For now, treat all matches
equally.

---

## V3 Aspirational Features

These are ideas that make sense only after V2 is proven and the data pipeline
is reliable. They are listed here to inform architectural decisions now.

**Live competition day tracking:**
- On tournament day, a designated person (coach, team captain, parent volunteer)
  enters results in real time via a mobile-optimized form or the Google Sheet
- The leaderboard updates within minutes (Firestore onSnapshot or polling)
- A `/live` page shows today's results as they come in: "Jackson Foley just won
  by submission at IBJJF Denver Open"
- Push notifications (web push via service worker) for team results
- This is the "game day" feature that makes people refresh the page

**PWA / Mobile wrapper:**
- Add a `manifest.json` and service worker for "Add to Home Screen"
- Offline support for previously viewed profiles (cache competitor data in
  IndexedDB)
- Not a native app. A PWA is sufficient for a leaderboard with no complex
  native interactions
- Splash screen with Easton branding on launch

**Competitor self-service:**
- Competitors claim their own profile via email verification
- They can upload a profile photo, link social media handles
- They can add matches not entered by coaches (e.g., open mats, unofficial
  competitions) -- marked as "self-reported" and excluded from official rankings
  unless coach-verified

**Team scoring at tournaments:**
- Aggregate Easton's performance at a given tournament as a "team score" -- total
  golds, silvers, bronzes, or total weighted points
- Compare Easton's team score to other academies who competed at the same event
- Display: "Easton placed 2nd out of 18 teams at Colorado State Championship"
- Requires opponent academy data, which is already in the match schema

**Bracket visualization:**
- For IBJJF-style single elimination brackets, show where an Easton competitor
  placed in the bracket
- Requires bracket structure data (round number, bracket position) -- this is an
  extension to the match schema: add `round` and `bracketPosition` optional fields
- Visual: a simplified bracket tree showing the competitor's path to gold/silver/bronze

**Video integration:**
- Competitors or coaches link match video URLs (YouTube, Instagram) to specific
  match records
- Match history table shows a "play" icon next to matches with video
- This is the feature that coaches use most -- reviewing footage by opponent,
  by tournament, by technique

**Public API:**
- A read-only JSON API at `/api/competitors`, `/api/matches`, etc.
- Enables third-party integrations, widgets on the Easton main website, or
  custom displays on gym TVs

---

## Technical Considerations for Scale

### Data volume projections

At full rollout across 9 Easton locations:
- 100-200 active competitors (adults + kids who compete at least once per year)
- 4-8 tournaments per year per competitor (heavy competitors do more)
- 400-1600 new matches per year
- After 3 years: 500+ competitors (including inactive), 3000-5000 matches

This is a small dataset. Firestore handles it trivially. No need for
pagination optimization, database indexing concerns, or caching layers until
the data is 10x larger than projected.

### Firestore query patterns

Index on:
- `matches` collection: `competitorId` + `date` (descending) -- for match history
- `matches` collection: `competition` -- for competition-level views
- `competitors` collection: `academy` + `ageDivision` + `belt` -- for filtered
  leaderboards
- `competitors` collection: `ageDivision` -- for division-level leaderboards

Composite queries (e.g., "all blue belt adults from Boulder who competed in 2026")
may require Firestore composite indexes. Create them as needed based on actual
query patterns.

### Leaderboard computation

Two options:
1. **Compute on read (current approach):** Every page load computes stats from
   raw matches. Works fine for hundreds of matches. At 5000+ matches with
   complex weighted scoring, consider pre-computing
2. **Compute on write (future):** When a match is written to Firestore, a Cloud
   Function updates the competitor's aggregate stats document. Stats collection
   stores pre-computed wins, losses, weighted points, etc. Pages read from stats
   collection directly. More complex but scales indefinitely

Recommendation: Stay with compute-on-read through V2. The dataset is small enough
that client-side or server-side computation is imperceptible. Switch to
compute-on-write only if load testing reveals issues.

### Google Sheets sync architecture

```
Google Sheet (coaches enter data)
       |
       v
Cloud Function / Next.js API Route (triggered by cron, every 15 min or on-demand)
       |
       v
Validate rows (required fields present, result enum valid, date parseable)
       |
       v
Firestore write (batch upsert: create if new, update if match ID exists)
       |
       v
App reads from Firestore (no code changes to data access layer interface)
```

Key decisions:
- Sync frequency: 15 minutes via Cloud Scheduler, plus a manual "Sync Now"
  button in admin. Not real-time -- coach enters data, it shows up within 15
  minutes. Real-time sync adds complexity for negligible benefit
- Conflict resolution: Sheet is the source of truth for data entry. If a row is
  modified in the Sheet, the sync overwrites the Firestore document. Firestore is
  the source of truth for the app
- Row identification: Each Sheet row needs a stable ID. Use the match ID column
  (e.g., "match-089") or generate a deterministic hash from
  (competitorName + date + competition + opponentName)
- Error handling: Rows that fail validation are logged but do not block the rest
  of the sync. Admin UI shows a list of "failed rows" with reasons

### Migration path from static data

The current `lib/data/index.js` exports functions with a clean interface:
`getCompetitors(filters)`, `getLeaderboard(filters, sortBy)`, etc. To migrate:

1. Add Firebase SDK to the project (`firebase` or `firebase-admin` package)
2. Rewrite the internal implementation of each function in `lib/data/index.js`
   to query Firestore instead of importing from `seed.js`
3. Function signatures and return shapes stay identical
4. No component changes required

This is the payoff of the abstracted data layer -- it was designed for exactly
this moment.

### Performance and caching

- Use Next.js `fetch` caching or `unstable_cache` for Firestore reads in server
  components. Revalidate every 60 seconds or on-demand via webhook after sync
- Static generation (ISR) for competitor profiles: generate at build time,
  revalidate every 5 minutes. Profile data changes infrequently
- Leaderboard page: SSR with short cache. Filters in URL params mean each
  filter combination is a unique cache key -- this is fine for the expected
  traffic volume
- OG images: generate once and cache indefinitely (invalidate when competitor
  data changes). Use `@vercel/og` or a canvas-based solution

---

## Information Architecture at Scale

```
/                           Dashboard (stat cards, quick links, recent results)
/leaderboard                Full leaderboard (filterable, sortable, paginated)
/competitor/[id]            Competitor profile (stats, match history, trends)
/competitor/[id]/share/[comp]  Shareable competition recap card
/competitions               Competition list (past results, upcoming schedule)
/competition/[slug]         Single competition results page
/academy/[slug]             Academy roll-up page (per-location stats)
/live                       Live competition day feed (V3)
/admin                      Admin: sync status, data validation (behind auth)
```

Navigation structure:
- Primary nav: Dashboard, Leaderboard, Competitions
- Secondary (in footer or dropdown): Academy pages, Admin
- Competitor profiles are not in nav -- they are reached via the leaderboard
  table or search

**Search:** Add a search input to the nav bar. At 200 competitors, a simple
client-side filter (name substring match) is sufficient. No need for Algolia
or ElasticSearch. The search links directly to the competitor profile.

---

## Key Metrics

How we know this product is working:

### Engagement (people come back)

| Metric | Target | How to measure |
|--------|--------|----------------|
| Monthly active visitors | 100+ unique within 3 months of launch | Vercel Analytics or Plausible |
| Return visitor rate | 30%+ visitors return within 30 days | Analytics |
| Average pages per session | 3+ (dashboard -> leaderboard -> profile) | Analytics |
| Post-tournament spike | 2-3x traffic within 48 hours of a major tournament | Analytics time series |

### Shareability (people spread it)

| Metric | Target | How to measure |
|--------|--------|----------------|
| Share page views | 20% of profile views come from external referrers | Referrer data in analytics |
| OG image renders | Track via image CDN hit count | Vercel image optimization logs |
| Direct profile URL visits | Growing over time (means people are bookmarking/sharing) | Analytics |

### Data health (the pipeline works)

| Metric | Target | How to measure |
|--------|--------|----------------|
| Time from tournament to data available | Under 48 hours | Track sync timestamps |
| Sync error rate | Under 5% of rows fail validation | Admin dashboard |
| Active competitors (competed in last 6 months) | 50+ within first season | Query Firestore |
| Matches entered per month | Correlates with tournament schedule | Firestore write count |

### Gym value (owners see ROI)

| Metric | Target | How to measure |
|--------|--------|----------------|
| New competition sign-ups | Qualitative -- do coaches report students citing the leaderboard as motivation? | Coach feedback |
| Cross-location awareness | Do competitors from one location browse another location's page? | Analytics by academy filter usage |
| Social media mentions | Competitors sharing their profiles | Manual tracking or social listening |

---

## What Not to Build

Scope discipline matters more than feature breadth for a gym leaderboard.

- **User accounts and auth for competitors.** Not in V2. Profiles are public.
  If a competitor wants to "claim" their profile, that is V3. Auth adds
  significant complexity and the core use case (viewing results) does not
  require it
- **Mobile native app.** A PWA is sufficient. The interaction model is "look
  at data" -- there is no camera, GPS, or notification-heavy workflow that
  demands native
- **Real-time websocket updates.** Polling or ISR revalidation is fine. Match
  results are not stock prices. A 60-second delay is imperceptible
- **Complex permissions and roles.** One shared Google Sheet, one admin
  password. Multi-role RBAC is over-engineering for a 9-location gym
- **Machine learning or predictive analytics.** "Based on your record, you
  have a 73% chance of winning your next match" -- interesting but gimmicky.
  The data volume is too small for meaningful predictions and the audience
  does not need it
- **Monetization.** This is a member benefit and marketing tool, not a
  revenue product. Do not add paywalls, ads, or premium tiers

---

## Priority Order

If forced to sequence everything into a single timeline:

1. **Firestore migration + Google Sheets pipeline** -- unlocks real data
2. **SEO and OG images** -- makes profiles findable and shareable
3. **Seasons and competition pages** -- adds the time dimension
4. **Weighted ranking system** -- makes the leaderboard more meaningful
5. **Academy roll-up pages** -- serves coaches and owners
6. **Share cards and competition recaps** -- drives social sharing
7. **Search** -- quality of life at scale
8. **Live competition day** -- the marquee feature, but only valuable after
   the data pipeline is proven reliable
9. **PWA wrapper** -- polish
10. **Competitor self-service** -- only if there is demand

Items 1-4 constitute V2. Items 5-7 are the V2.5 polish pass. Items 8-10 are V3.

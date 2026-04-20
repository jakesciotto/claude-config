# CAPABILITIES.md

Current feature inventory. Updated as features are added or modified.

---

## Data Pipeline

| Capability                    | Status | Notes                                                                             |
| ----------------------------- | ------ | --------------------------------------------------------------------------------- |
| Google Sheets ingestion       | Live   | 7 competition spreadsheets via googleapis service account                         |
| Multi-format division parsing | Live   | Grappling Industries, F2W, AGF, NAGA, Tap Cancer Out, Submission Challenge, IBJJF |
| Belt detection                | Live   | 7 belts (white-green), typo handling, combined division resolution                |
| Weight class normalization    | Live   | IBJJF name standardization, suffix stripping, numeric range normalization         |
| Age group extraction          | Live   | XU format, range format, single-age format                                        |
| Gender detection              | Live   | From division string keywords                                                     |
| Academy mapping               | Live   | 8 locations + aliases (Matrix, Easton-prefixed)                                   |
| Competitor deduplication      | Live   | By name + academy slug; highest belt from most recent date wins                   |
| Admin profile overrides       | Live   | JSON file (`lib/data/overrides.json`) merged after sheet data transformation      |
| ISR caching                   | Live   | `revalidate = 3600` (hourly) on all page routes                                   |
| Module-scope caching          | Live   | Sheets API + transformed data cached per Node process                             |
| Error resilience              | Live   | `Promise.allSettled` allows individual sheet failures                             |

## Dashboard (app/page.jsx)

| Capability             | Status | Notes                                                                     |
| ---------------------- | ------ | ------------------------------------------------------------------------- |
| Podium display         | Live   | Top 3 competitors with gold/silver/bronze accents and ambient glow        |
| Leaderboard table      | Live   | Sortable (wins, win rate, medals, podium %, champ %), paginated (10/page) |
| Rank change indicators | Live   | Arrows computed by excluding most recent competition and re-ranking       |
| Activity feed          | Live   | Recent entries as collapsible accordion with W-L record and medals        |
| Stat cards             | Live   | Total competitors, total entries, total medals, total gold                |

## Filtering

| Capability            | Status | Notes                                                     |
| --------------------- | ------ | --------------------------------------------------------- |
| Type toggle           | Live   | All / Gi / Nogi buttons; stats recomputed per type        |
| Belt filter           | Live   | Dropdown, dynamic options from data                       |
| Weight class filter   | Live   | Dropdown, normalized and deduplicated options             |
| Competition filter    | Live   | Dropdown; stats recomputed scoped to selected competition |
| Academy filter        | Live   | Dropdown, formatted as "ETC {Location}"                   |
| URL-param persistence | Live   | All filters stored as search params; shareable URLs       |
| Combined filters      | Live   | AND logic; type + competition intersection handled        |
| Clear filters         | Live   | Single button resets all params                           |

## Competitor Profile (app/competitor/[id]/page.jsx)

| Capability                  | Status | Notes                                                                                       |
| --------------------------- | ------ | ------------------------------------------------------------------------------------------- |
| Stats grid                  | Live   | 9 metrics: wins, losses, win rate, gold, total medals, podium %, champ %, avg WFM, entries  |
| Round results visualization | Live   | Color-coded W/L squares across all rounds in all entries                                    |
| Radar chart                 | Live   | 6 dimensions (win rate, podium %, champ %, medals, activity, WFM) with peer average overlay |
| Match timeline              | Live   | Stacked bar chart per entry; gi (blue) vs nogi (violet); losses as negative bars            |
| Competition history table   | Live   | Date, competition, type badge, division, record, placement, medals                          |
| Profile pills               | Live   | Belt badge, weight class, age group, academy                                                |

## UI / Design

| Capability           | Status | Notes                                                              |
| -------------------- | ------ | ------------------------------------------------------------------ |
| Dark mode default    | Live   | Ultra-dark backgrounds (#0A0A0F)                                   |
| Light mode           | Live   | Theme toggle via next-themes (attribute="class")                   |
| Glass morphism       | Live   | CSS custom properties for bg, border, hover, highlight             |
| Belt color system    | Live   | 9 HSL colors mapped to CSS variables                               |
| Staggered animations | Live   | 40ms delay per row on table and history entries                    |
| Responsive layout    | Live   | Mobile-first column hiding (`hidden md:table-cell`), card stacking |
| Gradient accents     | Live   | Top + left border gradients on cards, podium ambient glow          |

## Analytics

| Capability          | Status | Notes                                             |
| ------------------- | ------ | ------------------------------------------------- |
| PostHog integration | Live   | Client-side tracking via posthog-js               |
| Analytics proxy     | Live   | `/ingest` route via proxy.js to avoid ad blockers |

## Not Yet Implemented

| Capability                     | Status  | Notes                                                                    |
| ------------------------------ | ------- | ------------------------------------------------------------------------ |
| Database integration           | Planned | Firestore migration; currently sheet-only                                |
| Adult division support         | Planned | Current data is kids-only; adult belt ranks (blue-black) not yet handled |
| Seasons / time-scoped rankings | Planned | No season concept; all data is lifetime aggregate                        |
| Weighted scoring algorithm     | Planned | Current ranking is raw win count + win rate tiebreaker                   |
| SEO / Open Graph tags          | Planned | No meta tags, no social sharing previews                                 |
| Live competition tracking      | Planned | Real-time results during events                                          |
| Mobile-optimized experience    | Partial | Responsive columns but filter bar and charts not mobile-tuned            |
| Authentication / admin panel   | Planned | Overrides are manual JSON edits; no admin UI                             |

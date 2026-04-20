# Easton BJJ Competition Leaderboard -- Design Document

Date: 2026-03-05

## Overview

A public-facing competition leaderboard for Easton BJJ gym. Tracks adults and kids
competition results, displays rankings by win count, and provides filtering across
belt rank, age division, weight class, and date range. Designed for future migration
from static seed data to Firestore.

## Stack

- Next.js 16 (App Router, Turbopack)
- JavaScript (.jsx)
- shadcn/ui + Tailwind CSS
- Static seed data (20 entries) with abstracted data layer

## Data Model

### Competitor

| Field       | Type   | Notes                                                                 |
|-------------|--------|-----------------------------------------------------------------------|
| id          | string | UUID                                                                  |
| name        | string | Full name                                                             |
| academy     | string | Gym affiliation                                                       |
| belt        | enum   | Adults: white, blue, purple, brown, black. Kids: white, grey, yellow, orange, green |
| ageDivision | enum   | "adult" or "kids"                                                     |
| weightClass | string | e.g. "Lightweight", "Medium Heavy", "Rooster"                        |

### Match

| Field           | Type          | Notes                                                        |
|-----------------|---------------|--------------------------------------------------------------|
| id              | string        | UUID                                                         |
| competitorId    | string        | FK to Competitor                                             |
| date            | string (ISO)  | Date of competition                                          |
| competition     | string        | Tournament name                                              |
| result          | enum          | "win", "loss", "draw", "dq"                                 |
| method          | enum          | "submission", "points", "decision", "dq", "advantage", "penalty" |
| opponentName    | string        |                                                              |
| opponentAcademy | string        |                                                              |
| opponentBelt    | enum          | Same belt enum as Competitor                                 |
| pointsScored    | number        |                                                              |
| pointsAgainst   | number        |                                                              |
| advantages      | number        |                                                              |
| penalties       | number        |                                                              |
| duration        | string        | e.g. "5:30"                                                  |

### Derived Stats (computed, not stored)

wins, losses, draws, winRate, submissionRate, avgPointsScored, avgPointsAgainst,
pointDifferential

## Pages

### `/` -- Dashboard

- Hero stat cards row: total competitors, total matches, total submissions (3 cards)
- Two-column layout below:
  - Left: "Top Adults" card (top 5 by wins) + "Top Kids" card (top 5 by wins)
  - Right: "Recent Results" card (last 10 match results across all competitors)
- Competitor names link to their profile

### `/leaderboard` -- Full Leaderboard

- Filter bar at top: age division toggle, belt dropdown, weight class dropdown,
  date range picker, competition dropdown
- Filters persist as URL search params (shareable/bookmarkable)
- shadcn/ui DataTable with columns: Rank, Name, Belt (colored badge), Weight Class,
  Wins, Losses, Win %, Submissions, Pts/Match
- Sortable columns
- Rows link to competitor profile

### `/competitor/[id]` -- Competitor Profile

- Header card: name, academy, belt (badge), weight class, age division
- Stats row: wins, losses, draws, win rate, submission rate, avg points scored,
  avg points against
- Match history table: date, competition, opponent, opponent academy, result
  (color-coded), method, points scored/against, duration
- Filterable by date range

## Components

| Component    | Description                                                      |
|--------------|------------------------------------------------------------------|
| BeltBadge    | Colored badge per belt rank                                      |
| ResultBadge  | Green=win, red=loss, amber=draw, muted gray=DQ                  |
| StatCard     | Reusable metric card (value + label)                             |
| FilterBar    | Composable filter controls                                       |
| Nav          | Top navigation: logo/gym name, nav links, dark mode toggle       |

## Visual Design

- Dark mode default with light mode toggle
- Neutral base palette (zinc/slate grays)
- Belt colors as primary color system:
  - White: #f5f5f5 (dark text), Blue: #1e40af, Purple: #7e22ce,
    Brown: #92400e, Black: #171717
  - Kids -- Grey: #6b7280, Yellow: #eab308, Orange: #ea580c, Green: #16a34a
- Result colors: Win=green, Loss=red, Draw=amber, DQ=muted gray
- Inter or Geist Sans for body, monospace for numeric stats
- Max-width container (~1280px), no sidebar
- Mobile responsive: tables collapse to card layout, filters stack vertically

## Ranking

Win count, ties broken by win percentage. Data model supports future weighted and
composite scoring without schema changes.

## Data Access Layer

All data access goes through `lib/data/index.js`:

- getCompetitors(filters?)
- getCompetitorById(id)
- getMatches(filters?)
- getMatchesByCompetitor(competitorId)
- getLeaderboard(filters?, sortBy?)
- getStats()

Components never import seed data directly. When migrating to Firestore, only this
file changes.

## Seed Data

20 realistic entries: mix of adults and kids, various belts and weight classes.
Realistic BJJ tournament names (IBJJF Denver Open, Grappling Industries, NAGA, etc.)
and submission types (armbar, triangle, RNC, etc.).

## Future Considerations

- Google Sheets API integration as intermediate data source
- Firestore migration (competitors + matches collections, same schema)
- Weighted point system for ranking (submission win=5, points win=3, decision=2, draw=1)
- Composite scoring metric combining win rate, finish rate, activity, point differential

# Plan: Google Sheets Directory Integration

## Context

Competition sheet IDs are currently hardcoded in the `GOOGLE_SHEET_IDS` env var (7 sheets from 2024). A directory Google Sheet (`1t2Ih3r_yL6128hP42kLsQ-MBMmfArlP1XNzUw1zr9I8`) lists all 27 competitions across 2023-2026 with metadata (event/year multipliers, scrape/results flags). This plan makes the directory sheet the source of truth for competition discovery, replacing the env var approach.

Additionally, the auth layer uses `google.auth.GoogleAuth` which silently drops the `subject` parameter needed for domain-wide delegation. Newer/2023 sheets that are only accessible via impersonation return 403. Switching to `google.auth.JWT` fixes this -- confirmed via testing.

## Step 1: Fix auth -- GoogleAuth to JWT

**File:** `lib/data/sheets.js` (lines 9-31)

Replace `new google.auth.GoogleAuth(...)` with `new google.auth.JWT(...)`. Read `GOOGLE_WORKSPACE_ADMIN_EMAIL` from env for the `subject` parameter. When the env var is unset, `subject` is null and JWT behaves identically to GoogleAuth for directly-shared sheets.

## Step 2: Add directory sheet fetching + dynamic tab/row detection

**File:** `lib/data/sheets.js`

**2a.** New export `fetchDirectoryEntries(directorySheetId)`:
- Reads `Sheet1!A2:G100` (skip header row)
- Parses each row into `{ date, event, eventMultiplier, yearMultiplier, scrape, results, spreadsheetId }`
- Extracts spreadsheet ID from Results Link URL via regex `/spreadsheets\/d\/([a-zA-Z0-9_-]+)/`
- Skips empty separator rows

**2b.** New internal function `resolveResultsTab(sheets, spreadsheetId)`:
- Gets tab names via `sheets.spreadsheets.get()`
- Returns first match from priority list: `["Results", "All Results"]`
- Falls back to the first tab
- Handles the two 2023 problem sheets: "All Results" (8/12/23 GI) and "Athlete List" (8/26/23 F2W)

**2c.** Rewrite `fetchCompetitionResults()` to detect header row dynamically:
- Fetch `'{tab}'!A1:R1000` instead of hardcoded `Results!A67:R1000`
- Scan for header row by finding "Academy" in column A
- Return rows after the header
- Handles 2023 sheets (header at ~row 58) and 2024+ sheets (header at row 66)

**2d.** New export `normalizeDirectoryDate(dateStr)`:
- Converts "M/D/YY" to "YYYY-MM-DD" ISO format
- Shared by the sync route for overriding metadata

## Step 3: Database migration -- multiplier columns

**New file:** `supabase/migrations/007_competitions_multipliers.sql`

```sql
ALTER TABLE competitions ADD COLUMN IF NOT EXISTS event_multiplier NUMERIC;
ALTER TABLE competitions ADD COLUMN IF NOT EXISTS year_multiplier NUMERIC;
```

Must be applied in Supabase dashboard before deploying code.

## Step 4: Update env validation

**File:** `lib/env.js`

Add optional var warnings in `validateSyncEnv()` for `GOOGLE_DIRECTORY_SHEET_ID` and `GOOGLE_WORKSPACE_ADMIN_EMAIL`. These are not required -- the system gracefully falls back when they are absent.

## Step 5: Rewrite sync route sheet discovery

**File:** `app/api/sync/route.js` (lines 191-222)

Replace the current `sync_sources -> env var` resolution with a three-tier fallback:

1. **Directory sheet** (if `GOOGLE_DIRECTORY_SHEET_ID` is set): call `fetchDirectoryEntries()`, filter to `scrape=TRUE AND results=TRUE AND spreadsheetId != null`, extract sheet IDs + metadata, upsert into `sync_sources` with `added_by: "directory"`
2. **sync_sources table** (existing fallback)
3. **GOOGLE_SHEET_IDS env var** (existing fallback)

After fetching raw sheet data, override metadata from directory when title parsing fails (empty date from `parseTitle()`). This fixes the 2023 sheets with non-standard titles like "NAGA Denver 10/7/23 List & Results" while preserving existing competition IDs for the 7 already-imported sheets.

Always apply multipliers from directory metadata to competition objects.

Update the competition upsert to include `event_multiplier` and `year_multiplier`.

## Step 6: Carry multipliers through data layer

**File:** `lib/data/transform.js` (line 247-252) -- add `eventMultiplier` and `yearMultiplier` to competition objects in `transformSheetData()`.

**File:** `lib/data/index.js` (lines 59-66) -- add `eventMultiplier` and `yearMultiplier` to `mapCompetition()`. Not used by frontend yet (future weighted scoring), but available in the data pipeline.

## New Environment Variables

| Variable | Required | Value |
|----------|----------|-------|
| `GOOGLE_DIRECTORY_SHEET_ID` | No | `1t2Ih3r_yL6128hP42kLsQ-MBMmfArlP1XNzUw1zr9I8` |
| `GOOGLE_WORKSPACE_ADMIN_EMAIL` | No | `jakesciotto@eastontc.com` |

Both need to be added to Vercel env vars for production.

## Files Changed

| File | Change |
|------|--------|
| `lib/data/sheets.js` | JWT auth, directory fetch, tab resolution, header detection |
| `lib/env.js` | Optional var warnings |
| `app/api/sync/route.js` | Directory discovery, metadata override, multiplier persistence |
| `lib/data/transform.js` | Carry multipliers through competition objects |
| `lib/data/index.js` | Map multiplier fields from DB rows |
| `supabase/migrations/007_competitions_multipliers.sql` | New migration |

## Verification

1. Run sync locally and confirm all 27 sheets (where Scrape=TRUE and Results=TRUE) are fetched
2. Confirm 2023 sheets with non-standard tab names ("All Results", "Athlete List") return data
3. Confirm 2023 sheets with variable header positions have rows correctly parsed
4. Confirm existing 7 competition IDs are unchanged (no orphaned entries)
5. Confirm `event_multiplier` / `year_multiplier` populated in competitions table
6. Confirm fallback works when `GOOGLE_DIRECTORY_SHEET_ID` is unset
7. Run sync twice to verify idempotency

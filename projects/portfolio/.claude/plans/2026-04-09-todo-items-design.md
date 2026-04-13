# TODO Items Design Spec

**Date:** 2026-04-09
**Scope:** 5 items from TODO.md -- about tile theme, WakaTime sizing, Spotify header, Trakt separation, Strava cap

---

## 1. WakaTime Primary Stat Sizing

**Problem:** WakaTime tile uses `text-4xl` for its primary number while the same-sized Oura and Todoist tiles use `text-3xl`.

**Fix:** Change `wakatime-tile.jsx:79` from `text-4xl` to `text-3xl`.

**Files:** `app/components/wakatime-tile.jsx`

---

## 2. About Tile Theme Alignment

**Problem:** The about tile uses non-standard font sizes (`text-[13px]`, `text-[11px]`, `text-[10px]`) and a layout pattern (numbered list + border-l quote card) that diverges from the typography conventions used in other content tiles like education and experience.

**Fix:** Normalize typography to match the standard Tailwind scale used across the site:

| Element | Current | Target |
|---------|---------|--------|
| Heading | `text-lg font-semibold font-mono` | No change (already consistent) |
| Subtitle | `text-[11px] lowercase` | `text-xs text-muted-foreground` |
| Fact label | `text-[13px] font-semibold` | `text-sm font-semibold text-foreground` |
| Fact detail | `text-[11px] text-muted-foreground` | `text-xs text-muted-foreground` |
| Counter numbers | `text-[10px] font-mono` | `text-xs font-mono` |
| Wife review label | `text-[10px] font-mono uppercase` | `text-xs font-mono uppercase` |
| Wife review quote | `text-sm italic` | `text-sm italic` (no change) |

Keep the numbered counters and BeltIcon -- they add character without breaking the theme.

**Files:** `app/components/about-tile.jsx`

---

## 3. Spotify Now Playing in Header

**Problem:** User wants a scrolling track name in the site header when Spotify is actively playing.

**Design:**

- **New component:** `app/components/header-now-playing.jsx`
  - `'use client'` component
  - Polls `/api/spotify-now-playing` every 30 seconds
  - Renders nothing when `isPlaying` is false
  - When active: small accent-secondary dot + CSS marquee scrolling "track - artist"
  - Cleanup: clears interval and visibility listener on unmount

- **Marquee implementation:** Pure CSS
  - Container: `overflow-hidden flex-1` between logo and icon links
  - Inner span: `@keyframes marquee` using `translateX(100%)` to `translateX(-100%)`
  - Duration ~12s, linear, infinite
  - Text: `text-xs font-mono text-muted-foreground`

- **Header integration:** In `fixed-header.jsx`, place `<HeaderNowPlaying />` between the logo button and the icons div
  - Use `flex-1 overflow-hidden mx-3` on the wrapper to fill available space
  - Hidden below `md` breakpoint (`hidden md:flex`) to avoid mobile crowding

- **Polling:** Independent from the Spotify tile's polling. Same `/api/spotify-now-playing` endpoint, same 30s interval, same visibility-based fetch pattern.

**Files:**
- `app/components/header-now-playing.jsx` (new)
- `app/components/fixed-header.jsx` (modified)
- `app/global.css` (add marquee keyframes)

---

## 4. Trakt Tile Visual Separation

**Problem:** The "now watching / last watched" section and lifetime stats flow together with no visual boundary. Stats should clearly read as "all time."

**Fix:**

- Add a `border-t border-border` divider between the watching section and the stats section
- Add `pt-3` padding above the stats div (currently just `mt-auto`)
- Add a label `"all time"` above the stats row: `text-[10px] uppercase tracking-widest text-muted-foreground mb-1`

**Files:** `app/components/trakt-tile.jsx`

---

## 5. Strava Activity Type Cap

**Problem:** The activity breakdown list overflows the tile when there are many activity types. Labels like "VIRTUAL RI..." truncate.

**Fix:**

- Sort breakdown by count descending (enforce sort order)
- Take the top 8 entries
- If remaining entries exist, sum their counts into an `{ type: 'Other', count: N }` row appended at the end
- Increase label width from `w-20` to `w-24` to accommodate longer activity names like "Virtual Ride" and "Alpine Ski"

**Files:** `app/components/strava-tile.jsx`

---

## Out of Scope

- No changes to API routes
- No changes to caching logic
- No changes to the bento grid layout
- No new dependencies

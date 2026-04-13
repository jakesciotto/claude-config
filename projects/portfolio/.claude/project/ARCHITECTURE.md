# ARCHITECTURE.md

## Stack

- **Framework**: Next.js 16 (App Router, Turbopack)
- **Styling**: Tailwind CSS v4 + CSS custom properties for theming
- **Fonts**: Geist Sans / Geist Mono
- **Animation**: GSAP + ScrollTrigger (scroll-triggered batch reveals), Lenis (smooth scroll)
- **Charts**: Recharts (sparklines, bar charts)
- **Analytics**: PostHog (client + server-side via `posthog-node`)
- **Cache/Storage**: Upstash Redis (token persistence, Spotify data)
- **Deployment**: Vercel

## Directory Layout

```
app/
  layout.jsx              Root layout (Geist fonts, theme init, header/footer)
  page.jsx                Home page - renders BentoGrid with all tiles
  global.css              Theme tokens, grid layout, glassmorphism, grain overlay
  posthog.js              Server-side PostHog client factory
  icon.svg                Favicon (SVG)
  lib/
    utils.js              cn() - clsx + tailwind-merge
  components/
    bento-grid.jsx        GSAP ScrollTrigger batch animation wrapper
    tile.jsx              Base tile wrapper (glassmorphism, accent colors, optional 3D tilt)
    tile-skeleton.jsx     Loading skeleton with accent-colored pulse
    stat-tile.jsx         Reusable stat display (value + label)
    ui/
      sparkline.jsx       Recharts AreaChart wrapper (gradient fill, color mapping)
      tooltip.jsx         Radix tooltip
    fixed-header.jsx      Sticky header (social links via lucide-react)
    footer.jsx            Site footer
    scroll-provider.jsx   Lenis smooth scroll context
    theme-toggle.jsx      Light/dark mode toggle (localStorage)
    hero-tile.jsx         Name + tagline
    hero-name.jsx         Animated name display
    github-tile.jsx       GitHub contribution stats + sparkline
    oura-tile.jsx         Sleep/readiness from Oura Ring
    wakatime-tile.jsx     Coding hours + language breakdown
    spotify-tile.jsx      Listening stats from Spotify
    strava-tile.jsx       All-time activity stats from Strava
    about-tile.jsx        Bio card
    experience-tile.jsx   Work experience timeline
    education-tile.jsx    Education background
    skill-tags.jsx        Tech stack tags
    work-accordion.jsx    Expandable work history
    cert-strip.jsx        Certification badges
    project-tile.jsx      Project showcase
    fun-stats-tile.jsx    Misc stats (unused, replaced by Strava)
    magnetic-link.jsx     Hover-magnetic link effect
    tracked-link.jsx      PostHog-tracked external links
  api/
    github-stats/         GitHub GraphQL (contribution calendar, 7-day commits)
    oura-stats/           Oura Ring OAuth (sleep, readiness, trends)
    oura-callback/        Oura OAuth callback (token exchange + Redis storage)
    spotify-stats/        Spotify stats from Redis cache
    wakatime-stats/       WakaTime API (languages, editors, hours)
    strava-stats/         Strava OAuth (all-time/recent totals, activity breakdown)
  privacy/                Privacy policy page
  terms/                  Terms page
  tweets/                 Tweet showcase page
public/
  img/                    Static images (project screenshots, logos, icons)
```

## Bento Grid

The home page is a 4-column CSS grid (`bento-grid` class in `global.css`) with named tile positions. Each tile is wrapped in the `Tile` component which provides:

- Glassmorphism (backdrop blur, semi-transparent background)
- One of three accent colors (`primary`, `secondary`, `tertiary`) via CSS custom property `--tile-accent`
- Optional 3D tilt effect via `react-parallax-tilt`
- Initial `opacity: 0` for GSAP scroll-triggered fade-in

Desktop layout (4 columns, rows auto-sized):

```
Row 1-2:  Hero(1-3)       | GitHub(3-5)
          Hero(1-3)       | Experience(3-5)
Row 3-4:  Skills(1-3)     | Work(3-5)
Row 5:    About(1-3)      | Oura(3-4)      | WakaTime(4-5)
Row 6:    Education(1-2)  | Certs(2-4)     | Spotify(4-5)
Row 7-8:  Projects(1-3)   | Strava(3-5)
```

Responsive breakpoints:
- **Tablet** (max-width 1024px): 2-column layout, select tiles go full-width
- **Mobile** (max-width 768px): Single column, all tiles stack vertically

## Theming

Two color schemes defined in `global.css` via CSS custom properties:

- **Light**: Off-white background (`#f4f3f0`), teal primary (`#0d9e8a`)
- **Dark**: Navy background (`#08090e`), cyan primary (`#3df0d0`)

Theme is toggled via `theme-toggle.jsx` and persisted in localStorage. A blocking `<script>` in `layout.jsx` prevents FOUC by reading the stored theme before first paint.

## Data Integration Pattern

All API-backed tiles follow the same architecture:

### Server (API Route)

1. **Token management**: In-memory cache with expiry buffer + Redis persistence for refresh token rotation (Oura, Strava use OAuth2 refresh flow)
2. **Data fetching**: `Promise.all` for parallel endpoint calls where possible
3. **Response shape**: Structured JSON with null fallbacks on error
4. **Analytics**: PostHog capture on success and error paths

### Client (Tile Component)

1. `'use client'` directive
2. `useState(null)` for data, render `TileSkeleton` while loading
3. `fetchStats()` checks localStorage cache (15-minute TTL) before hitting API
4. `useEffect` sets up: initial fetch, interval polling (15min), `visibilitychange` listener for refetch on tab focus
5. Cleanup: clear interval + remove event listener on unmount
6. Error fallback: use stale localStorage cache if API fails

### Caching Layers

| Layer | Mechanism | TTL | Purpose |
|-------|-----------|-----|---------|
| Server memory | Module-scoped variable | Token expiry - 60s | Avoid redundant token refreshes |
| Redis | `@upstash/redis` | Permanent | Persist rotated refresh tokens across deploys |
| Client localStorage | Manual key/value | 15 min (900,000ms) | Reduce API calls per visitor |
| GitHub/WakaTime | `next: { revalidate: 300 }` | 5 min | Next.js ISR for fetch deduplication |

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `next` 16.x | Framework (App Router, Turbopack) |
| `react` 19.x | UI library |
| `tailwindcss` 4.x | Utility-first CSS |
| `gsap` | Scroll animations |
| `lenis` | Smooth scrolling |
| `recharts` | Charts (sparklines, bar charts) |
| `@upstash/redis` | Redis client for token/data persistence |
| `posthog-node` | Server-side analytics |
| `posthog-js` | Client-side analytics |
| `react-parallax-tilt` | 3D tilt effect on hero tile |
| `lucide-react` | Icon library |
| `geist` | Font package |
| `radix-ui` | Accessible UI primitives (tooltip) |

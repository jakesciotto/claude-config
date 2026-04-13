# CHANGELOG.md

All notable changes to this project will be documented in this file.


## Change Categories

Use these standard categories for each version entry:

- **Added** — New features or capabilities
- **Changed** — Changes to existing functionality
- **Deprecated** — Soon-to-be removed features
- **Removed** — Removed features
- **Fixed** — Bug fixes
- **Security** — Security vulnerability fixes

---

## Template Entry

Copy and customize this template for new releases:

```
## [X.Y.Z] - YYYY-MM-DD

### Added

- New feature 1

### Changed

- Updated behavior of existing feature

### Fixed

- Bug fix 1

### Security

- Security fix 1
```

---

**Note:** Maintain this changelog by adding entries under `[Unreleased]` during development, then moving them to a versioned section at release time.

## [Unreleased] - 2026-03-19

### Added
- Bento grid layout: 4-column responsive CSS Grid with glassmorphism tiles
- Fixed header with theme toggle, replacing navbar and stats bar
- Hero tile with GSAP letter-stagger animation and tilt effect
- GitHub stats tile with sparkline (recharts)
- Experience tile with years counter
- Work history accordion with expand/collapse
- Oura health tile: hours slept, sleep score, readiness score, sleep trend sparkline
- WakaTime dev tile: total coding hours, daily average, horizontal bar chart of top 5 languages with percentage labels
- Spotify tile: total hours listened, top artist, years of data span
- Education tile: 3 degrees listed
- Certifications strip: horizontal scrollable badges with tooltips
- About tile: personality list
- Projects tile: 5 featured projects with status pills
- Fun stats tile: 8 personality stats in 2-column grid
- Tile entrance animations via GSAP ScrollTrigger
- Grain texture overlay on body
- `grid-auto-flow: dense` responsive breakpoints (4-col desktop, 2-col tablet, 1-col mobile)
- Matter.js physics simulation for skill tags with organize/jumble toggle
- Skills added: k8s, statistical analysis, predictive modeling, prompt engineering, genai, agentic ai
- Recharts sparkline component (`app/components/ui/sparkline.jsx`)
- StatTile reusable component with optional heading, animated counter, and secondary labels
- TileSkeleton loading placeholder component
- ThemeToggle extracted as standalone component
- `useLenis()` hook exposed from ScrollProvider

### Changed
- Consolidated multi-page site (stats, projects, certifications) into single-page bento dashboard
- Color palette evolved: mint `#3df0d0`, coral `#f05545`, violet `#a78bfa` (dark mode)
- Light mode accents: teal `#0d9e8a`, red `#d04535`, purple `#7c5cbf`
- Card surfaces use `--card-glass` with `backdrop-filter: blur(12px)`
- Header shows "js" initials instead of full name (avoids duplication with hero)
- Email updated to jake.sciotto@gmail.com across header and hero
- ScrollProvider fixed ticker cleanup bug (was passing wrong function reference to `gsap.ticker.remove`)
- Skills physics slowed down: gravity 0.3 -> 0.15, air friction 0.02 -> 0.05
- Technical capabilities heading font matched to other tile headers
- Footer wrapped in `max-w-6xl` container

### Removed
- Multi-page routes: `/stats`, `/projects`, `/certifications`
- Navbar component (`nav.jsx`)
- Stats bar component (`stats-bar.jsx`)
- Legacy components: `animated-section.jsx`, `section-title.jsx`, `github-stats.jsx`, `oura-sleep-stats.jsx`, `spotify-stats.jsx`, `wakatime-stats.jsx`, `employment-timeline.jsx`, `project-item.jsx`, `work-project-item.jsx`, `stat-card.jsx`, `info-tooltip.jsx`
- Data visualization components: `commit-texture.jsx`, `sleep-wave.jsx`, `spotify-gradient.jsx`
- `next-mdx-remote` dependency
- Resume link from hero
- Scroll-weight animation from hero name

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Status

**Session:** 2026-02-21 17:17 CST

**In progress:** 2×2 grid layout implemented and Playwright QA tooling installed — needs browser testing to verify visual correctness across viewports.

**Completed this session:**
- `index.html` lines 135–200: Map tab restructured to `.map-grid` with 4 `.map-cell` quadrants: controls (top-left), `#pfiemap` (top-right), `#trendsMain` (bottom-left), `#barChart` (bottom-right)
- `style.css` ~279: Replaced `.map-wrapper`/`.map-below`/`.controls-col`/`.chart-col` rules with `.map-grid` (`display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: 1fr 1fr`) and `.map-cell` styles
- `style.css` ~568 mobile block: Grid collapses to 1-column with order: map(1) → controls(2) → bar(3) → trend(4); min-heights 280px/250px
- `app.js` `updateTrendsChart()` ~line 455: Added `trendsMainTitle` sync and `Plotly.react('trendsMain', ...)` render after the existing `trendsChart` render
- `app.js`: Added `Plotly.Plots.resize(trendsMain)` to loadData setTimeout (~line 745), window.resize handler (~line 880), and map tab switch handler (~line 860)
- Playwright installed: `pfie-web/package.json`, `pfie-web/playwright.config.js`, `pfie-web/tests/responsive.spec.js` created; chromium browser downloaded

**Suspected areas to investigate (start here next session):**
- `style.css` `.map-grid` — verify `grid-template-rows: 1fr 1fr` actually divides the panel height equally; the parent `.tab-panel` must have `display: flex; flex-direction: column; flex: 1` for `1fr` rows to work
- `app.js` `updateTrendsChart()` ~line 522 — `#trendsMain` is in `display:none` tab on initial load; confirm first render succeeds or add a `setTimeout` guard like the existing one in loadData
- `pfie-web/tests/responsive.spec.js` — `.leaflet-legend` selector may not match the actual legend DOM class; verify by inspecting the rendered legend element and update the selector if needed

**Next steps:**
1. Start dev server (`cd pfie-web && python3 -m http.server 8080`) and run `npx playwright test --reporter=list` to get baseline pass/fail
2. Fix any failures — most likely: legend selector in spec, or `.map-grid` rows not filling height (add `height: 100%` to `.tab-panel#tab-map` if needed)
3. Manual check at 1440px: confirm all 4 quadrants are equal size, map tiles render, both charts show data
4. Manual check at 375px: confirm single-column order is correct and each cell has adequate height

---

## Project Overview

**PFIE (Police Firearm Injury Explorer)** — an interactive data visualization dashboard. The repo contains two things:
- `pfie/` — the original R Shiny app (reference only; do not modify unless explicitly asked)
- `pfie-web/` — the active static JS port, deployable to GitHub Pages

## Local Development

The app uses `fetch()` to load CSV data, so it **requires a web server** (won't work via `file://`):

```bash
cd pfie-web
python3 -m http.server 8080
# Open http://localhost:8080
```

There is no build step, bundler, or package manager. All dependencies are loaded from CDN.

## Architecture

### Data Flow

```
CSV files (data/)
  → loadData()           parse + augment with centroid/bounds fallbacks
  → rawData              global store of all rows
  → runFilters()         date range, state, agency type, injury status
  → filteredData
  → drawMapPoints()      Leaflet CircleMarkers / cluster layer
  → updateBarChart()     Plotly bar (injuries by agency type)
  → updateTrendsChart()  Plotly scatter + computed LOESS line
  → updateDataTable()    DataTables with FixedHeader
```

### Key Files

| File | Role |
|------|------|
| `pfie-web/index.html` | All HTML structure, CDN imports, UI elements (sidebar filters, tabs) |
| `pfie-web/js/app.js` | All application logic (~862 lines) — single JS file, no modules |
| `pfie-web/css/style.css` | All styling |
| `pfie-web/data/pfie20142020.csv` | Main dataset (831 KB) |
| `pfie-web/data/statecentroids.csv` | Lat/lon fallbacks when point location is missing |
| `pfie-web/data/statebounds.csv` | State boundary boxes for map fitting |
| `DECISIONS.md` | Design rationale, known issues, remaining tasks — read this first for context |

### External Libraries (CDN)

- **Leaflet 1.9.4** + MarkerCluster — map + clustering
- **Plotly 2.27.0** — bar chart and trends scatter/LOESS chart
- **DataTables 1.13.7** + FixedHeader — data table tab
- **PapaParse 5.4.1** — CSV parsing
- **jQuery 3.7.0** — required by DataTables
- **Flatpickr** (dark theme) — date range pickers in sidebar

### Important Implementation Notes

- **LOESS smoother**: Pure JS Cleveland (1979) implementation in `app.js`. Bandwidth 0.75. Omits iterative robustness steps (accepted deviation from R output).
- **Jitter**: Mulberry32 seeded PRNG. Seed = `jitterSliderValue + 1000`. Deterministic within JS app but differs from R's Mersenne Twister output.
- **Date parsing**: Always append `'T00:00:00'` to date strings before `new Date()` to force local-time (avoids UTC off-by-one errors).
- **Trends chart resize**: Must call `Plotly.Plots.resize()` on tab switch because Plotly measures zero-width when the container is hidden.
- **DataTables column alignment**: Call `columns.adjust()` on tab switch to fix FixedHeader misalignment when the tab was hidden on initial load.
- **Map tile**: CartoDB Positron (matches original Shiny app).

## Working Style Guidelines (Lessons from Session 2026-02-21)

During the first working session, two significant problems occurred that must be avoided:

1. **Output token overflow**: Reading large files (especially `app.js` at 862 lines and `style.css`) in the same response as performing analysis caused the response to exceed the output token maximum and get cut off mid-action.

2. **Silent extended thinking**: Claude spent 11+ minutes in internal reasoning with no visible output before the user had to interrupt. This is unacceptable — if analysis takes more than a few seconds, produce intermediate output to show progress.

**Rules for future sessions in this repo:**
- **Read files one at a time** when diagnosing bugs. Do not batch-read multiple large files in a single response.
- **State your diagnosis immediately** after reading — don't do extended silent reasoning.
- Before reading `app.js` (862 lines) or `style.css`, ask yourself whether a targeted `Grep` for the relevant section would suffice.
- If a bug involves CSS layout + JS toggle logic, read the CSS section first, form a hypothesis, then check JS only if needed.
- Produce a visible working hypothesis before making additional tool calls.

## Deployment (GitHub Pages)

1. Push repo to GitHub
2. Settings → Pages → source = `pfie-web/` folder (or root of branch containing `index.html`)
3. Add `CNAME` file in `pfie-web/` containing the custom domain (single line)
4. Update DNS registrar: CNAME record → `<username>.github.io`
5. Enable "Enforce HTTPS" after DNS propagates

The `.nojekyll` file in `pfie-web/` is required to skip Jekyll processing on GitHub Pages.

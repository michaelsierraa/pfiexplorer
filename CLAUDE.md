# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Status

**Session:** 2026-02-21 17:45 CST

**In progress:** Jitter investigation complete (analysis only, no code changes). Next major task is Option D — point-in-polygon land/coastline jitter bounds.

**Completed this session:**
- 2×2 grid layout fully implemented and Playwright-verified: 19/19 tests pass across 375px, 720px, 1024px, 1440px viewports
- Deep investigation of jitter "static point" bug for incident 437529 (Florida Keys):
  - Confirmed jitter IS applied mathematically (coordinates change at every slider value)
  - Root cause 1: incident 437529's raw coordinates (24.5611, -81.7733) are in Florida Keys water — a data/geocoding issue, not a jitter artifact
  - Root cause 2: jitter base = 0.0153° (medianPosDiff of national data); at national zoom (~11 px/°) max slider (10) = 0.17px — sub-pixel, invisible for isolated points
  - Stacked centroid-fallback points appear to "respond" because their cluster visibly spreads; isolated unique-coordinate points don't visibly move
  - Playwright investigation script at `/tmp/investigate_jitter.mjs` documents the analysis

**Suspected areas to investigate (start here next session):**
- `app.js` `computeJitterAmount()` ~line 305 — jitter scale is tied to data coordinate density, not screen pixels; at national zoom it's always sub-pixel; consider scaling to minimum pixel displacement or screen-space units
- `app.js` `applyJitter()` ~line 48 — `v == null || isNaN(v)` guard skips the `rng()` call, shifting the RNG sequence for all subsequent points; if any point in `pts` has a NaN coordinate (non-numeric string from CSV), downstream points get wrong jitter offsets — worth auditing
- `pfie-web/data/pfie20142020.csv` — incident 437529 and likely other Florida Keys incidents are geocoded to open water; Option D (land polygon check) is the correct fix

**Next steps:**
1. Implement Option D: load a US land/coastline GeoJSON (e.g., from Natural Earth or us-atlas), add point-in-polygon check to jitter via rejection sampling — reject offsets that land in water, fall back to raw coordinate after N attempts
2. Decide on GeoJSON source: Natural Earth 10m land (`ne_10m_land.json`, ~800 KB) or us-atlas state polygons (`states-10m.json`, ~500 KB) — state polygons are preferable since they also enforce state-boundary containment
3. After Option D: address the jitter-scale issue separately (sub-pixel at national zoom) — possible fix: enforce a minimum pixel displacement by converting `jAmt` from degrees to pixels using the current map zoom level

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

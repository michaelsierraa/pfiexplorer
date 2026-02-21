# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Deployment (GitHub Pages)

1. Push repo to GitHub
2. Settings → Pages → source = `pfie-web/` folder (or root of branch containing `index.html`)
3. Add `CNAME` file in `pfie-web/` containing the custom domain (single line)
4. Update DNS registrar: CNAME record → `<username>.github.io`
5. Enable "Enforce HTTPS" after DNS propagates

The `.nojekyll` file in `pfie-web/` is required to skip Jekyll processing on GitHub Pages.

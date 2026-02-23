# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Status

**Session:** 2026-02-23 11:35 CST

**In progress:** All queued tasks resolved this session. Backlog items identified for next session.

**Resolved this session:**
- Renamed "Map" tab → "Plots" (`index.html` line 129) — commit `1a1676b`
- Fixed Plotly legend overlap with subtitle at all screen sizes — commit `7292807`:
  - Both charts: `margin.t: 92 → 120`, `legend.y: 1.12 → 1.0`, added `legend.yanchor: 'bottom'`
  - Root cause: `yref:'container'` title vs paper-coord legend converged at H_plot≈382px
  - Fix: anchor legend bottom to top of plot area (fixed pixel = margin.t), independent of H_plot
- Added `/compact` as step 6 to `~/.claude/commands/update-status.md`

**Task #7 (mobile sidebar close) — deferred, plan ready:**
Option A (CSS-only, recommended): in `style.css` `@media (max-width: 900px)` block (~line 600), add:
```css
.sidebar-toggle.sidebar-open { position: fixed; top: 9px; right: 12px; z-index: 1003; }
.tab-nav-divider { display: none; }
```

**Suspected areas to investigate (start here next session):**
- `css/style.css` line ~600 (`@media (max-width: 900px)`) — Task #7 mobile toggle fix
- `js/app.js` line ~519–523 — y-axis parity: trends uses `tickfont:{size:12}`, bar uses `size:11`; trends `margin.l:55`, bar `margin.l:44`
- `js/app.js` line ~490–510 — trend line toggle: LOESS traces have `showlegend:false`; need to link visibility to the scatter trace legend toggle
- `css/style.css` root/global font sizes — large-screen font scaling for buttons, dropdowns, tabs

**Next steps:**
1. **Task #7**: Apply Option A CSS (2 lines in `style.css` media block)
2. **Y-axis parity**: Align bar chart `yaxis.tickfont` to `size:12` and `margin.l` to 55 to match trends chart
3. **Trend line toggle**: In `updateTrendsChart()`, give each LOESS trace a `legendgroup` matching its scatter trace and set `showlegend:false` + `visible` tied to the scatter's legend state — or use Plotly `legendgroup` to auto-link
4. **Large-screen fonts**: Add `@media (min-width: 1400px)` block in `style.css` scaling up button/tab/select font sizes

---

## Backlog

### Geocoding enrichment — RESOLVED
Audit confirmed all 1,437 production incidents have address-level geocoding from GVA. No centroid placeholders exist. Raw file `raw2014_20GVA.csv` contains city + address fields for all incidents and is available at repo root for reference.

### Jitter — Option D (point-in-polygon bounds)
Implement rejection sampling against us-atlas state polygons to prevent jitter from crossing state lines or landing in water. Load `states-10m.json` at startup alongside existing CSVs; add `pointInPolygon()` check in `drawMapPoints()` before placing jittered marker.

### Jitter — sub-pixel scale at national zoom
`computeJitterAmount()` returns 0.0153° max (1.7 km) at national zoom — sub-pixel and invisible for single-point incidents. Consider scaling jitter to enforce a minimum screen-pixel displacement using `map.getZoom()` and `map.latLngToContainerPoint()`.

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

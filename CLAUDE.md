# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Status

**Session:** 2026-02-23 10:15 CST

**In progress:** Task #7 (mobile sidebar close) — plan presented, awaiting user decision on implementation approach.

**Task #7 plan summary:**
On mobile (≤900px), when the sidebar is open (fixed overlay, z-index 1002), the Filters button in `.tab-nav` is hidden beneath the backdrop (z-index 1001) and unreachable. Two options presented:
- **Option A (recommended, CSS-only):** When `.sidebar-open` class is on the button, add `position: fixed; top: 9px; right: 12px; z-index: 1003` so it floats above the backdrop. Also hide `.tab-nav-divider`. Zero HTML/JS changes.
- **Option B (standard drawer UX):** Add `<button class="sidebar-close-btn" id="sidebarClose">` inside `.sidebar-inner`, hidden on desktop. Requires HTML + CSS + JS changes.

**Other changes this session:**
- Renamed "Map" tab label to "Plots" (`pfie-web/index.html` line 129) — committed `1a1676b`
- Updated `update-status` skill (`~/.claude/commands/update-status.md`) to auto-run `/compact` as step 6

**Suspected areas to investigate (start here next session):**
- `css/style.css` line ~600 (`@media (max-width: 900px)` block) — where Task #7 Option A CSS change goes
- `pfie-web/index.html` line ~62 (`.sidebar-inner`) — where Task #7 Option B HTML change goes
- `pfie-web/js/app.js` line ~891 (event listeners block) — where Task #7 Option B JS change goes

**Next steps:**
1. User decides Option A vs Option B for Task #7
2. Implement chosen option (Option A: 3 lines in `style.css`; Option B: HTML + CSS + JS across 3 files)
3. Test on Chrome mobile emulator at 375px, 768px widths

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

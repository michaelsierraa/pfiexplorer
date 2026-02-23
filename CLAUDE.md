# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Status

**Session:** 2026-02-23 16:15 CST

**In progress:** Working directory renamed from `pfie_claude_project` to `pfiexplorer` to match GitHub repo name. Shell session broken mid-session due to rename — must start fresh next session from `/Users/ms39643/Documents/GitHub/pfiexplorer`.

**Resolved this session:**
- Mobile plot heights: `css/style.css` line 630–631 (`@media (max-width: 900px)`): `.trend-cell` and `.bar-cell` `min-height: 250px → 375px`
- Mobile trends x-axis: `js/app.js` line 523–525: yearly ticks (`dtick: 'M12'`, `tickformat: '%Y'`), `-35°` rotation on mobile
- Toolbar scrolls away on mobile: `css/style.css` (`@media (max-width: 900px)`): scroll container moved from `.map-grid` to `#tab-map`; `.map-grid` now `flex: none`
- Mobile buttons 2×2 grid: `css/style.css` (`@media (max-width: 560px)`): `flex: 0 0 calc(50% - 4px)` per button
- GitHub deployment: repo created at `github.com/michaelsierraa/pfiexplorer`; Actions workflow at `.github/workflows/deploy.yml` serves `pfie-web/` — auto-deploys on every push to `main`
- Live URL: **https://michaelsierraa.github.io/pfiexplorer/**

**Suspected areas to investigate (start here next session):**
- `js/app.js` line 524 — `tick0: '2014-01-01'` is hardcoded; derive from `filteredData` min date if tick alignment feels off after filtering
- `css/style.css` line 629 — `.map-cell--map { min-height: 280px; }` on mobile; may feel short relative to 375px charts

**Next steps:**
1. Verify app loads correctly at `https://michaelsierraa.github.io/pfiexplorer/`
2. Add `pfiexplorer` repo to GitHub Desktop (File → Add Local Repository → `/Users/ms39643/Documents/GitHub/pfiexplorer`)
3. Standard push workflow: Claude Code edits + commits → push via `git push` or GitHub Desktop "Push origin"

---

## Backlog

### Geocoding enrichment — RESOLVED
Audit confirmed all 1,437 production incidents have address-level geocoding from GVA. No centroid placeholders exist. Raw file `raw2014_20GVA.csv` contains city + address fields for all incidents and is available at repo root for reference.

### Jitter — RESOLVED (not a to-do)
Jitter backlog items (Option D point-in-polygon, sub-pixel scale) were reviewed and decided against. No jitter changes planned.

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

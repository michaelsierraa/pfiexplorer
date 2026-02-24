# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Status

**Session:** 2026-02-24 11:10 CST

**In progress:** Session complete. All changes committed and pushed to `michaelsierraa/pfiexplorer` main (commits `051ecd1`, `e6f2b76`). GitHub Actions deploy triggered.

**Resolved this session:**
- `README.md` created at repo root — two-section (public overview + technical reference); covers data source, dataset scope, team, citation, architecture, local dev, deployment
- `pfie-web/index.html` `<head>` (lines 7–20) — added `<meta name="description">`, Open Graph (`og:type`, `og:url`, `og:title`, `og:description`), and Twitter Card tags
- `DECISIONS.md` removed from git tracking (`git rm --cached`) and added to `.gitignore` line 6 — file stays local only
- GitHub repo description and topics updated via `gh repo edit` (topics: gun-violence, law-enforcement, data-visualization, javascript, leaflet, plotly, open-data, police)
- Bar chart `font.size` unified 12 → 13 to match trends chart (`app.js` line 443)
- Both chart legend `font.size` bumped 11 → 13 (`app.js` lines 446, 529)
- `.plot-title-main` bumped 14px → 16px; `.plot-title-sub` bumped 12px → 13px (`style.css` lines 399, 405)
- DataTable search bar moved next to length dropdown: `dom: "<'dt-top'lf>rtip"` added to DataTable init (`app.js` line 592); `.dt-top` flex layout + float overrides added to `style.css` lines 480–485

**Suspected areas to investigate (start here next session):**
- `js/app.js` line 524 — `tick0: '2014-01-01'` hardcoded; derive from `filteredData` min date if tick alignment is off after filtering
- `css/style.css` ~line 648 — `.map-cell--map { min-height: 280px }` on mobile; may feel short relative to chart heights

**Next steps:**
1. Verify live app at `https://michaelsierraa.github.io/pfiexplorer/` after Actions deploy completes
2. Custom domain: add `CNAME` file to `pfie-web/` with `pfiexplorer.com`, configure DNS, set in GitHub Pages settings (see Backlog)
3. Logo: create logo files in `pfie-web/img/`, wire into `.header-title` in `index.html` and add favicon `<link>` tags in `<head>` (see Backlog)

---

## Backlog

### Geocoding enrichment — RESOLVED
Audit confirmed all 1,437 production incidents have address-level geocoding from GVA. No centroid placeholders exist. Raw file `raw2014_20GVA.csv` contains city + address fields for all incidents and is available at repo root for reference.

### Jitter — RESOLVED (not a to-do)
Jitter backlog items (Option D point-in-polygon, sub-pixel scale) were reviewed and decided against. No jitter changes planned.

### Custom domain — TODO
Point `pfiexplorer.com` (owned) to the GitHub Pages site. Steps:
1. Add `CNAME` file to `pfie-web/` containing `pfiexplorer.com` (single line, no `https://`)
2. At DNS registrar: add CNAME record `www` → `michaelsierraa.github.io`, and ALIAS/ANAME record for apex (`@`) → `michaelsierraa.github.io` (or use GitHub's four A records for the apex)
3. In GitHub repo Settings → Pages → Custom domain: enter `pfiexplorer.com`, save
4. Wait for DNS propagation, then enable "Enforce HTTPS"
5. After custom domain is live, update citation URL in `pfie-web/index.html` line 254

### Logo — TODO
Create a logo and integrate it in two places:
1. **App header** — replace or supplement the text title in `pfie-web/index.html` `.header-title` (line 48–52) with an `<img>` tag pointing to a logo file (e.g., `pfie-web/img/logo.svg`)
2. **Browser/tab icon (favicon)** — replace the default globe with the logo; add `<link rel="icon">` tags in `<head>` of `index.html` pointing to appropriately sized PNG/SVG files in `pfie-web/img/`
- Logo file(s) to be created and placed in a new `pfie-web/img/` directory

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

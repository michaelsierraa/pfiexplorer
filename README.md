# Police Firearm Injury Explorer (PFIE)

**Live app:** [https://michaelsierraa.github.io/pfiexplorer/](https://michaelsierraa.github.io/pfiexplorer/)

An interactive data visualization dashboard for exploring firearm injuries sustained by active-duty law enforcement officers in the United States.

---

## Overview

PFIE provides researchers, policymakers, journalists, and the public with an accessible tool for exploring incident-level data on police officers shot fatally or nonfatally by suspects. The dashboard supports filtering by date range, state, agency type, and injury outcome, and presents data through an interactive map, charts, and a searchable data table.

### Data Source

PFIE is built on data compiled by the [Gun Violence Archive (GVA)](https://www.gunviolencearchive.org/about), a non-partisan, non-profit organization that aggregates information on gun violence incidents from over 7,500 law enforcement, media, government, and commercial sources daily.

### Dataset Scope

| | |
|---|---|
| **Coverage** | 2014–2020 |
| **Incidents** | 1,437 |
| **Geography** | United States (50 states + D.C.) |

**Cases included:**
- Victim is a sworn, active-duty law enforcement officer
- Shot fatally or nonfatally with a firearm by a suspect
- Shot somewhere on their body or on-person equipment (e.g., radio, ballistic helmet)

**Cases excluded:**
- Retired or off-duty officers
- Corrections officers or federal law enforcement (FBI, ATF, U.S. Marshals, etc.)
- Blue-on-blue shootings (officer shot by another officer)
- Accidental self-inflicted or suicide-by-firearm incidents

### Features

- **Interactive map** — incident-level markers with clustering; filter by date, state, agency type, and injury outcome
- **Bar chart** — injuries by agency type (fatal vs. nonfatal)
- **Trends chart** — incident counts over time with LOESS smoothing
- **Data table** — searchable, sortable incident records with source links
- **Download** — export filtered data as CSV, JSON, or plain text

### Development Team

**Principal investigators:**
- [Michael Sierra-Arévalo](https://www.sierraarevalo.com) (University of Texas) — study design, data coding, app development
- [Justin Nix](https://jnix.netlify.app/about) (University of Nebraska–Omaha) — study design, data coding

**Research assistants (coding support):**
Aidan Bach, Tommy Flaherty, Ciara Garcia, Kateryna Kaplun, Philip Phu Pham, and Jamie Villarreal

### Preferred Citation

> Sierra-Arévalo, M., Nix, J., Bach, A., Flaherty, T., Garcia, C., Kaplun, K., Pham, P. P., & Villarreal, J. (2024). *The Police Firearm Injury Explorer.* Retrieved from [https://michaelsierraa.github.io/pfiexplorer/](https://michaelsierraa.github.io/pfiexplorer/)

---

## Technical Reference

### Repository Structure

```
pfiexplorer/
├── pfie/               Original R Shiny app (reference only — do not modify)
└── pfie-web/           Active static JS port (GitHub Pages deployable)
    ├── index.html      All HTML structure, CDN imports, UI elements
    ├── css/style.css   All styling
    ├── js/app.js       All application logic (~860 lines, single file)
    └── data/
        ├── pfie20142020.csv      Main dataset (831 KB, 1,437 incidents)
        ├── statecentroids.csv    Lat/lon fallbacks for missing point locations
        └── statebounds.csv       State boundary boxes for map fitting
```

### Architecture

```
CSV files (data/)
  → loadData()           parse + augment with centroid/bounds fallbacks
  → rawData              global store of all rows
  → runFilters()         date range, state, agency type, injury status
  → filteredData
  → drawMapPoints()      Leaflet CircleMarkers / cluster layer
  → updateBarChart()     Plotly bar (injuries by agency type)
  → updateTrendsChart()  Plotly scatter + LOESS smoothing line
  → updateDataTable()    DataTables with FixedHeader
```

### External Libraries (CDN, no build step required)

| Library | Version | Purpose |
|---------|---------|---------|
| Leaflet | 1.9.4 | Interactive map |
| Leaflet MarkerCluster | 1.5.3 | Incident clustering |
| Plotly | 2.27.0 | Bar and trends charts |
| DataTables + FixedHeader | 1.13.7 | Data table tab |
| PapaParse | 5.4.1 | CSV parsing |
| jQuery | 3.7.0 | Required by DataTables |
| Flatpickr (dark theme) | latest | Date range pickers |

### Local Development

The app uses `fetch()` to load CSV data, so it requires a local web server — it will not work via `file://`.

```bash
cd pfie-web
python3 -m http.server 8080
# Open http://localhost:8080
```

There is no build step, bundler, or package manager. All dependencies are loaded from CDN.

### GitHub Pages Deployment

1. Push repo to GitHub
2. **Settings → Pages** → set source to the `pfie-web/` folder
3. For a custom domain: add a `CNAME` file in `pfie-web/` containing just the domain name (e.g., `pfiexplorer.com`)
4. Update DNS at your registrar: add a CNAME record pointing to `<username>.github.io`
5. In **Settings → Pages → Custom domain**, enter the domain and save
6. Enable "Enforce HTTPS" after DNS propagates

The `.nojekyll` file in `pfie-web/` is required to prevent GitHub Pages from applying Jekyll processing.

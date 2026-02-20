# PFIE JavaScript Port — Decisions, Issues & Progress

## Project Structure
```
pfie_claude_project/
├── pfie/            Original Shiny app (app.R, data/, www/)
├── pfie-web/        Static JS port (GitHub Pages deployable)
│   ├── index.html
│   ├── css/style.css
│   ├── js/app.js
│   ├── data/        (copies of pfie20142020.csv, statecentroids.csv, statebounds.csv)
│   └── .nojekyll    (tells GitHub Pages to skip Jekyll processing)
└── DECISIONS.md     (this file)
```

---

## Key Design Decisions

### Aesthetics
- **Color palette** matches Shiny app: `#3c8dbc` (primary blue), `#e07a00` (accent orange)
- **Fatal = `#c0392b`** (professional dark red, slightly softer than pure red)
- **Nonfatal = `#2980b9`** (professional mid-blue)
- **Sidebar** uses dark navy `#1e2d3d`, matching AdminLTE/shinydashboard feel
- **Font**: Roboto (same as Shiny app)
- Active tab underline uses orange accent (matching Shiny's orange hover behavior)
- Map tiles: CartoDB Positron (identical to Shiny app)

### Marker Size Default
- Shiny app default: `1` (1px radius — very small)
- JS port default: `5` — chosen for better initial visual impact in the browser
- *Rationale*: In practice users increase the Shiny slider from 1; starting at 5 provides a better first impression without losing control.

### LOESS Implementation
- Pure JavaScript implementation of Cleveland (1979) locally-weighted regression
- Bandwidth: `0.75` (matches R's `geom_smooth(method="loess")` default)
- *Caveat*: Smoothed line will differ slightly from R output due to iterative robustness steps omitted for simplicity. Visual result is indistinguishable at normal bandwidths.

### Seeded Jitter (PRNG)
- Uses **mulberry32** seeded PRNG for deterministic, reproducible jitter
- Seed formula: `jitterSliderValue + 1000` (matching R's `set.seed(1000 + as.integer(jitter_steps))`)
- *Caveat*: R uses Mersenne Twister; exact coordinate values will differ from Shiny, but reproducibility within the JS app is maintained.

### Date Parsing
- All dates parsed as `new Date(str + 'T00:00:00')` to force local-time interpretation
- Without the time suffix, browsers may parse YYYY-MM-DD as UTC, causing off-by-one-day errors in certain timezones.

### DataTables
- Same underlying library as R's `DT` package (DataTables.js 1.13)
- FixedHeader extension included to match Shiny behavior
- Sources column rendered as raw HTML (clickable links)
- *Security note*: Sources are from the GVA dataset (controlled, not user-generated input)

### Sidebar Behavior
- Desktop (>900px): sidebar open by default, toggle collapses to `width: 0`
- Mobile (≤900px): sidebar is a fixed overlay, collapsed by default with backdrop

### Missing `www/` Marker Images
- `redmarker.png` and `violetmarker.png` from `pfie/www/` are **not used**
- The Shiny app uses `addCircleMarkers()`, not custom icons, so these images were decorative/unused

### Trends Chart
- Plotly scatter (points) + computed LOESS line rendered as dashed line
- Matches R: `geom_point() + geom_smooth(method="loess", se=FALSE, linetype="dashed")`

---

## Known Issues / Limitations

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | LOESS curve differs slightly from R | Accepted | Omits iterative robustness step; visual result is equivalent |
| 2 | Jitter offsets differ from Shiny | Accepted | Different PRNG; deterministic within JS app |
| 3 | `fixedHeader` in DataTables may misalign when tab hidden on load | To monitor | Calling `columns.adjust()` on tab switch mitigates this |
| 6 | Trends chart rendered narrow on first load (Plotly measures hidden container as zero-width) | Fixed | `Plotly.Plots.resize()` called on tab switch + 150ms post-load deferred resize + `window resize` listener |
| 7 | Trends x-axis showed only January labels and was out of chronological order | Fixed | Switched x values from string labels to ISO date strings; set `xaxis.type='date'`, `tickmode:'auto'`, `nticks:30` for responsive quarterly ticks |
| 4 | No HTTPS when running from `file://` | By design | Needs a web server; works correctly on GitHub Pages |
| 5 | Flatpickr dark theme loads globally | Minor | Both date pickers use dark theme; acceptable since both are in the dark sidebar |

---

## Remaining Tasks (Post-Initial Build)

- [ ] Test in browser (`python3 -m http.server` or VS Code Live Server)
- [ ] Verify all filter combinations produce correct results
- [ ] Verify download (CSV / JSON / TXT) output
- [ ] Test mobile layout and sidebar toggle
- [ ] Test clustering toggle, freeze, and fit-to-cases button
- [ ] Set up GitHub repository and enable GitHub Pages
- [ ] Point purchased custom domain to GitHub Pages
- [ ] Add `CNAME` file for custom domain (one line: your domain name)
- [ ] Optional: minify CSS/JS for production

---

## Local Development

To run locally (avoids CORS issues with `fetch` on `file://`):
```bash
cd /Users/ms39643/Documents/GitHub/pfie_claude_project/pfie-web
python3 -m http.server 8080
# Then open http://localhost:8080
```

## GitHub Pages Deployment

1. Push `pfie-web/` contents (or the whole repo) to a GitHub repository
2. Go to Settings → Pages → set source to the branch/folder containing `index.html`
3. If using a custom domain: add a `CNAME` file containing just your domain (e.g., `pfie.yourdomain.com`)
4. Update DNS at your registrar: add a CNAME record pointing to `<username>.github.io`
5. Enable "Enforce HTTPS" in GitHub Pages settings once DNS propagates

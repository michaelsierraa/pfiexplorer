'use strict';

/* ══════════════════════════════════════════════════════════════════════════
   PFIE Web — app.js
   JavaScript port of the Shiny Police Firearm Injury Explorer
   ════════════════════════════════════════════════════════════════════════ */

// ── CONSTANTS ────────────────────────────────────────────────────────────────
const FATAL_COLOR    = '#c0392b';
const NONFATAL_COLOR = '#2980b9';
const FONT_FAMILY    = 'Source Sans 3, sans-serif';
const DATE_MIN       = '2014-01-01';
const DATE_MAX       = '2020-12-31';

// ── APPLICATION STATE ────────────────────────────────────────────────────────
let rawData      = [];       // All parsed rows from CSV
let stateBounds  = {};       // { StateName: {x1,y1,x2,y2} }
let filteredData = [];       // Currently filtered subset

// Map state
let map          = null;
let markerLayer  = null;     // L.layerGroup for unclustered markers
let clusterLayer = null;     // L.markerClusterGroup for clustered markers
let useClusters  = false;
let isFrozen     = false;
let userMovedMap = false;
let lastFitTime  = 0;
let lastState    = null;     // tracks previous state filter for reset logic

// Chart / table handles
let dtInstance   = null;     // DataTables instance
let dtInitialized = false;

// ── SEEDED PRNG (mulberry32) ──────────────────────────────────────────────────
// Used to produce deterministic jitter (same slider value = same offsets).
// R uses Mersenne Twister so exact values differ, but reproducibility is preserved.
function mulberry32(seed) {
  let s = seed >>> 0;
  return function () {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 0x100000000;
  };
}

// Apply uniform jitter in [-amount, +amount] to an array of numbers
function applyJitter(values, amount, seed) {
  const rng = mulberry32(seed >>> 0);
  return values.map(v =>
    v == null || isNaN(v) ? v : v + (rng() * 2 - 1) * amount
  );
}

// ── LOESS SMOOTHER ────────────────────────────────────────────────────────────
// Cleveland (1979) locally-weighted polynomial regression.
// bandwidth: fraction of points used as neighbors (0 < bw ≤ 1, default 0.75).
function loess(xs, ys, bandwidth) {
  const n = xs.length;
  if (n < 3) return ys.slice();

  const bw   = bandwidth || 0.75;
  const span = Math.max(2, Math.floor(bw * n));
  const out  = new Array(n);

  for (let i = 0; i < n; i++) {
    const xi = xs[i];

    // Sort all points by distance from xi, keep span nearest
    const indexed = xs.map((x, j) => ({ j, d: Math.abs(x - xi) }));
    indexed.sort((a, b) => a.d - b.d);
    const nbrs   = indexed.slice(0, span);
    const maxDst = nbrs[nbrs.length - 1].d;

    if (maxDst === 0) { out[i] = ys[i]; continue; }

    // Tricube weights + weighted linear regression
    let sw = 0, swx = 0, swy = 0, swx2 = 0, swxy = 0;
    for (const { j, d } of nbrs) {
      const u  = d / maxDst;
      const w  = Math.pow(1 - Math.pow(u, 3), 3);
      const x  = xs[j];
      const y  = ys[j];
      sw   += w;
      swx  += w * x;
      swy  += w * y;
      swx2 += w * x * x;
      swxy += w * x * y;
    }

    const det = sw * swx2 - swx * swx;
    if (Math.abs(det) < 1e-12) {
      out[i] = swy / sw;
    } else {
      const b1 = (sw * swxy - swx * swy) / det;
      const b0 = (swy - b1 * swx) / sw;
      out[i]   = b0 + b1 * xi;
    }
  }
  return out;
}

// ── DATE UTILITIES ────────────────────────────────────────────────────────────
function parseDate(str) {
  if (!str) return null;
  // Append T00:00:00 to avoid UTC vs local-time ambiguity on date-only strings
  const d = new Date(str + 'T00:00:00');
  return isNaN(d.getTime()) ? null : d;
}

function fmtDate(d) {
  if (!d) return '';
  const y  = d.getFullYear();
  const mo = String(d.getMonth() + 1).padStart(2, '0');
  const da = String(d.getDate()).padStart(2, '0');
  return `${y}-${mo}-${da}`;
}

// Return Date floored to first of month
function floorMonth(d) {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

// "Jan 2017" label for trend chart x-axis
function fmtMonthLabel(d) {
  return d.toLocaleDateString('en-US', { year: 'numeric', month: 'short' });
}

// ── FILTER HELPERS ─────────────────────────────────────────────────────────────
function getFilters() {
  return {
    start:  parseDate(document.getElementById('dateStart').value)  || parseDate(DATE_MIN),
    end:    parseDate(document.getElementById('dateEnd').value)    || parseDate(DATE_MAX),
    state:  document.getElementById('stateSelect').value,
    agency: document.getElementById('agencySelect').value,
    status: document.getElementById('statusSelect').value,
    format: document.getElementById('formatSelect').value,
  };
}

function runFilters() {
  const f = getFilters();
  let d = rawData;

  if (f.start) d = d.filter(r => r._date >= f.start);
  if (f.end)   d = d.filter(r => r._date <= f.end);
  if (f.state  !== 'National') d = d.filter(r => r.state === f.state);
  if (f.agency !== 'All')      d = d.filter(r => r.agencytypelabel === f.agency);
  if (f.status === 'Fatal')    d = d.filter(r => r.statuslabel === 'Fatal');
  if (f.status === 'Nonfatal') d = d.filter(r => r.statuslabel === 'Nonfatal');

  // Per-incident aggregates (mirrors R: group_by(incidentid) %>% summarise)
  const agg = {};
  d.forEach(r => {
    const id = r.incidentid;
    if (!agg[id]) agg[id] = { total: 0, fatal: 0, nonfatal: 0 };
    agg[id].total++;
    if (r.statuslabel === 'Fatal')    agg[id].fatal++;
    if (r.statuslabel === 'Nonfatal') agg[id].nonfatal++;
  });

  filteredData = d.map(r => ({
    ...r,
    _totalofficers: agg[r.incidentid]?.total    ?? 1,
    _totalfatal:    agg[r.incidentid]?.fatal    ?? 0,
    _totalnonfatal: agg[r.incidentid]?.nonfatal ?? 0,
  }));

  document.getElementById('caseCount').textContent =
    `${filteredData.length.toLocaleString()} case${filteredData.length !== 1 ? 's' : ''} shown`;
}

// ── TITLE BUILDER ─────────────────────────────────────────────────────────────
function buildTitleBase() {
  const f = getFilters();

  const agencyDesc = {
    All:     'Police',
    Local:   'Local Police',
    Sheriff: "Sheriff's Deputies",
    State:   'State Police',
    Special: 'Special Police',
  }[f.agency] || 'Police';

  const injuryDesc = {
    All:      'Fatal and Nonfatal Firearm Injuries',
    Fatal:    'Fatal Firearm Injuries',
    Nonfatal: 'Nonfatal Firearm Injuries',
  }[f.status] || 'Firearm Injuries';

  const stateLbl = f.state === 'National' ? 'United States' : f.state;
  const start    = fmtDate(f.start);
  const end      = fmtDate(f.end);

  return `${agencyDesc} ${injuryDesc} — ${stateLbl} — ${start} to ${end}`;
}

// ── MAP ───────────────────────────────────────────────────────────────────────
function initMap() {
  map = L.map('pfiemap', {
    zoomSnap:  0.25,
    zoomDelta: 0.25,
    minZoom:   2,
    maxZoom:   18,
  });

  // CartoDB Positron tiles (matches Shiny app)
  L.tileLayer(
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    {
      attribution: '&copy; <a href="https://carto.com/">CARTO</a> &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      subdomains:  'abcd',
      maxZoom:     19,
    }
  ).addTo(map);

  // Legend (collapsible)
  const legend = L.control({ position: 'bottomright' });
  legend.onAdd = () => {
    const div = L.DomUtil.create('div', 'leaflet-legend');
    div.innerHTML = `
      <div class="legend-header">
        <span class="legend-title">Injury Status</span>
        <button class="legend-toggle" aria-label="Toggle legend">&#9662;</button>
      </div>
      <div class="legend-body">
        <div class="legend-item">
          <span class="legend-dot" style="background:${FATAL_COLOR}"></span>Fatal
        </div>
        <div class="legend-item">
          <span class="legend-dot" style="background:${NONFATAL_COLOR}"></span>Nonfatal
        </div>
      </div>`;

    const btn = div.querySelector('.legend-toggle');
    L.DomEvent.on(btn, 'click', L.DomEvent.stopPropagation);
    L.DomEvent.on(btn, 'click', () => {
      const collapsed = div.classList.toggle('collapsed');
      btn.innerHTML = collapsed ? '&#9656;' : '&#9662;';
    });

    return div;
  };
  legend.addTo(map);

  // Detect user-initiated map moves to suppress auto-fit
  map.on('moveend', () => {
    if (Date.now() - lastFitTime > 400) {
      userMovedMap = true;
    }
  });

  map.fitBounds([[-14, -179], [72, -60]]);
}

function fitMapToData() {
  const f   = getFilters();
  const now = Date.now();
  lastFitTime  = now;
  userMovedMap = false;

  // State-specific bounding box
  if (f.state !== 'National') {
    const b = stateBounds[f.state];
    if (b) {
      map.fitBounds([[b.y1, b.x1], [b.y2, b.x2]]);
      return;
    }
  }

  // Fit to visible points
  const pts = filteredData.filter(r => r.latitude != null && r.longitude != null);
  if (pts.length === 0) {
    map.fitBounds([[-14, -179], [72, -60]]);
    return;
  }
  if (pts.length === 1) {
    map.setView([pts[0].latitude, pts[0].longitude], 8);
    return;
  }
  const lats = pts.map(r => r.latitude);
  const lons = pts.map(r => r.longitude);
  const pad  = 0.05;
  map.fitBounds([
    [Math.min(...lats) - pad, Math.min(...lons) - pad],
    [Math.max(...lats) + pad, Math.max(...lons) + pad],
  ]);
}

// Compute median of consecutive differences (used for adaptive jitter)
function medianPosDiff(arr) {
  const sorted = [...new Set(arr.filter(v => v != null && isFinite(v)))].sort((a, b) => a - b);
  if (sorted.length < 2) return NaN;
  const diffs = [];
  for (let i = 1; i < sorted.length; i++) {
    const d = sorted[i] - sorted[i - 1];
    if (d > 0) diffs.push(d);
  }
  if (!diffs.length) return NaN;
  diffs.sort((a, b) => a - b);
  const m = Math.floor(diffs.length / 2);
  return diffs.length % 2 ? diffs[m] : (diffs[m - 1] + diffs[m]) / 2;
}

function computeJitterAmount() {
  const steps = parseFloat(document.getElementById('jitterScale').value);
  if (steps === 0) return 0;

  const lons    = filteredData.map(r => r.longitude);
  const lats    = filteredData.map(r => r.latitude);
  const stepLon = medianPosDiff(lons);
  const stepLat = medianPosDiff(lats);
  const valids  = [stepLon, stepLat].filter(v => isFinite(v) && v > 0);
  const base    = valids.length ? Math.max(...valids) : 1e-5;

  return (steps / 10) * base;
}

function drawMapPoints() {
  // Clear previous layers
  if (markerLayer)  { map.removeLayer(markerLayer);  markerLayer  = null; }
  if (clusterLayer) { map.removeLayer(clusterLayer); clusterLayer = null; }

  const pts = filteredData.filter(r => r.latitude != null && r.longitude != null);
  if (pts.length === 0) return;

  const radius    = parseInt(document.getElementById('markerSize').value, 10);
  const jAmt      = computeJitterAmount();
  const jSeed     = Math.round(parseFloat(document.getElementById('jitterScale').value)) + 1000;

  const rawLats = pts.map(r => r.latitude);
  const rawLons = pts.map(r => r.longitude);
  const lats    = jAmt > 0 ? applyJitter(rawLats, jAmt, jSeed)     : rawLats;
  const lons    = jAmt > 0 ? applyJitter(rawLons, jAmt, jSeed + 1) : rawLons;

  const markers = pts.map((r, i) => {
    const color = r.statuslabel === 'Fatal' ? FATAL_COLOR : NONFATAL_COLOR;
    const m = L.circleMarker([lats[i], lons[i]], {
      radius,
      color,
      fillColor:   color,
      fillOpacity: 0.78,
      weight:      1.2,
    });
    m.bindPopup(
      `<b>State:</b> ${r.state}<br>` +
      `<b>Date:</b> ${fmtDate(r._date)}<br>` +
      `<b>Incident ID:</b> ${r.incidentid}<br>` +
      `<b>Agency:</b> ${r.agencytypelabel}<br>` +
      `<b>Injury Status:</b> ${r.statuslabel}<br>` +
      `<b>Officers Shot:</b> ${r._totalofficers}<br>` +
      `<b>Fatal:</b> ${r._totalfatal} &nbsp;` +
      `<b>Nonfatal:</b> ${r._totalnonfatal}`
    );
    return m;
  });

  if (useClusters) {
    clusterLayer = L.markerClusterGroup({
      maxClusterRadius:  30,
      spiderfyOnMaxZoom: true,
      singleMarkerMode:  false,
    });
    markers.forEach(m => clusterLayer.addLayer(m));
    map.addLayer(clusterLayer);
  } else {
    markerLayer = L.layerGroup(markers);
    markerLayer.addTo(map);
  }
}

function updateMap() {
  drawMapPoints();
  if (isFrozen) return;

  const f = getFilters();
  const stateChanged = f.state !== lastState;
  lastState = f.state;

  if (stateChanged) {
    // State change always resets the view
    userMovedMap = false;
    fitMapToData();
  } else if (!userMovedMap) {
    fitMapToData();
  }
}

// ── BAR CHART ─────────────────────────────────────────────────────────────────
function updateBarChart() {
  const f       = getFilters();
  const agencies = ['Local', 'Sheriff', 'State', 'Special'];

  // Aggregate counts
  const agg = {};
  agencies.forEach(a => { agg[a] = { Fatal: 0, Nonfatal: 0 }; });
  filteredData.forEach(r => {
    if (agg[r.agencytypelabel]) {
      agg[r.agencytypelabel][r.statuslabel] = (agg[r.agencytypelabel][r.statuslabel] || 0) + 1;
    }
  });

  // Dynamic title (two-line: metric + filter context as subtitle)
  const barMetric = {
    All:      'Fatal and Nonfatal Police Firearm Injuries by Agency Type',
    Fatal:    'Fatal Police Firearm Injuries by Agency Type',
    Nonfatal: 'Nonfatal Police Firearm Injuries by Agency Type',
  }[f.status];
  const stateLbl  = f.state === 'National' ? 'United States' : f.state;
  const agencyLbl = f.agency === 'All' ? 'All Agencies' : f.agency;
  const titleText = `<b>${barMetric}</b><br><span style="font-size:12px;color:#5a6a7a">${stateLbl} · ${agencyLbl} · ${fmtMonthLabel(f.start)} – ${fmtMonthLabel(f.end)}</span>`;

  // Traces
  const traces = [];
  if (f.status !== 'Nonfatal') {
    traces.push({
      x:             agencies,
      y:             agencies.map(a => agg[a].Fatal),
      name:          'Fatal',
      type:          'bar',
      marker:        { color: FATAL_COLOR },
      hovertemplate: '<b>%{x}</b><br>Fatal: %{y}<extra></extra>',
    });
  }
  if (f.status !== 'Fatal') {
    traces.push({
      x:             agencies,
      y:             agencies.map(a => agg[a].Nonfatal),
      name:          'Nonfatal',
      type:          'bar',
      marker:        { color: NONFATAL_COLOR },
      hovertemplate: '<b>%{x}</b><br>Nonfatal: %{y}<extra></extra>',
    });
  }

  const layout = {
    title:         { text: titleText, x: 0.02, xanchor: 'left', yref: 'container', y: 0.92, yanchor: 'top', font: { family: FONT_FAMILY, size: 14, color: '#1a202c' }, pad: { t: 0 } },
    barmode:       'group',
    paper_bgcolor: '#ffffff',
    plot_bgcolor:  '#ffffff',
    margin:        { t: 92, r: 24, b: 60, l: 44 },
    font:          { family: FONT_FAMILY, size: 12 },
    xaxis:         { title: '', tickangle: -30, tickfont: { size: 11 } },
    yaxis:         { title: 'Frequency', gridcolor: '#edf0f3', tickfont: { size: 11 } },
    legend:        { orientation: 'h', x: 0, y: 1.12, font: { size: 11 } },
    showlegend:    true,
  };

  Plotly.react('barChart', traces, layout, { displayModeBar: false, responsive: true });
}

// ── TRENDS CHART ──────────────────────────────────────────────────────────────
function updateTrendsChart() {
  const f         = getFilters();
  const stateLbl  = f.state === 'National' ? 'United States' : f.state;
  const agencyLbl = f.agency === 'All' ? 'All Agencies' : f.agency;
  const trendsMetric = {
    All:      'Monthly Fatal and Nonfatal Police Firearm Injuries',
    Fatal:    'Monthly Fatal Police Firearm Injuries',
    Nonfatal: 'Monthly Nonfatal Police Firearm Injuries',
  }[f.status];
  const titleText = `<b>${trendsMetric}</b><br><span style="font-size:12px;color:#5a6a7a">${stateLbl} · ${agencyLbl} · ${fmtMonthLabel(f.start)} – ${fmtMonthLabel(f.end)}</span>`;

  // Aggregate by month + statuslabel
  const monthMap = {};
  filteredData.forEach(r => {
    const mo  = floorMonth(r._date);
    const key = `${mo.getTime()}_${r.statuslabel}`;
    if (!monthMap[key]) monthMap[key] = { month: mo, status: r.statuslabel, count: 0 };
    monthMap[key].count++;
  });

  const fatal    = Object.values(monthMap).filter(v => v.status === 'Fatal')
                     .sort((a, b) => a.month - b.month);
  const nonfatal = Object.values(monthMap).filter(v => v.status === 'Nonfatal')
                     .sort((a, b) => a.month - b.month);

  // Build scatter + LOESS traces for one series
  function makeTraces(pts, color, name) {
    if (!pts.length) return [];
    // Use ISO date strings so Plotly treats x as a true time axis (chronological order)
    const dates  = pts.map(p => fmtDate(p.month));   // "2014-01-01"
    const xs     = pts.map(p => p.month.getTime());
    const ys     = pts.map(p => p.count);
    const smooth = loess(xs, ys, 0.75);

    return [
      {
        x:              dates,
        y:              ys,
        mode:           'markers',
        name,
        type:           'scatter',
        marker:         { color, size: 6, opacity: 0.6 },
        hovertemplate:  `<b>${name}</b><br>%{x|%b %Y}: %{y}<extra></extra>`,
      },
      {
        x:          dates,
        y:          smooth,
        mode:       'lines',
        name:       `${name} trend`,
        type:       'scatter',
        line:       { color, width: 2.5, dash: 'dash' },
        showlegend: false,
        hoverinfo:  'skip',
      },
    ];
  }

  const traces = [
    ...(f.status !== 'Nonfatal' ? makeTraces(fatal,    FATAL_COLOR,    'Fatal')    : []),
    ...(f.status !== 'Fatal'    ? makeTraces(nonfatal, NONFATAL_COLOR, 'Nonfatal') : []),
  ];

  const layout = {
    title:         { text: titleText, x: 0.02, xanchor: 'left', yref: 'container', y: 0.92, yanchor: 'top', font: { family: FONT_FAMILY, size: 14, color: '#1a202c' }, pad: { t: 0 } },
    paper_bgcolor: '#ffffff',
    plot_bgcolor:  '#ffffff',
    margin:        { t: 92, r: 24, b: 70, l: 55 },
    font:          { family: FONT_FAMILY, size: 13 },
    xaxis:         { type: 'date', tickformat: '%b %Y', tickmode: 'auto', nticks: 30, title: '', showgrid: false, tickangle: -35, tickfont: { size: 12 } },
    yaxis:         { title: 'Frequency', gridcolor: '#edf0f3', tickfont: { size: 12 } },
    legend:        { orientation: 'h', x: 0, y: 1.12, font: { size: 11 } },
    hovermode:     'x unified',
  };

  Plotly.react('trendsMain', traces, layout, { displayModeBar: false, responsive: true });
}

// ── DATA TABLE ────────────────────────────────────────────────────────────────
function buildTableRows() {
  return filteredData.map(r => {
    // Convert each comma-separated source URL into a clickable anchor
    const srcLinks = (r.sources || '')
      .split(/,\s*/)
      .map(u => u.trim())
      .filter(Boolean)
      .map(u => `<a href="${u}" target="_blank" rel="noopener">${u}</a>`)
      .join('<br>');

    return [
      r.incidentid,
      fmtDate(r._date),
      r.statuslabel,
      r.state,
      r.latitude  != null ? Number(r.latitude).toFixed(4)  : '',
      r.longitude != null ? Number(r.longitude).toFixed(4) : '',
      r.agencytypelabel,
      srcLinks,
    ];
  });
}

function updateDataTable() {
  document.getElementById('tableCaption').textContent = buildTitleBase();

  const rows = buildTableRows();

  if (dtInitialized && dtInstance) {
    dtInstance.clear().rows.add(rows).draw();
    return;
  }

  // First init
  dtInstance = $('#pfieTable').DataTable({
    data:        rows,
    columns: [
      { title: 'Incident ID' },
      { title: 'Date' },
      { title: 'Injury Status' },
      { title: 'State' },
      { title: 'Latitude' },
      { title: 'Longitude' },
      { title: 'Agency Type' },
      { title: 'Sources', orderable: false, width: '220px' },
    ],
    columnDefs: [
      // Render Sources column as raw HTML
      { targets: 7, render: { display: val => val } },
    ],
    pageLength:  25,
    order:       [[1, 'desc']],
    scrollX:     true,
    autoWidth:   false,
    fixedHeader: true,
  });
  dtInitialized = true;
}

// ── DOWNLOAD HANDLER ──────────────────────────────────────────────────────────
function downloadData() {
  const f    = getFilters();
  const cols = ['Incident ID','Date','Injury Status','State','Latitude','Longitude','Agency Type','Sources'];

  const rows = filteredData.map(r => ({
    'Incident ID':   r.incidentid,
    'Date':          fmtDate(r._date),
    'Injury Status': r.statuslabel,
    'State':         r.state,
    'Latitude':      r.latitude  != null ? r.latitude  : '',
    'Longitude':     r.longitude != null ? r.longitude : '',
    'Agency Type':   r.agencytypelabel,
    'Sources':       r.sources || '',
  }));

  let content, mimeType, ext;

  if (f.format === 'JSON') {
    content  = JSON.stringify(rows, null, 2);
    mimeType = 'application/json';
    ext      = 'json';

  } else if (f.format === 'TXT') {
    const header = cols.join('\t');
    const body   = rows.map(r => cols.map(c => String(r[c] ?? '')).join('\t')).join('\n');
    content  = header + '\n' + body;
    mimeType = 'text/plain';
    ext      = 'txt';

  } else {
    // CSV — quote fields that contain commas, quotes, or newlines
    const esc = v => {
      const s = String(v ?? '');
      return /[,"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    const header = cols.map(esc).join(',');
    const body   = rows.map(r => cols.map(c => esc(r[c])).join(',')).join('\n');
    content  = header + '\n' + body;
    mimeType = 'text/csv';
    ext      = 'csv';
  }

  const blob = new Blob([content], { type: mimeType });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = `pfie-data-${fmtDate(new Date())}.${ext}`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// ── FREEZE / UNFREEZE ─────────────────────────────────────────────────────────
function setFreezeState(frozen) {
  isFrozen = frozen;
  const btn   = document.getElementById('freezeMap');
  const mapEl = document.getElementById('pfiemap');

  if (frozen) {
    map.dragging.disable();
    map.touchZoom.disable();
    map.doubleClickZoom.disable();
    map.scrollWheelZoom.disable();
    map.boxZoom.disable();
    map.keyboard.disable();
    if (map.tap) map.tap.disable();
    mapEl.classList.add('frozen');
    btn.classList.add('active');
    btn.innerHTML = '<i class="fa-solid fa-snowflake"></i> Unfreeze Map';
  } else {
    map.dragging.enable();
    map.touchZoom.enable();
    map.doubleClickZoom.enable();
    map.scrollWheelZoom.enable();
    map.boxZoom.enable();
    map.keyboard.enable();
    if (map.tap) map.tap.enable();
    mapEl.classList.remove('frozen');
    btn.classList.remove('active');
    btn.innerHTML = '<i class="fa-solid fa-snowflake"></i> Freeze Map';
  }
}

// ── SIDEBAR TOGGLE ────────────────────────────────────────────────────────────
function toggleSidebar() {
  const sidebar  = document.getElementById('sidebar');
  const backdrop = document.getElementById('sidebarBackdrop');
  const btn      = document.getElementById('sidebarToggle');
  const isCollapsed = sidebar.classList.toggle('collapsed');

  // Button: green when sidebar is open, orange when closed
  btn.classList.toggle('sidebar-open', !isCollapsed);

  // Mobile backdrop
  if (window.innerWidth <= 900) {
    backdrop.classList.toggle('active', !isCollapsed);
  }

  // After the CSS transition completes (0.25 s), re-measure all charts
  // so Plotly fills the newly available width and Leaflet redraws tiles.
  setTimeout(() => {
    if (map) map.invalidateSize();
    const barEl   = document.getElementById('barChart');
    const trendEl = document.getElementById('trendsMain');
    if (barEl)   Plotly.Plots.resize(barEl);
    if (trendEl) Plotly.Plots.resize(trendEl);
  }, 300);
}

// ── MAIN UPDATE CYCLE ─────────────────────────────────────────────────────────
function applyFilters() {
  runFilters();
  updateMap();
  updateBarChart();
  updateTrendsChart();
  updateDataTable();
}

// ── DATA LOADING ──────────────────────────────────────────────────────────────
async function loadData() {
  try {
    const [pfieText, centroidsText, boundsText] = await Promise.all([
      fetch('data/pfie20142020.csv').then(r => { if (!r.ok) throw new Error(r.status); return r.text(); }),
      fetch('data/statecentroids.csv').then(r => r.text()),
      fetch('data/statebounds.csv').then(r => r.text()),
    ]);

    const parse = txt =>
      Papa.parse(txt, { header: true, dynamicTyping: true, skipEmptyLines: true }).data;

    const pfie      = parse(pfieText);
    const centroids = parse(centroidsText);
    const bounds    = parse(boundsText);

    // Centroid lookup { StateName: {lat, lng} }
    const centroidMap = {};
    centroids.forEach(r => { centroidMap[r.state] = { lat: r.lat, lng: r.long }; });

    // State bounding boxes
    bounds.forEach(r => { stateBounds[r.state] = { x1: r.x1, y1: r.y1, x2: r.x2, y2: r.y2 }; });

    // Process main dataset
    rawData = pfie
      .map(r => ({
        ...r,
        _date:     parseDate(r.date),
        // Fall back to state centroid if lat/lon missing
        latitude:  r.latitude  ?? centroidMap[r.state]?.lat ?? null,
        longitude: r.longitude ?? centroidMap[r.state]?.lng ?? null,
      }))
      .filter(r => r._date !== null);

    // Populate state dropdown
    const states = [...new Set(rawData.map(r => r.state))].sort();
    const sel    = document.getElementById('stateSelect');
    states.forEach(s => {
      const opt = document.createElement('option');
      opt.value = s;
      opt.textContent = s;
      sel.appendChild(opt);
    });

    // Hide loading overlay
    document.getElementById('loadingOverlay').classList.add('hidden');

    // Initial render
    applyFilters();

    // After the browser has painted and settled, correct any charts that rendered
    // while their containers were hidden (display:none gives Plotly zero width)
    setTimeout(() => {
      Plotly.Plots.resize(document.getElementById('barChart'));
      Plotly.Plots.resize(document.getElementById('trendsMain'));
    }, 150);

  } catch (err) {
    console.error('PFIE: data load failed', err);
    document.getElementById('loadingOverlay').innerHTML =
      `<div class="loading-box">
         <i class="fa-solid fa-triangle-exclamation" style="color:#e07a00"></i>
         <p>Failed to load data. Check the console and ensure data files are present.</p>
       </div>`;
  }
}

// ── BOOTSTRAP ─────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {

  // Map (must init before data load so container exists in DOM)
  initMap();

  // On mobile, collapse sidebar by default; on desktop it starts open
  if (window.innerWidth <= 900) {
    document.getElementById('sidebar').classList.add('collapsed');
    // Button starts orange (sidebar closed)
  } else {
    // Button starts green (sidebar open)
    document.getElementById('sidebarToggle').classList.add('sidebar-open');
  }

  // ── Date pickers ──────────────────────────────────────────────────────────
  flatpickr('#dateStart', {
    defaultDate: DATE_MIN,
    minDate:     DATE_MIN,
    maxDate:     DATE_MAX,
    dateFormat:  'Y-m-d',
    onChange:    () => applyFilters(),
  });
  flatpickr('#dateEnd', {
    defaultDate: DATE_MAX,
    minDate:     DATE_MIN,
    maxDate:     DATE_MAX,
    dateFormat:  'Y-m-d',
    onChange:    () => applyFilters(),
  });

  // ── Dropdown filters ───────────────────────────────────────────────────────
  ['stateSelect', 'agencySelect', 'statusSelect'].forEach(id => {
    document.getElementById(id).addEventListener('change', applyFilters);
  });
  // formatSelect doesn't trigger a re-render — only affects download

  // ── Sliders ────────────────────────────────────────────────────────────────
  const markerInput  = document.getElementById('markerSize');
  const jitterInput  = document.getElementById('jitterScale');
  const markerValEl  = document.getElementById('markerSizeVal');
  const jitterValEl  = document.getElementById('jitterScaleVal');

  markerInput.addEventListener('input', function () {
    markerValEl.textContent = this.value;
    drawMapPoints();
  });
  jitterInput.addEventListener('input', function () {
    jitterValEl.textContent = this.value;
    drawMapPoints();
  });

  // ── Map buttons ────────────────────────────────────────────────────────────
  document.getElementById('toggleClustering').addEventListener('click', function () {
    useClusters = !useClusters;
    this.innerHTML = useClusters
      ? '<i class="fa-solid fa-circle-nodes"></i> Disable Clustering'
      : '<i class="fa-solid fa-circle-nodes"></i> Enable Clustering';
    this.classList.toggle('active', useClusters);
    drawMapPoints();
  });

  document.getElementById('fitAll').addEventListener('click', () => {
    // Unfreeze if frozen, then fit
    if (isFrozen) setFreezeState(false);
    userMovedMap = false;
    fitMapToData();
  });

  document.getElementById('freezeMap').addEventListener('click', () => {
    setFreezeState(!isFrozen);
  });

  document.getElementById('toggleLegend').addEventListener('click', function () {
    const legendEl = document.querySelector('.leaflet-legend');
    const hiding = legendEl.style.display !== 'none';
    legendEl.style.display = hiding ? 'none' : '';
    this.innerHTML = hiding
      ? '<i class="fa-solid fa-eye"></i> Show Legend'
      : '<i class="fa-solid fa-eye-slash"></i> Hide Legend';
    this.classList.toggle('active', hiding);
  });

  // ── Tab switching ──────────────────────────────────────────────────────────
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', function () {
      document.querySelectorAll('.tab-btn').forEach(b => {
        b.classList.remove('active');
        b.setAttribute('aria-selected', 'false');
      });
      document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));

      this.classList.add('active');
      this.setAttribute('aria-selected', 'true');

      const panelId = `tab-${this.dataset.tab}`;
      document.getElementById(panelId).classList.add('active');

      // After panel is visible, resize Plotly to fill the now-measured container
      if (this.dataset.tab === 'map') {
        setTimeout(() => {
          Plotly.Plots.resize(document.getElementById('barChart'));
          Plotly.Plots.resize(document.getElementById('trendsMain'));
        }, 30);
        map.invalidateSize();
      }
      if (this.dataset.tab === 'data') {
        // Recalculate DataTables column widths after becoming visible
        if (dtInstance) dtInstance.columns.adjust().draw(false);
      }
    });
  });

  // ── Sidebar toggle ─────────────────────────────────────────────────────────
  document.getElementById('sidebarToggle').addEventListener('click', toggleSidebar);
  document.getElementById('sidebarBackdrop').addEventListener('click', toggleSidebar);

  // ── Download ───────────────────────────────────────────────────────────────
  document.getElementById('downloadBtn').addEventListener('click', downloadData);

  // ── Window resize → keep Plotly charts full-width ─────────────────────────
  let resizeTimer = null;
  window.addEventListener('resize', () => {
    Plotly.Plots.resize(document.getElementById('barChart'));
    Plotly.Plots.resize(document.getElementById('trendsMain'));

    // When crossing from mobile → desktop, clear the backdrop so it
    // doesn't stay stuck as a dark overlay after the breakpoint passes.
    if (window.innerWidth > 900) {
      document.getElementById('sidebarBackdrop').classList.remove('active');
    }

    // Debounce the Leaflet recalculation so it runs after the browser has
    // finished layout reflow — handles both drag-resize and instant hotkey
    // resizes where the container dimensions aren't settled yet.
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      map.invalidateSize();
      if (!isFrozen) fitMapToData();
    }, 150);
  });

  // ── Load data (async) ──────────────────────────────────────────────────────
  loadData();

  // Re-render charts after web fonts finish loading so Plotly measures
  // legend/title text with the actual font (Source Sans 3) not the fallback.
  document.fonts.ready.then(() => {
    if (filteredData.length) {
      updateBarChart();
      updateTrendsChart();
    }
  });
});

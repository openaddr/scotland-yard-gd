const fs = require('fs');

// Parse authoritative data
const stations = {};
const connections = { taxi: [], bus: [], underground: [], water: [] };

const stLines = fs.readFileSync('Scotland-yard-data/stations.txt', 'utf8').trim().split('\n');
for (const line of stLines) {
  const parts = line.trim().split(/\s+/);
  if (parts.length < 3) continue;
  const id = parseInt(parts[0]);
  stations[id] = { x: parseFloat(parts[1]), y: parseFloat(parts[2]), types: parts.slice(3) };
}

const connLines = fs.readFileSync('Scotland-yard-data/connections.txt', 'utf8').trim().split('\n');
for (const line of connLines) {
  const parts = line.trim().split(/\s+/);
  if (parts.length !== 3) continue;
  const from = parseInt(parts[0]);
  const to = parseInt(parts[1]);
  const type = parts[2];
  if (connections[type]) connections[type].push([from, to]);
}

// Calculate bounding box of stations
const xs = Object.values(stations).map(s => s.x);
const ys = Object.values(stations).map(s => s.y);
const minX = Math.min(...xs), maxX = Math.max(...xs);
const minY = Math.min(...ys), maxY = Math.max(...ys);
const dataW = maxX - minX, dataH = maxY - minY;

// Scale to fit 600x450 with margin
const margin = 30;
const viewW = 600, viewH = 450;
const availW = viewW - 2 * margin;
const availH = viewH - 2 * margin;
const scale = Math.min(availW / dataW, availH / dataH);
const offX = margin + (availW - dataW * scale) / 2 - minX * scale;
const offY = margin + (availH - dataH * scale) / 2 - minY * scale;

function tx(x) { return (x * scale + offX).toFixed(2); }
function ty(y) { return (y * scale + offY).toFixed(2); }

// Build set of station types for SVG styling
const stationTypes = {};
for (const [id, s] of Object.entries(stations)) {
  stationTypes[id] = new Set(s.types);
}

// Determine which stations are ferry-only
const ferryStations = new Set();
for (const c of connections.water) ferryStations.add(c[0]);

// SVG generation
const svgParts = [];

svgParts.push(`<?xml version="1.0" encoding="UTF-8"?>
<svg width="${viewW}" height="${viewH}" viewBox="0 0 ${viewW} ${viewH}" xmlns="http://www.w3.org/2000/svg">`);

// Background
svgParts.push(`  <rect width="${viewW}" height="${viewH}" rx="20" ry="20" fill="#d8e4f0" stroke="#555" stroke-width="8"/>`);

// River (approximate: draw a blue winding path through the middle)
// Ferry stations roughly mark the river: 108(1393,642), 115(972,553), 117(1294,670), 157(949,917), 194(534,1128)
// The river runs roughly between y=500-650 in auth coords → scaled
const riverY1 = ty(520);
const riverY2 = ty(650);
svgParts.push(`  <path d="M ${tx(33)} ${((parseFloat(riverY1)+parseFloat(riverY2))/2).toFixed(2)}
    C ${tx(400)} ${riverY1} ${tx(800)} ${riverY2} ${tx(1200)} ${((parseFloat(riverY1)+parseFloat(riverY2))/2).toFixed(2)}
    L ${tx(1593)} ${((parseFloat(riverY1)+parseFloat(riverY2))/2).toFixed(2)}"
    fill="none" stroke="#89c4e8" stroke-width="18" stroke-linecap="round" opacity="0.5"/>`);

// Connection paths
function drawConnectionGroup(paths, stroke, strokeWidth, dashArray, zIndex) {
  svgParts.push(`  <g fill="none" stroke="${stroke}" stroke-width="${strokeWidth}" ${dashArray ? `stroke-dasharray="${dashArray}"` : ''} stroke-linecap="round" stroke-linejoin="round" style="z-index:${zIndex}">`);
  for (const [a, b] of paths) {
    const sa = stations[a], sb = stations[b];
    svgParts.push(`    <line x1="${tx(sa.x)}" y1="${ty(sa.y)}" x2="${tx(sb.x)}" y2="${ty(sb.y)}"/>`);
  }
  svgParts.push(`  </g>`);
}

// Draw order: underground (bottom) → bus → taxi (top)
drawConnectionGroup(connections.underground, '#d44040', '3', '6,4', 1);
drawConnectionGroup(connections.bus, '#4a9e50', '2.5', null, 2);
drawConnectionGroup(connections.taxi, '#c8b830', '1', null, 3);
drawConnectionGroup(connections.water, '#4466aa', '2.5', '8,5', 4);

// Station circles
svgParts.push(`  <g stroke="#333" stroke-width="1.5" style="z-index:5">`);
for (const [id, s] of Object.entries(stations)) {
  const isFerry = ferryStations.has(parseInt(id));
  const fill = isFerry ? '#b0c4d8' : '#ffffff';
  if (isFerry) {
    svgParts.push(`    <circle cx="${tx(s.x)}" cy="${ty(s.y)}" r="6" fill="${fill}" stroke-dasharray="2,3"/>`);
  } else {
    svgParts.push(`    <circle cx="${tx(s.x)}" cy="${ty(s.y)}" r="6" fill="${fill}"/>`);
  }
}
svgParts.push(`  </g>`);

// Station labels
svgParts.push(`  <g fill="#222" font-family="sans-serif" font-size="7" text-anchor="middle" style="z-index:6">`);
for (const [id, s] of Object.entries(stations)) {
  svgParts.push(`    <text x="${tx(s.x)}" y="${(parseFloat(ty(s.y)) + 2.5).toFixed(2)}">${id}</text>`);
}
svgParts.push(`  </g>`);

svgParts.push('</svg>');

// Write SVG
const svgContent = svgParts.join('\n');
fs.writeFileSync('assets/Scotland_Yard_schematic.svg', svgContent);
console.log('SVG written:', svgContent.split('\n').length, 'lines');

// Generate new stations.json
const newStations = {};
for (const [id, s] of Object.entries(stations)) {
  const nx = parseFloat(tx(s.x));
  const ny = parseFloat(ty(s.y));
  newStations[id] = {
    x: Math.round(nx * 100) / 100,
    y: Math.round(ny * 100) / 100,
    types: s.types
  };
}
fs.writeFileSync('data/stations.json', JSON.stringify(newStations, null, '\t'));
console.log('stations.json written:', Object.keys(newStations).length, 'stations');

// Verify all connections reference valid stations
const stationIds = new Set(Object.keys(newStations).map(Number));
let bad = 0;
for (const type of Object.keys(connections)) {
  for (const [a, b] of connections[type]) {
    if (!stationIds.has(a) || !stationIds.has(b)) {
      console.log('BAD:', a, b, type);
      bad++;
    }
  }
}
console.log('Invalid connection refs:', bad);
console.log('Scale:', scale.toFixed(4), 'Offset:', offX.toFixed(2), offY.toFixed(2));

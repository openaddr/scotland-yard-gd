const fs = require('fs');
const xml = fs.readFileSync('C:/Data/Godot/scotland-yard/assets/Scotland_Yard_schematic.svg', 'utf8');

// =============================================================================
// 1. Extract station positions from SVG text labels
// =============================================================================
// SVG display coordinates: x_display = raw_x, y_display = raw_y - 582.42
// Board occupies approximately x=25-575, y=-5 to 370 (on a 600x450 canvas)
const svgStations = {};
for (const m of xml.matchAll(/<text[^>]*x="([^"]+)"[^>]*y="([^"]+)"[^>]*>[\s\S]*?<tspan[^>]*>([^<]+)<\/tspan>/g)) {
  const id = parseInt(m[3]);
  if (!isNaN(id) && id > 0 && id <= 200) {
    svgStations[id] = {
      x: parseFloat(m[1]),
      y: parseFloat(m[2]) - 582.42
    };
  }
}
console.log('SVG stations:', Object.keys(svgStations).length);
console.log('Sample positions:');
for (const id of [1, 13, 26, 50, 117, 199]) {
  console.log(`  Station ${id}: (${svgStations[id].x.toFixed(1)}, ${svgStations[id].y.toFixed(1)})`);
}

// =============================================================================
// 2. Identify ferry stations from grey dashed circles
// =============================================================================
const greyG = xml.indexOf('fill="#ddd" stroke-dasharray="2, 4"');
let greyCircles = [];
if (greyG >= 0) {
  const end = xml.indexOf('</g>', greyG);
  for (const m of xml.substring(greyG, end).matchAll(/cx="([^"]+)" cy="([^"]+)"/g)) {
    greyCircles.push({ x: parseFloat(m[1]), y: parseFloat(m[2]) - 582.42 });
  }
}

function findStation(x, y, thr = 20) {
  let best = null, bd = thr;
  for (const sid in svgStations) {
    const s = svgStations[sid];
    const d = Math.hypot(s.x - x, s.y - y);
    if (d < bd) { bd = d; best = parseInt(sid); }
  }
  return best;
}

const ferryStations = new Set(greyCircles.map(c => findStation(c.x, c.y, 20)).filter(Boolean));
console.log('\nFerry stations:', [...ferryStations].sort((a,b)=>a-b));

// =============================================================================
// 3. Load existing (verified) connection data
// =============================================================================
const existingConns = JSON.parse(fs.readFileSync('C:/Data/Godot/scotland-yard/data/connections.json', 'utf8'));
const existingStations = JSON.parse(fs.readFileSync('C:/Data/Godot/scotland-yard/data/stations.json', 'utf8'));

console.log('\nExisting connections:', existingConns.length);
const byType = { taxi: 0, bus: 0, underground: 0, ferry: 0 };
for (const c of existingConns) byType[c.type] = (byType[c.type]||0) + 1;
console.log('By type:', byType);

// =============================================================================
// 4. Derive station types from existing connections
// =============================================================================
const stationTypes = {};
for (const c of existingConns) {
  if (!stationTypes[c.from]) stationTypes[c.from] = new Set();
  if (!stationTypes[c.to]) stationTypes[c.to] = new Set();
  stationTypes[c.from].add(c.type);
  stationTypes[c.to].add(c.type);
}

function getTypes(sid) {
  const id = parseInt(sid);
  const types = ['taxi'];
  if (stationTypes[id] && stationTypes[id].has('bus')) types.push('bus');
  if (stationTypes[id] && stationTypes[id].has('underground')) types.push('underground');
  if (ferryStations.has(id)) types.push('ferry');
  return types;
}

// =============================================================================
// 5. Determine SVG→game coordinate transform
// =============================================================================
// The SVG board and the existing game board use DIFFERENT coordinate systems.
// SVG board: x=25-575, y=-5 to 370 (canvas 600x450)
// Existing game: x=170-1640, y=30-1230 (pixel coords from original board image)
// We need a linear transform: game = SVG * scale + offset
// Use all matching stations for linear regression

const pairs = Object.keys(existingStations)
  .filter(sid => svgStations[parseInt(sid)])
  .map(sid => ({
    sx: svgStations[parseInt(sid)].x,
    sy: svgStations[parseInt(sid)].y,
    ex: existingStations[sid].x,
    ey: existingStations[sid].y
  }));

const n = pairs.length;
let sumSx=0,sumSy=0,sumEx=0,sumEy=0;
for (const p of pairs) { sumSx+=p.sx; sumSy+=p.sy; sumEx+=p.ex; sumEy+=p.ey; }
const meanSx=sumSx/n, meanSy=sumSy/n, meanEx=sumEx/n, meanEy=sumEy/n;

let numX=0,denX=0,numY=0,denY=0;
for (const p of pairs) {
  numX+=(p.sx-meanSx)*(p.ex-meanEx);
  denX+=(p.sx-meanSx)*(p.sx-meanSx);
  numY+=(p.sy-meanSy)*(p.ey-meanEy);
  denY+=(p.sy-meanSy)*(p.sy-meanSy);
}
const scaleX = denX !== 0 ? numX/denX : 1;
const scaleY = denY !== 0 ? numY/denY : 1;
const offX = meanEx - scaleX*meanSx;
const offY = meanEy - scaleY*meanSy;

console.log(`\nTransform: game_x = ${scaleX.toFixed(4)} * svg_x + ${offX.toFixed(4)}`);
console.log(`           game_y = ${scaleY.toFixed(4)} * svg_y + ${offY.toFixed(4)}`);

// Check residuals
let maxEx=0, maxEy=0;
for (const p of pairs) {
  maxEx = Math.max(maxEx, Math.abs(p.ex - (scaleX*p.sx + offX)));
  maxEy = Math.max(maxEy, Math.abs(p.ey - (scaleY*p.sy + offY)));
}
console.log(`Max residual X: ${maxEx.toFixed(0)}, Y: ${maxEy.toFixed(0)}`);

// The residuals show how well the transform fits.
// If max residual is large, the coordinate systems don't match well.
// But the CONNECTIONS are still correct (they define adjacency, not absolute positions).

// =============================================================================
// 6. Generate new station data with SVG-derived positions
// =============================================================================
const newStations = {};
for (const sid in svgStations) {
  const s = svgStations[sid];
  newStations[sid] = {
    x: Math.round(scaleX * s.x + offX),
    y: Math.round(scaleY * s.y + offY),
    types: getTypes(sid)
  };
}

// Validate connections with new positions
let ok=0, bad=0;
for (const c of existingConns) {
  const s1 = newStations[c.from];
  const s2 = newStations[c.to];
  if (s1 && s2) {
    const dist = Math.hypot(s2.x-s1.x, s2.y-s1.y);
    if (dist < 300) ok++;
    else bad++;
  }
}
console.log(`\nConnection validation: ${ok} OK, ${bad} suspicious (>300 units)`);

// =============================================================================
// 7. Write output
// =============================================================================
fs.writeFileSync('C:/Data/Godot/scotland-yard/data/stations_new.json', JSON.stringify(newStations, null, 2));
fs.writeFileSync('C:/Data/Godot/scotland-yard/data/connections_new.json', JSON.stringify(existingConns, null, 2));

console.log('\nWritten:');
console.log('  stations_new.json — SVG-derived positions with existing types');
console.log('  connections_new.json — copied from existing (verified) data');
console.log('\nSample new positions:');
for (const id of [1, 13, 26, 50, 117, 199]) {
  if (newStations[id]) {
    const s = newStations[id];
    const svg = svgStations[id];
    console.log(`  ${id}: SVG(${svg.x.toFixed(0)},${svg.y.toFixed(1)}) → (${s.x}, ${s.y}) types=${JSON.stringify(s.types)}`);
  }
}

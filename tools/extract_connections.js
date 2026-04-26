const fs = require('fs');
const svg = fs.readFileSync('assets/Scotland_Yard_schematic.svg', 'utf8');

// Extract station circles (r=7.5) and texts
const stationCircles = [];
const circleRe = /<circle[^>]*cx="([^"]+)"[^>]*cy="([^"]+)"[^>]*r="7\.5"[^>]*\/>/g;
let m;
while ((m = circleRe.exec(svg)) !== null) {
  stationCircles.push({x: parseFloat(m[1]), y: parseFloat(m[2])});
}
const stationTexts = [];
const textRe = /<text[^>]*x="([^"]+)"[^>]*y="([^"]+)"[^>]*>[^<]*<tspan[^>]*>(\d+)<\/tspan>/g;
while ((m = textRe.exec(svg)) !== null) {
  stationTexts.push({id: parseInt(m[3]), x: parseFloat(m[1]), y: parseFloat(m[2])});
}

// Match texts to circles
const stationMap = [];
const usedCircles = new Set();
for (const st of stationTexts) {
  let bestIdx = -1, bestDist = 30;
  for (let i = 0; i < stationCircles.length; i++) {
    if (usedCircles.has(i)) continue;
    const dist = Math.sqrt((st.x - stationCircles[i].x)**2 + (st.y - stationCircles[i].y)**2);
    if (dist < bestDist) { bestDist = dist; bestIdx = i; }
  }
  if (bestIdx >= 0) { usedCircles.add(bestIdx); stationMap.push({id: st.id, x: stationCircles[bestIdx].x, y: stationCircles[bestIdx].y}); }
}

// Parse path vertices
function parsePathVertices(d) {
  const points = []; let x = 0, y = 0, cmd = '';
  const tokens = []; let i = 0;
  while (i < d.length) {
    if (/[mlhvzMLHVZ]/.test(d[i])) { tokens.push({t:'c',v:d[i].toLowerCase()}); i++; }
    else if (/[\d.eE+-]/.test(d[i])) {
      let num = '';
      if (d[i]==='+'||d[i]==='-') { num+=d[i]; i++; }
      while (i<d.length && /[\d.eE]/.test(d[i])) { if (d[i]==='-'&&num.length>0) break; num+=d[i]; i++; }
      if (num.length>0) tokens.push({t:'n',v:parseFloat(num)});
    } else i++;
  }
  let ti = 0;
  while (ti < tokens.length) {
    const tok = tokens[ti];
    if (tok.t==='c') { cmd=tok.v; ti++; continue; }
    if (tok.t!=='n') { ti++; continue; }
    if (cmd==='m'||cmd==='l') {
      if (ti+1<tokens.length&&tokens[ti+1].t==='n') { x+=tok.v; y+=tokens[ti+1].v; points.push({x,y}); ti+=2; if(cmd==='m') cmd='l'; }
      else ti++;
    } else if (cmd==='h') { x+=tok.v; points.push({x,y}); ti++; }
    else if (cmd==='v') { y+=tok.v; points.push({x,y}); ti++; }
    else ti++;
  }
  return points;
}

// Distance from point to line segment
function distToSegment(px,py,ax,ay,bx,by) {
  const dx=bx-ax, dy=by-ay;
  const len2 = dx*dx+dy*dy;
  if (len2===0) return Math.sqrt((px-ax)**2+(py-ay)**2);
  let t = ((px-ax)*dx+(py-ay)*dy)/len2;
  t = Math.max(0, Math.min(1, t));
  const projX = ax+t*dx, projY = ay+t*dy;
  return Math.sqrt((px-projX)**2+(py-projY)**2);
}

// For a path, find all stations within tolerance of any segment, in path order
function findStationsOnPath(pathPoints, tolerance) {
  const stationDistances = stationMap.map(s => {
    let minDist = Infinity;
    let bestSegmentIdx = 0;
    for (let i = 1; i < pathPoints.length; i++) {
      const d = distToSegment(s.x, s.y, pathPoints[i-1].x, pathPoints[i-1].y, pathPoints[i].x, pathPoints[i].y);
      if (d < minDist) { minDist = d; bestSegmentIdx = i-1; }
    }
    return {id: s.id, dist: minDist, segIdx: bestSegmentIdx};
  });

  const onPath = stationDistances.filter(s => s.dist < tolerance);

  // Sort by segment index, then by distance along segment
  onPath.sort((a, b) => {
    if (a.segIdx !== b.segIdx) return a.segIdx - b.segIdx;
    return a.dist - b.dist;
  });

  return onPath;
}

// Extract all paths from SVG lines
const svgLines = svg.split('\n');
function extractPaths(startLine, endLine) {
  const paths = [];
  for (let i = startLine; i < endLine; i++) {
    const pm = svgLines[i].match(/<path\s+d="([^"]+)"/);
    if (pm) {
      const points = parsePathVertices(pm[1]);
      if (points.length >= 2) paths.push(points);
    }
  }
  return paths;
}

// Extract paths from each transport group
const ugPaths = extractPaths(34, 41);           // Underground: stroke-dasharray group
const busGroupPaths = extractPaths(46, 64);      // Bus: stroke=#080 group
const taxiGroupPaths = extractPaths(70, 154);    // Taxi: stroke=#ff0 group

// Mixed group (lines 45-69) has some taxi and bus paths with inline stroke
const mixedGroupPaths = [];
for (let i = 45; i < 69; i++) {
  const pm = svgLines[i].match(/<path[^>]*d="([^"]+)"/);
  if (pm) {
    const line = svgLines[i];
    const points = parsePathVertices(pm[1]);
    if (points.length >= 2) {
      let type = 'unknown';
      if (line.includes("stroke='#ff0'")) type = 'taxi';
      else if (line.includes("stroke='#080'")) type = 'bus';
      mixedGroupPaths.push({points, type});
    }
  }
}

// Extract connections from paths
function extractConnectionsFromPaths(paths, type, tolerance) {
  const edges = new Set();
  for (const path of paths) {
    const onPath = findStationsOnPath(path, tolerance);
    const seen = new Set();
    const uniqueStations = [];
    for (const s of onPath) {
      if (!seen.has(s.id)) { seen.add(s.id); uniqueStations.push(s); }
    }
    for (let i = 1; i < uniqueStations.length; i++) {
      const edge = Math.min(uniqueStations[i-1].id, uniqueStations[i].id) + '-' + Math.max(uniqueStations[i-1].id, uniqueStations[i].id);
      edges.add(edge + '|' + type);
    }
  }
  return edges;
}

const TOLERANCE = 18;

const ugEdges = extractConnectionsFromPaths(ugPaths, 'underground', TOLERANCE);
const busEdges = extractConnectionsFromPaths(busGroupPaths, 'bus', TOLERANCE);
const taxiEdges = extractConnectionsFromPaths(taxiGroupPaths, 'taxi', TOLERANCE);

const mixedTaxiEdges = new Set();
const mixedBusEdges = new Set();
for (const mp of mixedGroupPaths) {
  if (mp.type === 'taxi') {
    extractConnectionsFromPaths([mp.points], 'taxi', TOLERANCE).forEach(e => mixedTaxiEdges.add(e));
  } else if (mp.type === 'bus') {
    extractConnectionsFromPaths([mp.points], 'bus', TOLERANCE).forEach(e => mixedBusEdges.add(e));
  }
}

// Combine all edges
const allEdges = new Map();
function addEdges(edgeSet) {
  for (const e of edgeSet) {
    const [key, type] = e.split('|');
    if (!allEdges.has(key)) allEdges.set(key, type);
  }
}
addEdges(ugEdges);
addEdges(busEdges);
addEdges(taxiEdges);
addEdges(mixedTaxiEdges);
addEdges(mixedBusEdges);

console.log('SVG connections found:', allEdges.size);
const typeCounts = {};
for (const [k,v] of allEdges) typeCounts[v] = (typeCounts[v]||0)+1;
console.log('By type:', typeCounts);

// Compare with JSON
const jsonConns = JSON.parse(fs.readFileSync('data/connections.json', 'utf8'));
const jsonEdgeMap = new Map();
jsonConns.forEach(c => {
  const key = Math.min(c.from,c.to)+'-'+Math.max(c.from,c.to);
  jsonEdgeMap.set(key, c.type);
});

const svgKeys = new Set(allEdges.keys());
const jsonKeys = new Set(jsonEdgeMap.keys());

const inSvgNotJson = [...svgKeys].filter(e => !jsonKeys.has(e)).sort((a,b) => {
  const [a1,a2] = a.split('-').map(Number);
  const [b1,b2] = b.split('-').map(Number);
  return a1-b1 || a2-b2;
});
const inJsonNotSvg = [...jsonKeys].filter(e => !svgKeys.has(e)).sort((a,b) => {
  const [a1,a2] = a.split('-').map(Number);
  const [b1,b2] = b.split('-').map(Number);
  return a1-b1 || a2-b2;
});

console.log('\nIn SVG but NOT in JSON:', inSvgNotJson.length);
console.log('In JSON but NOT in SVG:', inJsonNotSvg.length);

if (inSvgNotJson.length <= 80) {
  console.log('\nMissing from JSON (in SVG but not JSON):');
  inSvgNotJson.forEach(e => console.log(' ', e, '(' + allEdges.get(e) + ')'));
}

// Check type mismatches
let typeMismatches = 0;
for (const key of svgKeys) {
  if (jsonKeys.has(key)) {
    const svgType = allEdges.get(key);
    const jsonType = jsonEdgeMap.get(key);
    if (svgType !== jsonType) typeMismatches++;
  }
}
console.log('\nType mismatches (same edge, different transport):', typeMismatches);

// Output the complete connections list from SVG
if (inSvgNotJson.length > 0) {
  console.log('\n=== SUGGESTED ADDITIONS TO connections.json ===');
  const additions = [];
  for (const edge of inSvgNotJson) {
    const [from, to] = edge.split('-').map(Number);
    const type = allEdges.get(edge);
    additions.push({from, to, type});
  }
  console.log(JSON.stringify(additions, null, 2));
}

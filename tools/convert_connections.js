const fs = require('fs');

// Read the authoritative connections data
const lines = fs.readFileSync(0, 'utf8').trim().split('\n');
const typeMap = { water: 'ferry', taxi: 'taxi', bus: 'bus', underground: 'underground' };
const connections = [];
const connStations = new Set();

for (const line of lines) {
  const parts = line.trim().split(/\s+/);
  if (parts.length !== 3) continue;
  const [f, t, type] = parts;
  const mapped = typeMap[type] || type;
  connections.push({ from: parseInt(f), to: parseInt(t), type: mapped });
  connStations.add(parseInt(f));
  connStations.add(parseInt(t));
}

console.error('Total connections:', connections.length);
const typeCounts = {};
connections.forEach(c => typeCounts[c.type] = (typeCounts[c.type] || 0) + 1);
console.error('By type:', typeCounts);
const edges = new Set();
connections.forEach(c => edges.add(Math.min(c.from, c.to) + '-' + Math.max(c.from, c.to)));
console.error('Unique undirected edges:', edges.size);
console.error('Stations in connections:', connStations.size, 'range:', Math.min(...connStations), '-', Math.max(...connStations));

// Compare with our stations.json
const ourStations = JSON.parse(fs.readFileSync('data/stations.json', 'utf8'));
const ourIds = new Set();
for (const key of Object.keys(ourStations)) {
  ourIds.add(parseInt(key));
}
console.error('Our stations.json has', ourIds.size, 'stations, range:', Math.min(...ourIds), '-', Math.max(...ourIds));

const missing = [...ourIds].filter(id => !connStations.has(id)).sort((a, b) => a - b);
if (missing.length) console.error('Stations in our data but NOT in connections:', missing.join(', '));
const extra = [...connStations].filter(id => !ourIds.has(id)).sort((a, b) => a - b);
if (extra.length) console.error('Stations in connections but NOT in our data:', extra.join(', '));

// Output JSON
console.log(JSON.stringify(connections, null, 2));

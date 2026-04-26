const fs = require('fs');

const connections = JSON.parse(fs.readFileSync('data/connections.json', 'utf8'));
const stations = JSON.parse(fs.readFileSync('data/stations.json', 'utf8'));

// Build station types from connections
const stationTypes = {};
for (const conn of connections) {
  for (const sid of [conn.from, conn.to]) {
    if (!stationTypes[sid]) stationTypes[sid] = new Set();
    if (conn.type === 'ferry') stationTypes[sid].add('ferry');
    else stationTypes[sid].add(conn.type);
  }
}

// Update stations with correct types
let updated = 0;
for (const sidStr of Object.keys(stations)) {
  const sid = parseInt(sidStr);
  if (stationTypes[sid]) {
    const newTypes = [...stationTypes[sid]].sort();
    const oldTypes = stations[sidStr].types;
    if (JSON.stringify(newTypes) !== JSON.stringify(oldTypes)) {
      console.error(`Station ${sid}: ${JSON.stringify(oldTypes)} -> ${JSON.stringify(newTypes)}`);
      stations[sidStr].types = newTypes;
      updated++;
    }
  }
}

console.error(`Updated ${updated} station types`);
fs.writeFileSync('data/stations.json', JSON.stringify(stations, null, '\t'));
console.error('Written stations.json');

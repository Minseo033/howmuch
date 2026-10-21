import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { performance } from 'node:perf_hooks';

// Read-only, reproducible projection of a downloaded public /stores/all body.
// Use: node scripts/measure_store_catalog_payload.mjs /path/to/catalog.json
const file = process.argv[2];
if (!file) throw new Error('Supply a saved public /api/stores/all JSON file.');
const source = JSON.parse(readFileSync(file, 'utf8'));
assert.ok(Array.isArray(source));
const light = source.map(({ openingHours, ...mapFields }) => mapFields);
assert.equal(light.length, source.length);
for (let i = 0; i < source.length; i++) {
  assert.deepEqual(light[i], Object.fromEntries(
    Object.entries(source[i]).filter(([key]) => key !== 'openingHours'),
  ));
}
const measurements = [source, light].map((stores) => {
  const json = JSON.stringify(stores);
  const durations = [];
  for (let i = 0; i < 11; i++) {
    const start = performance.now();
    JSON.parse(json);
    if (i) durations.push(performance.now() - start);
  }
  durations.sort((a, b) => a - b);
  return {
    stores: stores.length,
    jsonBytes: Buffer.byteLength(json),
    gzipBytes: gzipSync(json, { level: 9 }).length,
    parseMedianMs: Number(durations[5].toFixed(2)),
  };
});
console.log(JSON.stringify({
  scope: 'Same saved catalog; local Node JSON parse, not device render latency',
  all: measurements[0], catalog: measurements[1],
  jsonReductionPercent: Number((100 * (1 - measurements[1].jsonBytes / measurements[0].jsonBytes)).toFixed(1)),
  gzipReductionPercent: Number((100 * (1 - measurements[1].gzipBytes / measurements[0].gzipBytes)).toFixed(1)),
}, null, 2));

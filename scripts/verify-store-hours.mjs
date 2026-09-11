import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const base = new URL(process.argv[2] ?? 'https://howmuch-backend-1xnu.onrender.com');
const records = JSON.parse(await readFile(new URL('../howmuch_backend/src/main/resources/store-hours.json', import.meta.url), 'utf8'));
async function get(route) {
  const response = await fetch(new URL(route, base), { signal: AbortSignal.timeout(45000), headers: { 'Cache-Control': 'no-cache' } });
  assert.equal(response.status, 200, `${route} HTTP status`);
  return response.json();
}
function verify(store, entry) {
  assert.ok(store, `Missing store: ${entry.storeName}`);
  assert.deepEqual(store.openingHours, {
    status: entry.status, text: entry.text, sourceName: entry.sourceName,
    sourceUrl: entry.sourceUrl, checkedAt: entry.checkedAt,
  }, `Hours mismatch: ${entry.storeName}`);
}
const stores = await get('/api/stores/all');
assert.ok(Array.isArray(stores) && stores.length >= 10000, 'Existing store catalog must be available');
const byId = new Map(stores.map(store => [store.storeId, store]));
console.log(`Live stores: ${stores.length}; stores with hours: ${stores.filter(store => store.openingHours).length}`);
for (const entry of records) verify(byId.get(entry.storeId), entry);
assert.equal(stores.filter(store => store.openingHours).length, records.length, 'Only reviewed records may have hours');
const entry = records[0], store = byId.get(entry.storeId);
const bounds = new URLSearchParams({
  minLat: store.latitude - 0.002, maxLat: store.latitude + 0.002,
  minLng: store.longitude - 0.002, maxLng: store.longitude + 0.002,
});
const nearby = await get(`/api/stores/bounds?${bounds}`);
verify(nearby.find(item => item.storeId === entry.storeId), entry);
console.log(`PASS: ${records.length} source-backed records and map bounds agree with reviewed release data.`);

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
  const expected = {
    status: entry.status, text: entry.text, sourceName: entry.sourceName,
    sourceUrl: entry.sourceUrl, checkedAt: entry.checkedAt,
    parkingYn: entry.parkingYn, packingYn: entry.packingYn,
  };
  if (entry.areaCurrency) expected.areaCurrency = entry.areaCurrency;
  if (entry.imageUrls?.length) expected.imageUrls = entry.imageUrls;
  assert.deepEqual(store.openingHours, expected, `Store details mismatch: ${entry.storeName}`);
}
const stores = await get('/api/stores/all');
assert.ok(Array.isArray(stores) && stores.length >= 10000, 'Existing store catalog must be available');
const byId = new Map(stores.map(store => [store.storeId, store]));
const realHours = records.filter(entry => entry.text !== '등록된 영업시간이 없어요.').length;
const photos = records.filter(entry => entry.imageUrls?.length).length;
assert.ok(records.length >= 9165, `Store detail coverage regressed: ${records.length}`);
assert.ok(realHours >= 135, `Hours coverage regressed: ${realHours}`);
assert.ok(photos >= 251, `Photo coverage regressed: ${photos}`);
console.log(`Live stores: ${stores.length}; enriched: ${records.length}; hours: ${realHours}; photos: ${photos}`);
for (const entry of records) verify(byId.get(entry.storeId), entry);
const enrichedStoreIds = new Set(
  stores.filter(store => store.openingHours).map(store => store.storeId),
);
assert.equal(enrichedStoreIds.size, records.length, 'Only reviewed store IDs may have details');
const entry = records[0], store = byId.get(entry.storeId);
const bounds = new URLSearchParams({
  minLat: store.latitude - 0.002, maxLat: store.latitude + 0.002,
  minLng: store.longitude - 0.002, maxLng: store.longitude + 0.002,
});
const nearby = await get(`/api/stores/bounds?${bounds}`);
verify(nearby.find(item => item.storeId === entry.storeId), entry);
console.log(`PASS: ${records.length} source-backed store details and map bounds agree with reviewed release data.`);

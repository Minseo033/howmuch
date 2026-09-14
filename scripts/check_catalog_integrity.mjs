import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const stores = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/stores-snapshot.json'), 'utf8'));
const supplement = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/stores-supplement.json'), 'utf8'));
const hours = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/store-hours.json'), 'utf8'));

const normalize = v => String(v ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
function storeId(s) {
  return s.storeId || `store_${createHash('sha256').update(
    [s.storeName, s.address, s.phoneNumber].map(normalize).join('|'),
  ).digest('hex').slice(0, 24)}`;
}

const allStores = [...stores, ...supplement];
const snapshotIds = new Set(stores.map(storeId));
const supplementIds = new Set(supplement.map(storeId));
const allIds = new Set(allStores.map(storeId));
const missing = hours.filter(h => !allIds.has(h.storeId));
const collisions = [...supplementIds].filter(id => snapshotIds.has(id));
const storesById = new Map();
for (const store of allStores) {
  const id = storeId(store);
  const rows = storesById.get(id) || [];
  rows.push(store);
  storesById.set(id, rows);
}
const identityMismatches = hours.filter((entry) => !(storesById.get(entry.storeId) || []).some((store) =>
  store.storeName === entry.storeName
    && store.address === entry.address
    && String(store.phoneNumber ?? '') === String(entry.phoneNumber ?? '')));
const supplementPhones = supplement.map(store => String(store.phoneNumber ?? '').replace(/\D/g, ''));
const snapshotPhones = new Set(stores.map(store => String(store.phoneNumber ?? '').replace(/\D/g, '')).filter(value => value.length >= 8));
const supplementEntries = hours.filter(entry => supplementIds.has(entry.storeId));
const allImageUrls = hours.flatMap(entry => entry.imageUrls || []);

assert.equal(supplementIds.size, supplement.length, 'Supplement store IDs must be unique');
assert.equal(allIds.size, snapshotIds.size + supplementIds.size, 'Served store IDs must be globally unique');
assert.equal(collisions.length, 0, 'Supplement store IDs must not collide with the public snapshot');
assert.equal(new Set(supplementPhones).size, supplement.length, 'Supplement phone numbers must be present and unique');
assert.ok(supplementPhones.every(value => value.length >= 8), 'Supplement phone numbers must be verifiable');
assert.ok(supplementPhones.every(value => !snapshotPhones.has(value)), 'Supplement phone numbers must not exist in the public snapshot');
assert.equal(missing.length, 0, 'Every catalog record must exist in the served store union');
assert.equal(identityMismatches.length, 0, 'Every catalog identity must exactly match its store record');
assert.equal(supplementEntries.length, supplement.length, 'Every supplement store must have confirmed details');
assert.ok(supplementEntries.every(entry => entry.imageUrls?.length > 0), 'Every supplement store must have an official photo');
assert.equal(new Set(allImageUrls).size, allImageUrls.length, 'Official photo URLs must not be reused across stores');
console.log(JSON.stringify({
  totalSnapshotRows: stores.length,
  totalSnapshotUniqueStores: snapshotIds.size,
  snapshotDuplicateRows: stores.length - snapshotIds.size,
  totalSupplementStores: supplement.length,
  totalServedStores: allIds.size,
  totalHoursEntries: hours.length,
  validStoreMatches: hours.length - missing.length,
  missingFromStores: missing.length,
  identityMismatches: identityMismatches.length,
  supplementIdCollisions: collisions.length,
  supplementPhoneCollisions: supplementPhones.filter(value => snapshotPhones.has(value)).length,
  duplicatePhotoUrls: allImageUrls.length - new Set(allImageUrls).size,
  sampleMissing: missing.slice(0, 5).map(m => ({ id: m.storeId, name: m.storeName }))
}, null, 2));

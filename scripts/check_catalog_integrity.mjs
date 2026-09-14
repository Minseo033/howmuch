import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const stores = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/stores-snapshot.json'), 'utf8'));
const hours = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/store-hours.json'), 'utf8'));

const normalize = v => String(v ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
function storeId(s) {
  return s.storeId || `store_${createHash('sha256').update(
    [s.storeName, s.address, s.phoneNumber].map(normalize).join('|'),
  ).digest('hex').slice(0, 24)}`;
}

const snapshotIds = new Set(stores.map(storeId));
const missing = hours.filter(h => !snapshotIds.has(h.storeId));
console.log(JSON.stringify({
  totalSnapshotStores: stores.length,
  totalHoursEntries: hours.length,
  validSnapshotMatches: hours.length - missing.length,
  missingFromSnapshot: missing.length,
  sampleMissing: missing.slice(0, 5).map(m => ({ id: m.storeId, name: m.storeName }))
}, null, 2));

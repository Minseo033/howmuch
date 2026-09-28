import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, existsSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertSafeSupplementApply,
  finiteCoordinate,
  isValidSnapshotStore,
} from './data_integrity.mjs';

const validStore = {
  storeId: 'store_1',
  storeName: '테스트 식당',
  address: '서울특별시 중구 세종대로 1',
  latitude: '37.5665',
  longitude: '126.9780',
};

assert.equal(isValidSnapshotStore(validStore), true, 'valid text and Korean coordinates are accepted');
for (const value of [null, '', '  ', false, true, {}, []]) {
  assert.equal(finiteCoordinate(value), null, `invalid coordinate ${String(value)} is rejected`);
}
assert.equal(isValidSnapshotStore({ ...validStore, storeName: '  ' }), false,
  'a present but blank store name is rejected');
assert.equal(isValidSnapshotStore({ ...validStore, address: null }), false,
  'a present but null address is rejected');
assert.equal(isValidSnapshotStore({ ...validStore, latitude: null }), false,
  'null is never coerced to a coordinate');
assert.equal(isValidSnapshotStore({ ...validStore, longitude: '0' }), false,
  'coordinates outside Korea are rejected');

assert.throws(
  () => assertSafeSupplementApply({
    fetched: [{ candidate: { bsshSn: '1' }, error: 'HTTP 503' }],
    previousSupplement: [],
    supplement: [validStore],
    nextCatalog: [validStore],
  }),
  /detail request\(s\) failed/,
  'a failed detail request blocks a replacement apply before files are written',
);
assert.throws(
  () => assertSafeSupplementApply({
    fetched: [],
    previousSupplement: [],
    supplement: [validStore, { ...validStore }],
    nextCatalog: [validStore],
  }),
  /Supplement has a duplicate storeId/,
  'duplicate supplement IDs block apply before files are written',
);
assert.throws(
  () => assertSafeSupplementApply({
    fetched: [],
    previousSupplement: [],
    supplement: [validStore],
    nextCatalog: [validStore, { ...validStore }],
  }),
  /Store-hours catalog has a duplicate storeId/,
  'catalog ID collisions block apply before files are written',
);
assert.doesNotThrow(() => assertSafeSupplementApply({
  fetched: [],
  previousSupplement: [],
  supplement: [validStore],
  nextCatalog: [validStore],
}), 'a complete unique apply plan is accepted');
assert.throws(
  () => assertSafeSupplementApply({
    fetched: [],
    previousSupplement: [{ ...validStore, storeId: 'store_existing' }],
    supplement: [validStore],
    nextCatalog: [validStore],
  }),
  /existing supplement store\(s\) were not re-accepted/,
  'a replacement refresh cannot silently drop an existing supplement record',
);

{
  const fixtureDir = mkdtempSync(path.join(tmpdir(), 'howmuch-snapshot-validator-'));
  const inputPath = path.join(fixtureDir, 'input.json');
  const outputPath = path.join(fixtureDir, 'output.json');
  const rows = Array.from({ length: 10_000 }, (_, index) => ({
    ...validStore,
    storeId: `store_${index}`,
  }));
  for (let index = 0; index < 101; index += 1) {
    rows[index] = { ...rows[index], latitude: null, longitude: false };
  }
  writeFileSync(inputPath, JSON.stringify(rows));
  assert.throws(
    () => execFileSync('node', ['scripts/validate-stores-snapshot.mjs', inputPath, outputPath], {
      cwd: fileURLToPath(new URL('../', import.meta.url)),
      stdio: 'pipe',
    }),
    /Snapshot validation failed/,
    'the validator rejects null/boolean coordinate coercion in a realistic-sized snapshot',
  );
  assert.equal(existsSync(outputPath), false, 'invalid input never creates an output snapshot');
}

console.log('data integrity tests passed');

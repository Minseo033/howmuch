import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { checkSnapshot, classifySnapshotRow } from './validate-stores-snapshot.mjs';

const committed = JSON.parse(readFileSync(
  new URL('../howmuch_backend/src/main/resources/stores-snapshot.json', import.meta.url), 'utf8'));
const row = (overrides = {}) => ({
  storeName: '식당', address: '서울 중구 세종대로 110', latitude: 37.56, longitude: 126.97, ...overrides,
});
const rows = (count, make = () => row()) => Array.from({ length: count }, (_, index) => make(index));

test('the committed snapshot passes, including searchable stores without coordinates', () => {
  const summary = checkSnapshot(committed, { previousCount: committed.length });
  assert.equal(summary.total, committed.length);
  assert.ok(summary.missingCoordinates > 0);
  assert.equal(summary.invalid, 0);
});

test('rows are classified by what the app can show', () => {
  assert.equal(classifySnapshotRow(row()), 'valid');
  assert.equal(classifySnapshotRow(row({ latitude: 0, longitude: 0 })), 'missing-coordinates');
  assert.equal(classifySnapshotRow(row({ latitude: null, longitude: null })), 'missing-coordinates');
  assert.equal(classifySnapshotRow(row({ latitude: 126.97, longitude: 37.56 })), 'invalid');
  assert.equal(classifySnapshotRow(row({ latitude: null, longitude: false })), 'invalid');
  assert.equal(classifySnapshotRow(row({ latitude: 0, longitude: 127.0 })), 'invalid');
  assert.equal(classifySnapshotRow(row({ storeName: ' ' })), 'invalid');
});

test('a large drop against the committed snapshot stops the update unless explicitly allowed', () => {
  const smaller = rows(10_000);
  assert.throws(() => checkSnapshot(smaller, { previousCount: 11_207 }), /shrank/);
  assert.equal(checkSnapshot(smaller, { previousCount: 11_207, allowShrink: true }).total, 10_000);
  assert.equal(checkSnapshot(smaller, { previousCount: 10_400 }).total, 10_000);
});

test('broken rows or a geocoding outage fail validation', () => {
  assert.throws(() => checkSnapshot(rows(10_000, (i) => (i < 60 ? row({ address: '' }) : row()))), /lack a name or address/);
  assert.throws(() => checkSnapshot(rows(10_000, (i) => (i < 600 ? row({ latitude: 0, longitude: 0 }) : row()))), /no coordinates/);
  assert.throws(() => checkSnapshot(rows(9_999)), /at least/);
});

import assert from 'node:assert/strict';
import test from 'node:test';
import { GOODPRICE_SOURCE_NAME, applyPhotoMatch } from './photo_merge.mjs';

const official = 'https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=1';

test('re-running with photos the record already has changes nothing', () => {
  const entry = {
    sourceName: '부산광역시 서구', sourceUrl: 'https://www.bsseogu.go.kr/hours.csv',
    checkedAt: '2026-09-24', imageUrls: ['a.jpg'],
  };
  const before = structuredClone(entry);

  assert.equal(applyPhotoMatch(entry, { sourceUrl: official, urls: ['a.jpg'], checkedAt: '2026-10-06' }), false);
  assert.deepEqual(entry, before);
});

test('new photos keep the hours source of a municipal record', () => {
  const entry = {
    sourceName: '부산광역시 서구', sourceUrl: 'https://www.bsseogu.go.kr/hours.csv',
    checkedAt: '2026-09-24', imageUrls: ['a.jpg'],
  };

  assert.equal(applyPhotoMatch(entry, { sourceUrl: official, urls: ['a.jpg', 'b.jpg'], checkedAt: '2026-10-06' }), true);
  assert.deepEqual(entry.imageUrls, ['a.jpg', 'b.jpg']);
  assert.equal(entry.sourceUrl, 'https://www.bsseogu.go.kr/hours.csv');
  assert.equal(entry.checkedAt, '2026-09-24');
});

test('goodprice-sourced records take the official page and check date', () => {
  const entry = { sourceName: GOODPRICE_SOURCE_NAME, sourceUrl: 'old', checkedAt: '2026-09-15', imageUrls: [] };

  assert.equal(applyPhotoMatch(entry, { sourceUrl: official, urls: ['c.jpg'], checkedAt: '2026-10-06' }), true);
  assert.equal(entry.sourceUrl, official);
  assert.equal(entry.checkedAt, '2026-10-06');
});

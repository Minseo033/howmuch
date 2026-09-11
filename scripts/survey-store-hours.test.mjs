import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cleanHours, matches, storeId, usableHours } from './survey-store-hours.mjs';

test('same names at different addresses or with conflicting phones are never accepted', () => {
  const store = { storeName: '동네식당', address: '서울특별시 강동구 천중로 73 (천호동)', phoneNumber: '02-123-4567' };
  const candidate = { bsshNm: '동네식당', roadNmAddr: '서울특별시 강동구 천중로 73', bsshTelno: '021234567' };
  assert.equal(matches(store, candidate), true);
  assert.equal(matches(store, { ...candidate, roadNmAddr: '서울특별시 강동구 천중로 75' }), false);
  assert.equal(matches(store, { ...candidate, bsshTelno: '02-999-9999' }), false);
  assert.equal(matches(store, { ...candidate, bsshNm: '동네식당 2호점' }), false);
  assert.notEqual(storeId(store), storeId({ ...store, address: '다른 주소' }));
});

test('preserves overnight hours and closure prose without inferring a schedule', () => {
  const text = cleanHours('  18:00~익일 02:00<br>매주 월요일 휴무\r\n ');
  assert.equal(text, '18:00~익일 02:00\n매주 월요일 휴무');
  assert.equal(usableHours(text), true);
  assert.equal(usableHours('정보 없음'), false);
  assert.equal(usableHours('월요일 휴무'), false);
  assert.equal(usableHours('10:00~미정'), false);
});

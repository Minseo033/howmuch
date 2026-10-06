import assert from 'node:assert/strict';
import test from 'node:test';
import { confirmedMenuPrice } from './goodprice_menus.mjs';

test('missing or blank prices never become 0 won menus', () => {
  for (const raw of ['', '   ', null, undefined, 'null', '가격문의', '0', 0, '-1']) {
    assert.equal(confirmedMenuPrice(raw), null, `${JSON.stringify(raw)} must not be a confirmed price`);
  }
});

test('positive amounts are normalized to digits', () => {
  assert.equal(confirmedMenuPrice(9000), '9000');
  assert.equal(confirmedMenuPrice('9,000'), '9000');
  assert.equal(confirmedMenuPrice(' 7000원 '), '7000');
});

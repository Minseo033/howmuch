import assert from 'node:assert/strict';
import test from 'node:test';
import { addressMatches, provinceOf } from './store_address.mjs';

test('building numbers must match as a whole, not by prefix', () => {
  assert.equal(addressMatches('경기도 수원시 팔달구 중앙로 3', '경기도 수원시 팔달구 중앙로 35'), false);
  assert.equal(addressMatches('경기도 수원시 팔달구 중앙로 3', '경기도 수원시 팔달구 중앙로 3-1'), false);
  assert.equal(addressMatches('경기도 수원시 팔달구 중앙로 3', '경기도 수원시 팔달구 중앙로3번길 5'), false);
  assert.equal(addressMatches('경기도 수원시 팔달구 중앙로 35', '경기도 수원시 팔달구 중앙로 35'), true);
});

test('province prefixes, spacing and floor details do not split one address', () => {
  assert.equal(addressMatches('서울특별시 중구 세종대로 110', '중구 세종대로 110'), true);
  assert.equal(addressMatches('서울 중구 세종대로 110', '서울특별시 중구 세종대로110'), true);
  assert.equal(addressMatches('서울특별시 중구 세종대로 110, 2층', '서울특별시 중구 세종대로 110'), true);
  assert.equal(addressMatches('서울특별시 중구 세종대로 110 (태평로1가)', '서울특별시 중구 세종대로 110'), true);
});

test('the same street number in another province is a different store', () => {
  assert.equal(addressMatches('부산광역시 북구 금곡대로 12', '울산광역시 북구 금곡대로 12'), false);
  assert.equal(addressMatches('수원 중앙로 35', '안양 중앙로 35'), false);
});

test('Gwangju-si in Gyeonggi is not mistaken for Gwangju metropolitan city', () => {
  assert.equal(provinceOf('광주시 오포읍 문형로 10'), null);
  assert.equal(provinceOf('광주 북구 우치로 77'), '전남광주');
  assert.equal(provinceOf('경기도 광주시 오포읍 문형로 10'), '경기');
});

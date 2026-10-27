import assert from 'node:assert/strict';
import test from 'node:test';
import { createRuntime } from './fixtures/kakao_map_runtime.mjs';

const catalog = Array.from({ length: 15000 }, (_, i) => ({
  storeId: `store-${i}`, lat: 33 + i * .0004, lng: 127.005,
  title: `매장 ${i}`, menu: '국밥', price: '7,000원',
}));

function setup(native, withClusterer = false) {
  const runtime = createRuntime({ native, withClusterer });
  const c = runtime.context;
  if (native) c.initializeMap();
  else c.initKakaoMap('map', 37.5, 127);
  const map = native ? c.map : c.kakaoMapObjects.map;
  map.level = 3;
  let bounds = { minLat: 37.5, maxLat: 37.56, minLng: 127, maxLng: 127.01 };
  let reads = 0;
  map.getBounds = () => {
    reads++;
    return {
      getSouthWest: () => ({ getLat: () => bounds.minLat, getLng: () => bounds.minLng }),
      getNorthEast: () => ({ getLat: () => bounds.maxLat, getLng: () => bounds.maxLng }),
    };
  };
  if (native) c.addMobileMarkers(JSON.stringify(catalog));
  else c.addMobileMarkers('map', JSON.stringify(catalog));
  return {
    ...runtime, map,
    sync(hidden = {}) { if (native) c.syncStoreOverlays(hidden); else c.syncKakaoStoreOverlays('map', hidden); },
    highlight(index) { if (native) c.highlightMarker(index); else c.highlightKakaoMapMarker('map', index); },
    cached() { return native ? c.customOverlays : c.customOverlays.map; },
    move(minLat, maxLat) { bounds = { ...bounds, minLat, maxLat }; },
    get reads() { return reads; },
  };
}

for (const native of [false, true]) {
  const platform = native ? 'native WebView' : 'web';

  test(`${platform}: unchanged dense viewport reads bounds once and does not reattach DOM`, () => {
    const runtime = setup(native);
    assert.ok(runtime.overlays.filter((overlay) => overlay.map).length > 100,
      'visible labels retain every store rather than imposing a 100-store cap');
    let writes = 0, lookups = 0;
    for (const overlay of runtime.overlays) {
      const setMap = overlay.setMap;
      overlay.setMap = (map) => { writes++; setMap(map); };
    }
    const lookup = runtime.context.document.getElementById;
    runtime.context.document.getElementById = (id) => { lookups++; return lookup(id); };
    const readsBefore = runtime.reads;
    for (let i = 0; i < 20; i++) runtime.sync();
    assert.equal(runtime.reads - readsBefore, 20);
    assert.equal(writes, 0);
    assert.equal(lookups, 0);
  });

  test(`${platform}: rapid panning removes old labels, bounds the cache, and preserves a selection`, () => {
    const runtime = setup(native);
    runtime.highlight(0);
    for (let i = 0; i < 60; i++) {
      const minLat = 33.1 + i * .08;
      runtime.move(minLat, minLat + .06);
      runtime.sync();
      const cached = runtime.cached();
      const expected = catalog.filter((item, index) => index === 0 ||
        (item.lat >= minLat && item.lat <= minLat + .06));
      const visible = Object.keys(cached).filter((index) => cached[index]._howmuchMap === runtime.map);
      assert.deepEqual(visible.map(Number).sort((a, b) => a - b),
        expected.map((item) => Number(item.storeId.slice(6))).sort((a, b) => a - b));
      assert.ok(Object.keys(cached).length <= Math.max(512, visible.length));
      assert.equal(cached[0]._howmuchSelected, true);
    }
  });

  test(`${platform}: full catalog still contributes to clusters without 15k invisible click handlers`, () => {
    const runtime = setup(native, true);
    assert.equal(runtime.clusterers[0].markers.length, catalog.length);
    assert.ok(runtime.clusterers[0].markers.every((marker) => marker.options.image));
    assert.ok(runtime.clusterers[0].markers.every((marker) => marker.options.clickable === false));
    assert.equal(runtime.listeners.filter((listener) =>
      runtime.clusterers[0].markers.includes(listener.map)).length, 0);
    runtime.highlight(2);
    assert.equal(runtime.cached()[2]._howmuchSelected, true);
  });
}

test('native: a covered map defers new marker work and resumes with the latest payload', () => {
  const runtime = setup(true);
  const c = runtime.context;
  c.setMapActive(false);
  const before = runtime.reads;
  for (let i = 0; i < 20; i++) runtime.sync();
  c.addMobileMarkers(JSON.stringify(catalog.slice(0, 200)));
  c.addMobileMarkers(JSON.stringify(catalog.slice(0, 300)));
  assert.equal(runtime.reads, before);
  assert.equal(c.markerDataCache.length, catalog.length);
  c.setMapActive(true);
  assert.equal(c.markerDataCache.length, 300);
  assert.equal(c.pendingMarkerPayload, null);
});

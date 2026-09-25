import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const mapScript = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1])
  .find((source) => source.includes('function initKakaoMap'));
assert.ok(mapScript, 'Kakao map runtime script is present');

function createRuntime() {
  let nextTimerId = 1;
  const timers = new globalThis.Map();
  const observers = [];
  const overlays = [];
  const elements = new globalThis.Map();
  const listeners = [];

  function makeElement() {
    return {
      style: {},
      children: [],
      childElementCount: 0,
      appendChild(child) { this.children.push(child); this.childElementCount = this.children.length; },
    };
  }

  const container = makeElement();
  container.id = 'map';
  container.offsetWidth = 360;
  container.offsetHeight = 640;
  elements.set('map', container);

  class ResizeObserver {
    constructor(callback) { this.callback = callback; this.disconnected = false; observers.push(this); }
    observe(target) { this.target = target; }
    disconnect() { this.disconnected = true; }
  }

  function LatLng(lat, lng) { this.lat = lat; this.lng = lng; }
  function KakaoMap(node) {
    this.node = node;
    node.childElementCount = 1;
    this.relayoutCount = 0;
    this.getNode = () => node;
    this.relayout = () => { this.relayoutCount += 1; };
    this.setCenter = () => {};
    this.panTo = () => {};
    this.setMaxLevel = (level) => { this.maxLevel = level; };
  }
  function CustomOverlay(options) {
    this.options = options;
    this.map = options.map || null;
    this.zIndex = options.zIndex || 0;
    this.setMap = (map) => { this.map = map; };
    this.setPosition = () => {};
    this.setZIndex = (zIndex) => { this.zIndex = zIndex; };
    overlays.push(this);
  }
  const context = {
    console: { error() {}, log() {} },
    document: {
      getElementById: (id) => elements.get(id) || null,
      createElement: () => makeElement(),
    },
    setTimeout(callback) { const id = nextTimerId++; timers.set(id, callback); return id; },
    clearTimeout(id) { timers.delete(id); },
    ResizeObserver,
  };
  context.window = context;
  context.kakao = {
    maps: {
      load: (callback) => callback(),
      LatLng,
      Map: KakaoMap,
      CustomOverlay,
      event: {
        addListener(map, type, handler) { listeners.push({ map, type, handler }); },
        removeListener(map, type, handler) {
          const index = listeners.findIndex((item) => item.map === map && item.type === type && item.handler === handler);
          if (index !== -1) listeners.splice(index, 1);
        },
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(mapScript, context, { filename: 'web/index.html' });
  return {
    context,
    observers,
    overlays,
    listeners,
    runTimers() {
      const pending = [...timers.entries()];
      timers.clear();
      for (const [, callback] of pending) callback();
    },
  };
}

{
  const { context, observers, listeners, runTimers } = createRuntime();
  let idleCalls = 0;
  context.onKakaoMapIdle = () => { idleCalls += 1; };
  context.initKakaoMap('map', 37.5, 127.0);
  assert.equal(context.kakaoMapObjects.map.maxLevel, 10,
    'the web map limits zoom-out to the bounds endpoint supported range');
  assert.equal(observers.length, 1, 'one observer is attached for a map instance');
  context.initKakaoMap('map', 37.6, 127.1);
  assert.equal(context.kakaoMapObjects.map.maxLevel, 10,
    'reused maps keep the same zoom-out limit');
  assert.equal(listeners.length, 4, 'reinitializing replaces rather than accumulates event listeners');
  assert.equal(observers.length, 2, 'a reused map refreshes its observer generation');
  assert.equal(observers[0].disconnected, true, 'the prior observer is released before reuse');

  context.disposeKakaoMap('map');
  assert.equal(listeners.length, 0, 'disposing removes all map event listeners');
  assert.equal(observers[1].disconnected, true, 'disposing a map disconnects its ResizeObserver');
  assert.equal(context.kakaoMapObjects.map, undefined, 'disposing removes the stale map reference');
  runTimers();
  assert.equal(idleCalls, 0, 'disposed maps cannot fire delayed idle callbacks');
}

{
  const { context, listeners, runTimers } = createRuntime();
  let moved = 0;
  context.onKakaoMapMoveStart = () => { moved++; };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  listeners.find((item) => item.type === 'dragstart').handler();
  listeners.find((item) => item.type === 'zoom_start').handler();
  assert.equal(moved, 2, 'dragging and zooming invalidate pending Flutter requests');
  const idle = listeners.find((item) => item.type === 'idle').handler;
  for (let index = 0; index < 100; index++) idle();
  assert.equal(context.kakaoMapLifecycles.map.timers.length, 1, 'debouncing retains only the live timer');
  let reads = 0;
  context.kakaoMapObjects.map.getBounds = () => {
    reads++;
    return {
      getSouthWest: () => ({ getLat: () => 37, getLng: () => 126 }),
      getNorthEast: () => ({ getLat: () => reads === 1 ? 37 : 38, getLng: () => 127 }),
    };
  };
  assert.equal(JSON.parse(context.getKakaoMapBounds('map')).maxLat, 38,
    'collapsed bounds are read again after relayout');
  context.kakaoMapObjects.map.getBounds = () => null;
  assert.equal(context.getKakaoMapBounds('map'), null, 'unavailable bounds are safely deferred');
}

{
  const { context, listeners, runTimers } = createRuntime();
  let idleCalls = 0;
  let maxLat = 38;
  context.onKakaoMapIdle = () => { idleCalls++; };
  context.initKakaoMap('map', 37.5, 127);
  context.kakaoMapObjects.map.getBounds = () => ({
    getSouthWest: () => ({ getLat: () => 37, getLng: () => 126 }),
    getNorthEast: () => ({ getLat: () => maxLat, getLng: () => 127 }),
  });
  runTimers();
  assert.equal(idleCalls, 1, 'initial relayout callbacks request identical bounds once');
  const idle = listeners.find((item) => item.type === 'idle').handler;
  idle();
  runTimers();
  assert.equal(idleCalls, 1, 'marker relayout does not immediately re-request the same bounds');
  maxLat = 38.1;
  idle();
  runTimers();
  assert.equal(idleCalls, 2, 'a changed map viewport still requests new stores');
  context.kakaoMapLifecycles.map.lastIdleAt = Date.now() - 2000;
  idle();
  runTimers();
  assert.equal(idleCalls, 3, 'the same viewport can retry after the short deduplication window');
}

{
  const { context, overlays, runTimers } = createRuntime();
  delete context.kakao;
  context.addMobileMarkers('map', JSON.stringify([{ lat: 1, lng: 2, title: 'old', menu: '', price: '' }]));
  context.kakao = {
    maps: {
      load: (callback) => callback(),
      LatLng: function LatLng(lat, lng) { this.lat = lat; this.lng = lng; },
      CustomOverlay: function CustomOverlay(options) {
        this.options = options;
        this.map = options.map || null;
        this.setMap = (map) => { this.map = map; };
        overlays.push(this);
      },
    },
  };
  context.kakaoMapObjects.map = { relayout() {} };
  context.addMobileMarkers('map', JSON.stringify([{ lat: 3, lng: 4, title: 'new', menu: '', price: '' }]));
  runTimers();
  assert.equal(context.markerDataCache.map.length, 1,
    'the latest marker payload has one item');
  assert.equal(context.markerDataCache.map[0].title, 'new',
    'a delayed older marker request cannot overwrite the latest marker payload');
  assert.equal(overlays.length, 1, 'only the current marker set creates overlays');
}

{
  const { context, overlays } = createRuntime();
  let centeredOn = null;
  context.kakaoMapObjects.map = {
    relayout() {},
    panTo(position) { centeredOn = position; },
  };
  const clicked = [];
  context.onKakaoMarkerClick = (index) => clicked.push(index);
  context.addMobileMarkers('map', JSON.stringify([
    { lat: 37.5, lng: 127, title: '앞 매장', menu: '메뉴 A', price: '5,000원', source: 'API' },
    { lat: 37.5, lng: 127, title: '뒤 매장', menu: '메뉴 B', price: '6,000원', source: 'USER', selected: true },
  ]));

  assert.deepEqual(overlays.map((overlay) => overlay.zIndex), [3, 10],
    'the selected overlapping marker starts in front of other markers');
  assert.equal(overlays[1].options.content.style.transform, 'scale(1.2)',
    'selected marker receives the visual selected treatment');

  context.highlightKakaoMapMarker('map', 0);
  assert.deepEqual(overlays.map((overlay) => overlay.zIndex), [10, 3],
    'selecting a marker raises it above overlapping markers');
  overlays[1].options.content.children[0].onclick({ stopPropagation() {} });
  assert.deepEqual(clicked, [1], 'marker click forwards the clicked store index');
  assert.deepEqual(overlays.map((overlay) => overlay.zIndex), [3, 10],
    'clicking a marker immediately raises that marker before Flutter responds');

  context.setKakaoMapCenterFromSwipe('map', 37.501, 127.002);
  assert.deepEqual(
    { lat: centeredOn.lat, lng: centeredOn.lng },
    { lat: 37.501, lng: 127.002 },
    'swiping to another store can pan the map to that store coordinates',
  );
}

console.log('web map lifecycle tests passed');

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const mapScript = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1])
  .find((source) => source.includes('function initKakaoMap'));
assert.ok(mapScript, 'Kakao map runtime script is present');

function createRuntime({ withClusterer = false } = {}) {
  let nextTimerId = 1;
  const timers = new globalThis.Map();
  const observers = [];
  const overlays = [];
  const clusterers = [];
  const elements = new globalThis.Map();
  const listeners = [];

  function makeElement() {
    return {
      style: {},
      children: [],
      childElementCount: 0,
      isConnected: true,
      setAttribute(name, value) { this[name] = value; },
      replaceChildren() { this.children = []; this.childElementCount = 0; },
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

  function LatLng(lat, lng) { this.lat = lat; this.lng = lng; this.getLat = () => lat; this.getLng = () => lng; }
  function LatLngBounds() { this.points = []; this.extend = (point) => this.points.push(point); }
  function KakaoMap(node, options) {
    this.node = node;
    node.childElementCount = 1;
    this.relayoutCount = 0;
    this.getNode = () => node;
    this.relayout = () => { this.relayoutCount += 1; };
    this.center = options.center;
    this.level = options.level;
    this.setCenter = (position) => { this.center = position; };
    this.getCenter = () => this.center;
    this.getLevel = () => this.level;
    this.setLevel = (level) => { this.level = level; };
    this.setBounds = (bounds, ...padding) => { this.fittedBounds = bounds; this.padding = padding; };
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
  function Marker(options) {
    this.options = options;
    this.map = null;
    this.setMap = (map) => { this.map = map; };
  }
  function MarkerClusterer(options) {
    this.options = options;
    this.markers = [];
    this.cleared = false;
    this.addMarkers = (markers) => {
      this.markers = markers;
      this.lastCluster = {
        getMarkers: () => markers,
        getCenter: () => markers[0].options.position,
      };
      const listener = listeners.find((item) => item.map === this && item.type === 'clustered');
      if (listener) listener.handler([this.lastCluster]);
    };
    this.clear = () => { this.cleared = true; this.markers = []; };
    clusterers.push(this);
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
      LatLngBounds,
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
  if (withClusterer) {
    context.kakao.maps.Marker = Marker;
    context.kakao.maps.MarkerClusterer = MarkerClusterer;
  }
  vm.createContext(context);
  vm.runInContext(mapScript, context, { filename: 'web/index.html' });
  context.kakaoMapCallbacks.map = {};
  // Old test names are aliases only inside the harness. Runtime callbacks
  // are keyed by platform-view ID and cannot clobber another screen.
  for (const [legacy, current] of Object.entries({ onKakaoMapIdle: 'onIdle', onKakaoMapMoveStart: 'onMoveStart', onKakaoMarkerClick: 'onMarkerClick' })) {
    Object.defineProperty(context, legacy, { set(value) { context.kakaoMapCallbacks.map[current] = value; } });
  }
  return {
    context,
    observers,
    overlays,
    clusterers,
    listeners,
    runTimers() {
      const pending = [...timers.entries()];
      timers.clear();
      for (const [, callback] of pending) callback();
    },
  };
}

{
  const { context, overlays, clusterers, listeners } = createRuntime({ withClusterer: true });
  const map = {
    level: 7,
    relayout() {},
    getLevel() { return this.level; },
    setLevel(level, options) { this.level = level; this.levelOptions = options; },
  };
  context.kakaoMapObjects.map = map;
  context.addMobileMarkers('map', JSON.stringify([
    { storeId: 'one', lat: 37.5, lng: 127, title: '첫 매장', menu: '백반', price: '8,000원' },
    { storeId: 'two', lat: 37.5001, lng: 127.0001, title: '둘째 매장', menu: '국밥', price: '9,000원' },
    { storeId: 'picked', lat: 37.5002, lng: 127.0002, title: '선택 매장', menu: '비빔밥', price: '10,000원', selected: true },
  ]));

  assert.equal(clusterers.length, 1, 'nearby marker labels are managed by one clusterer');
  assert.equal(clusterers[0].options.minLevel, 4, 'close zoom keeps individual store labels');
  assert.equal(clusterers[0].options.gridSize, 72, 'cluster spacing prevents label collisions');
  assert.equal(clusterers[0].options.styles[0].background, '#2563EB',
    'small clusters use the product blue');
  assert.deepEqual(Array.from(clusterers[0].markers, (marker) => marker._howmuchIndex), [0, 1],
    'the selected store remains outside the cluster');
  assert.deepEqual(overlays.map((overlay) => overlay.map), [null, null, map],
    'clustered labels hide while the selected store stays visible');

  const clusterClick = listeners.find(
    (item) => item.map === clusterers[0] && item.type === 'clusterclick',
  );
  clusterClick.handler(clusterers[0].lastCluster);
  assert.equal(map.level, 5, 'a cluster tap zooms in two levels');
  assert.equal(map.levelOptions.anchor.lat, 37.5, 'cluster zoom stays anchored on the group');

  const oldClusterer = clusterers[0];
  context.highlightKakaoMapMarker('map', 0);
  assert.equal(oldClusterer.cleared, true, 'selection rebuilds stale cluster membership');
  assert.deepEqual(Array.from(clusterers[1].markers, (marker) => marker._howmuchIndex), [1, 2],
    'the newly selected store is separated from the rebuilt cluster');
  assert.deepEqual(overlays.map((overlay) => overlay.map), [map, null, null],
    'only the selected label remains above its cluster');
}

{
  const { context, listeners, runTimers } = createRuntime();
  const events = [];
  context.kakaoMapCallbacks.map = { onMarkerClick: (...values) => events.push(values) };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  map.setCenter(new context.kakao.maps.LatLng(37.7, 127.2));
  map.setLevel(7);
  context.recoverKakaoMap('map');
  assert.notEqual(context.kakaoMapObjects.map, map, 'recovery replaces only the map object');
  assert.equal(context.kakaoMapObjects.map.getCenter().lat, 37.7, 'map-only recovery retains center');
  assert.equal(context.kakaoMapObjects.map.getLevel(), 7, 'map-only recovery retains zoom');
  assert.equal(listeners.length, 4, 'recovery does not accumulate map event listeners');
  context.emitKakaoMapEvent('map', 'onMarkerClick', 0, 'current');
  assert.equal(events.length, 1, 'recovery retains its own Flutter callbacks');
  context.fitKakaoMapStores('map', JSON.stringify([{lat: 37.5, lng: 127}, {lat: 35.2, lng: 129}, {lat: 0, lng: 0}]));
  assert.equal(context.kakaoMapObjects.map.fittedBounds.points.length, 2, 'search fits all valid result coordinates');
  assert.deepEqual(context.kakaoMapObjects.map.padding, [150, 40, 260, 40], 'fit keeps search controls and cards clear');
  context.setKakaoMapSearchMode('map', true);
  assert.equal(context.kakaoMapObjects.map.maxLevel, 14, 'local result mode can fit nationwide results without a bounds API query');
  context.setKakaoMapSearchMode('map', false);
  assert.equal(context.kakaoMapObjects.map.maxLevel, 10, 'normal map mode restores backend-safe zoom limit');
}

{
  const { context, runTimers } = createRuntime();
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  map.node.offsetWidth = 0;
  context.fitKakaoMapStores('map', JSON.stringify([{lat: 37.09, lng: 126.86}]));
  assert.equal(map.center.lat, 37.5, 'hidden route is not manipulated');
  runTimers();
  map.node.offsetWidth = 360;
  runTimers();
  assert.equal(map.center.lat, 37.09, 'search navigation survives a zero-size route-pop frame');
  assert.equal(map.level, 4);
  map.node.offsetWidth = 0;
  context.fitKakaoMapStores('map', JSON.stringify([{lat: 35.1, lng: 129.1}]));
  context.fitKakaoMapStores('map', JSON.stringify([{lat: 36.1, lng: 128.1}]));
  map.node.offsetWidth = 360;
  runTimers();
  assert.equal(map.center.lat, 36.1, 'a newer search cancels the old pending fit');
  map.node.offsetWidth = 0;
  context.fitKakaoMapStores('map', JSON.stringify([{lat: 35.1, lng: 129.1}]));
  context.setKakaoMapSearchMode('map', false);
  map.node.offsetWidth = 360;
  runTimers();
  assert.equal(map.center.lat, 36.1, 'clearing a search cancels its pending navigation');
  map.node.offsetWidth = 0;
  context.fitKakaoMapStores('map', JSON.stringify([{lat: 35.1, lng: 129.1}]));
  context.disposeKakaoMap('map');
  map.node.offsetWidth = 360;
  runTimers();
  assert.equal(map.center.lat, 36.1, 'disposed views never apply a pending search navigation');
}

{
  const { context, observers, runTimers } = createRuntime();
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  map.setLevel(7);
  const originalCenter = map.getCenter();
  const observer = observers[0];
  for (let i = 0; i < 100; i++) observer.callback();
  runTimers();
  assert.equal(map.relayoutCount, 0, 'identical size never triggers relayout');
  for (let i = 0; i < 20; i++) {
    map.node.offsetWidth = 361 + i;
    observer.callback();
  }
  assert.equal(context.kakaoMapLifecycles.map.timers.length, 1, 'resize bursts coalesce into one owned timer');
  runTimers();
  assert.equal(map.relayoutCount, 1, 'resize burst performs one relayout');
  assert.equal(map.getCenter(), originalCenter, 'resize preserves center');
  assert.equal(map.getLevel(), 7, 'resize preserves zoom');
  map.node.offsetWidth = 0;
  observer.callback();
  runTimers();
  assert.equal(map.relayoutCount, 1, 'zero-size view is not laid out');
  map.node.offsetWidth = 500;
  observer.callback();
  map.node.isConnected = false;
  runTimers();
  assert.equal(map.relayoutCount, 1, 'detached view is not laid out');
}

{
  const { context } = createRuntime();
  const events = [];
  context.kakaoMapCallbacks.map = { onMarkerClick: (...values) => events.push(['first', ...values]) };
  context.kakaoMapCallbacks.other = { onMarkerClick: (...values) => events.push(['other', ...values]) };
  context.emitKakaoMapEvent('map', 'onMarkerClick', 1, 'store-a');
  context.emitKakaoMapEvent('other', 'onMarkerClick', 2, 'store-b');
  assert.deepEqual(events, [['first', 1, 'store-a'], ['other', 2, 'store-b']], 'each map owns its callbacks');
  context.disposeKakaoMap('map');
  context.emitKakaoMapEvent('map', 'onMarkerClick', 0, 'stale');
  assert.equal(events.length, 2, 'disposed views cannot receive callbacks');
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

{
  const { context, overlays, listeners, observers, runTimers } = createRuntime();
  const events = [];
  context.kakaoMapCallbacks.map = { onMarkerClick: (index, id) => events.push([index, id]) };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  context.addMobileMarkers('map', JSON.stringify([
    { storeId: 'front', lat: 37.5, lng: 127, title: '앞', menu: '메뉴', price: '3,000 / 3,500원' },
    { storeId: 'back', lat: 37.5, lng: 127, title: '뒤', menu: '무료', price: '무료' },
  ]));
  const bubble = overlays[1].options.content.children[0];
  const background = listeners.find((item) => item.type === 'click').handler;
  const drag = listeners.find((item) => item.type === 'dragstart').handler;
  for (let index = 0; index < 100; index++) {
    bubble.onclick({ stopPropagation() {} });
    assert.equal(bubble['aria-pressed'], 'true', 'selected marker exposes its selected state');
    background();
    assert.equal(bubble['aria-pressed'], 'false', 'background tap clears marker selected state');
    drag();
    if (index % 5 === 0) {
      map.node.offsetWidth++;
      observers[0].callback();
      runTimers();
    }
  }
  assert.equal(events.length, 200, '100 select/background/drag cycles reach the correct view');
  assert.equal(events[0][1], 'back', 'marker callback includes the stable store ID');
  assert.equal(context.kakaoMapObjects.map, map, 'interaction never replaces the map object');
  assert.equal(listeners.length, 4, 'interaction does not accumulate listeners');
  assert.equal(overlays.length, 2, 'selection does not rebuild overlay objects');
  context.disposeKakaoMap('map');
  runTimers();
  bubble.onclick({ stopPropagation() {} });
  assert.equal(events.length, 200, 'a detached marker cannot call Flutter');
  assert.equal(Object.keys(context.kakaoMarkerRequestGenerations).length, 0, 'disposed request ownership is released');
}

{
  const { context, listeners, observers, runTimers } = createRuntime();
  for (let index = 0; index < 20; index++) {
    context.kakaoMapCallbacks.map = {};
    context.initKakaoMap('map', 37.5, 127);
    runTimers();
    assert.equal(listeners.length, 4);
    context.disposeKakaoMap('map');
    runTimers();
    assert.equal(listeners.length, 0, 'screen re-entry releases the previous screen listeners');
    assert.equal(Object.keys(context.kakaoMapObjects).length, 0);
    assert.equal(Object.keys(context.kakaoMapCallbacks).length, 0);
    assert.equal(Object.keys(context.kakaoMapLifecycles).length, 0);
  }
  assert.ok(observers.every((observer) => observer.disconnected), 'every old observer is disconnected');
}

{
  const { context, runTimers } = createRuntime();
  const events = [];
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  context.getKakaoMapLifecycle('other');
  context.kakaoMapCallbacks.other = { onMarkerClick: () => events.push('other') };
  context.setSuppressMarkerClicks('map', 1000);
  context.onMarkerClickWeb('other', 0);
  assert.deepEqual(events, ['other'], 'a click suppression timer belongs only to its own screen');
  context.disposeKakaoMap('map');
  runTimers();
  assert.equal(context.kakaoMapLifecycles.map, undefined, 'the old suppression timer cannot revive a disposed view');
}

{
  const { context, runTimers } = createRuntime();
  const errors = [];
  context.kakaoMapCallbacks.map = { onError: (message) => errors.push(message) };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  let reads = 0;
  context.kakaoMapObjects.map.getBounds = () => {
    if (++reads > 1) throw Error('SDK bounds failure after resize');
    return null;
  };
  assert.equal(context.getKakaoMapBounds('map'), null);
  assert.equal(errors.length, 1, 'bounds recovery failure becomes a map-only recovery state');
}

{
  // P1-16: a marker response that arrives while home is covered is a wait,
  // not a map error, and it is drawn once the same map is visible again.
  const { context, overlays, observers, runTimers } = createRuntime();
  const errors = [];
  let idleCalls = 0;
  context.kakaoMapCallbacks.map = {
    onError: (message) => errors.push(message),
    onIdle: () => { idleCalls++; },
  };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  map.node.offsetWidth = 0;
  observers[0].callback();
  context.addMobileMarkers('map', JSON.stringify([
    { storeId: 'hidden-a', lat: 37.5, lng: 127, title: '가려진 동안 도착', menu: '국밥', price: '8,000원' },
  ]));
  for (let index = 0; index < 60; index++) runTimers();
  assert.deepEqual(errors, [], 'a covered map never turns a marker response into a map error');
  assert.equal(overlays.length, 0, 'nothing is drawn into a zero-size map');
  map.node.offsetWidth = 360;
  const idleBefore = idleCalls;
  observers[0].callback();
  assert.equal(overlays.length, 1, 'the pending marker payload is drawn when the map is visible again');
  assert.equal(context.markerDataCache.map[0].storeId, 'hidden-a');
  runTimers();
  assert.ok(idleCalls > idleBefore, 'Flutter is asked to read the viewport again after the hidden period');
  assert.equal(context.kakaoMapObjects.map, map, 'returning does not rebuild the map');
}

{
  // P1-16 without a resize notification: the slow visibility check flushes.
  const { context, overlays, runTimers } = createRuntime();
  const errors = [];
  context.kakaoMapCallbacks.map = { onError: (message) => errors.push(message) };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  map.node.isConnected = false;
  context.addMobileMarkers('map', JSON.stringify([{ storeId: 'old', lat: 37.5, lng: 127, title: 'old', menu: '', price: '' }]));
  context.addMobileMarkers('map', JSON.stringify([{ storeId: 'new', lat: 37.6, lng: 127.1, title: 'new', menu: '', price: '' }]));
  for (let index = 0; index < 40; index++) runTimers();
  map.node.isConnected = true;
  runTimers();
  assert.deepEqual(errors, []);
  assert.equal(overlays.length, 1, 'only the newest hidden payload is drawn');
  assert.equal(context.markerDataCache.map[0].storeId, 'new');
  context.addMobileMarkers('map', JSON.stringify([]));
  map.node.offsetWidth = 0;
  context.addMobileMarkers('map', JSON.stringify([{ storeId: 'late', lat: 1, lng: 2, title: 'late', menu: '', price: '' }]));
  context.disposeKakaoMap('map');
  map.node.offsetWidth = 360;
  for (let index = 0; index < 5; index++) runTimers();
  assert.equal(context.markerDataCache.map, undefined, 'a disposed view never draws its pending payload');
}

{
  // FE-MAP-13: leaving home before the first render waits without a limit.
  const { context, runTimers } = createRuntime();
  const errors = [];
  let ready = 0;
  context.kakaoMapCallbacks.map = { onError: (message) => errors.push(message), onReady: () => { ready++; } };
  const container = context.document.getElementById('map');
  container.offsetWidth = 0;
  context.initKakaoMap('map', 37.5, 127);
  for (let index = 0; index < 120; index++) runTimers();
  assert.deepEqual(errors, [], 'a hidden first render is not reported as a size error');
  assert.equal(context.kakaoMapObjects.map, undefined, 'the map is not created at zero size');
  container.offsetWidth = 360;
  runTimers();
  assert.ok(context.kakaoMapObjects.map, 'the map is created once the view is visible');
  assert.equal(ready, 1, 'Flutter receives one ready event');
}

{
  // P1-18: the search zoom limit follows the mode even when it changes while
  // the map is hidden, and it is in place before a pending fit runs.
  const { context, observers, runTimers } = createRuntime();
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  let maxLevelAtFit = null;
  map.setBounds = (bounds, ...padding) => { maxLevelAtFit = map.maxLevel; map.fittedBounds = bounds; map.padding = padding; };
  map.node.offsetWidth = 0;
  observers[0].callback();
  context.setKakaoMapSearchMode('map', true);
  context.fitKakaoMapStores('map', JSON.stringify([{ lat: 37.5, lng: 127 }, { lat: 35.1, lng: 129.0 }]));
  assert.equal(map.maxLevel, 10, 'a hidden map is not manipulated');
  map.node.offsetWidth = 360;
  observers[0].callback();
  assert.equal(map.maxLevel, 14, 'returning to search results restores the search zoom limit');
  assert.equal(maxLevelAtFit, 14, 'the nationwide fit runs with the search zoom limit');
  map.setLevel(13);
  map.node.offsetWidth = 0;
  observers[0].callback();
  context.setKakaoMapSearchMode('map', false);
  map.node.offsetWidth = 360;
  runTimers();
  assert.equal(map.maxLevel, 10, 'clearing a search while hidden restores the backend-safe limit');
  assert.equal(map.level, 10, 'a zoomed-out search view comes back inside the supported span');
}

{
  // P1-19: an AI pick chosen on another screen moves the map after return.
  const { context, runTimers } = createRuntime();
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  const pans = [];
  map.panTo = (position) => { pans.push([position.lat, position.lng]); map.center = position; };
  map.node.offsetWidth = 0;
  context.setKakaoMapCenterFromSwipe('map', 35.15, 129.06);
  assert.deepEqual(pans, [], 'a hidden map does not pan');
  map.node.offsetWidth = 360;
  runTimers();
  assert.deepEqual(pans, [[35.15, 129.06]], 'the preserved pan runs once the map is visible');
  map.node.offsetWidth = 0;
  context.setKakaoMapCenterFromSwipe('map', 33.5, 126.5);
  context.fitKakaoMapStores('map', JSON.stringify([{ lat: 36.35, lng: 127.38 }]));
  map.node.offsetWidth = 360;
  runTimers();
  assert.deepEqual(pans, [[35.15, 129.06]], 'a newer viewport intent replaces the older pan');
  assert.equal(map.center.lat, 36.35);
}

{
  // Leaving right after a drag: the skipped viewport request runs on return.
  const { context, listeners, observers, runTimers } = createRuntime();
  let idleCalls = 0;
  context.kakaoMapCallbacks.map = { onIdle: () => { idleCalls++; } };
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  const map = context.kakaoMapObjects.map;
  map.getBounds = () => ({
    getSouthWest: () => ({ getLat: () => 37.4, getLng: () => 126.9 }),
    getNorthEast: () => ({ getLat: () => 37.6, getLng: () => 127.1 }),
  });
  const before = idleCalls;
  listeners.find((item) => item.type === 'idle').handler();
  map.node.offsetWidth = 0;
  observers[0].callback();
  for (let index = 0; index < 10; index++) runTimers();
  assert.equal(idleCalls, before, 'no viewport request reaches Flutter while hidden');
  map.node.offsetWidth = 360;
  observers[0].callback();
  runTimers();
  assert.equal(idleCalls, before + 1, 'the skipped viewport request runs once the map is visible');
}

{
  // FE-MAP-19: fit padding never exceeds a short map.
  const { context, runTimers } = createRuntime();
  const container = context.document.getElementById('map');
  container.offsetHeight = 300;
  container.offsetWidth = 320;
  context.initKakaoMap('map', 37.5, 127);
  runTimers();
  context.fitKakaoMapStores('map', JSON.stringify([{ lat: 37.5, lng: 127 }, { lat: 37.6, lng: 127.1 }]));
  const [top, right, bottom, left] = context.kakaoMapObjects.map.padding;
  assert.ok(top + bottom <= 300 * 0.7, 'vertical padding leaves room for the results');
  assert.ok(top < 150 && bottom < 260, 'short maps scale the padding down');
  assert.equal(right, 40);
  assert.equal(left, 40);
}

{
  // FE-MAP-11: the recommendation route map replaces its own map when the
  // route changes, and a closed view stops waiting for the SDK.
  const dartSource = readFileSync(
    new URL('../lib/features/recommendation/presentation/widgets/route_map_view_web.dart', import.meta.url),
    'utf8',
  );
  const routeScript = dartSource.match(/_eval\(\s*'''([\s\S]*?)'''/)[1];
  let nextTimerId = 1;
  const timers = new globalThis.Map();
  const container = { innerHTML: '', id: 'route' };
  const createdMaps = [];
  const context = {
    document: {
      getElementById: (id) => (id === 'route' ? container : null),
      createElement: () => ({ style: {}, innerText: '' }),
    },
    setTimeout(callback) { const id = nextTimerId++; timers.set(id, callback); return id; },
    clearTimeout(id) { timers.delete(id); },
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(routeScript, context, { filename: 'route_map_view_web.dart' });
  const runTimers = () => { const pending = [...timers.values()]; timers.clear(); pending.forEach((callback) => callback()); };
  const kakao = {
    maps: {
      load: (callback) => callback(),
      LatLng: function LatLng(lat, lng) { this.lat = lat; this.lng = lng; },
      LatLngBounds: function LatLngBounds() { this.extend = () => {}; },
      CustomOverlay: function CustomOverlay() { this.setMap = () => {}; },
      Polyline: function Polyline() { this.setMap = () => {}; },
      Map: function KakaoMap(node) {
        this.htmlWhenCreated = node.innerHTML;
        node.innerHTML = '<map>';
        this.setBounds = () => {};
        this.setCenter = () => {};
        createdMaps.push(this);
      },
    },
  };
  const route = JSON.stringify([
    { order: 1, name: 'A', latitude: 37.56, longitude: 126.97 },
    { order: 2, name: 'B', latitude: 37.57, longitude: 126.98 },
  ]);

  context.initHowMuchRouteMap('route', route, 0, 0);
  context.disposeHowMuchRouteMap('route');
  context.kakao = kakao;
  runTimers();
  assert.equal(createdMaps.length, 0, 'a closed route map never finishes a pending SDK retry');

  context.initHowMuchRouteMap('route', route, 0, 0);
  context.initHowMuchRouteMap('route', route, 37.55, 126.96);
  assert.equal(createdMaps.length, 2);
  assert.equal(createdMaps[1].htmlWhenCreated, '', 'a changed route replaces the previous map element');
  assert.equal(context.howMuchRouteMaps.route, createdMaps[1], 'only the newest map is kept');
  context.disposeHowMuchRouteMap('route');
  assert.equal(context.howMuchRouteMaps.route, undefined, 'closing the view releases its map');
  assert.equal(container.innerHTML, '');
}

console.log('web map lifecycle tests passed');

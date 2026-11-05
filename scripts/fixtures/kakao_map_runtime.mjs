import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../../web/index.html', import.meta.url), 'utf8');
const mapScript = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1])
  .find((source) => source.includes('function initKakaoMap'));
assert.ok(mapScript, 'Kakao map runtime script is present');

export function createRuntime({ withClusterer = false, native = false } = {}) {
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
  elements.set('kakao-map-container', container);

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
    this.setLevel = (level, options) => { this.level = level; this.levelOptions = options; };
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
    if (options.content?.id) elements.set(options.content.id, options.content);
    overlays.push(this);
  }
  function Marker(options) {
    this.options = options;
    this.map = null;
    this.setMap = (map) => { this.map = map; };
    this.getPosition = () => options.position;
  }
  function MarkerImage(src, size) { this.src = src; this.size = size; }
  function Size(width, height) { this.width = width; this.height = height; }
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
    addEventListener() {},
    Print: { postMessage() {} },
  };
  context.window = context;
  context.top = context;
  context.location = { origin: 'https://howmuch-zeta.vercel.app' };
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
    context.kakao.maps.MarkerImage = MarkerImage;
    context.kakao.maps.Size = Size;
  }
  vm.createContext(context);
  let source = mapScript;
  if (native) {
    const dart = readFileSync(new URL('../../lib/features/home/presentation/screens/home_map_screen.dart', import.meta.url), 'utf8');
    const policy = readFileSync(new URL('../../lib/core/security/kakao_inline_webview_policy.dart', import.meta.url), 'utf8');
    const bridge = policy.match(/String bridgeScript[\s\S]*?=>\s*'''([\s\S]*?)'''/)[1]
      .replaceAll('TOKEN_VALUE', JSON.stringify('fixture-document-capability'))
      .replaceAll('ORIGIN_VALUE', JSON.stringify(context.location.origin))
      .replaceAll('CHANNEL_VALUE', JSON.stringify('Print'));
    source = [...dart.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
      .map((match) => match[1])
      .find((script) => script.includes('function initializeMap'))
      .replaceAll('$initialLat', '37.5').replaceAll('$initialLng', '127')
      .replaceAll('$initialLevel', '3')
      .replaceAll("${_mobileWebViewPolicy.bridgeScript('Print')}", bridge)
      // Test-only introspection keeps production bridge capabilities private.
      .replace('})();', `
        window.initializeMap = initializeMap;
        window.syncStoreOverlays = syncStoreOverlays;
        Object.defineProperties(window, {
          map: { get: () => map },
          customOverlays: { get: () => customOverlays },
          markerDataCache: { get: () => markerDataCache },
          pendingMarkerPayload: { get: () => pendingMarkerPayload }
        });
      })();`);
  }
  vm.runInContext(source, context, { filename: native ? 'native-map.html' : 'web/index.html' });
  if (native) return { context, overlays, clusterers, listeners, elements };
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
    elements,
    listeners,
    runTimers() {
      const pending = [...timers.entries()];
      timers.clear();
      for (const [, callback] of pending) callback();
    },
  };
}

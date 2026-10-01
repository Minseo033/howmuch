import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

@JS('initKakaoMap')
external void _initKakaoMap(JSString viewId, JSNumber lat, JSNumber lng);

@JS('getKakaoMapBounds')
external JSString? _getKakaoMapBounds(JSString viewId);

@JS('addMobileMarkers')
external void _addMobileMarkers(JSString viewId, JSString jsonString);

@JS('highlightKakaoMapMarker')
external void _highlightKakaoMapMarker(JSString viewId, JSNumber markerIndex);

void registerWebCallbacks(
  String viewId,
  void Function() onIdle,
  void Function() onMoveStart,
  void Function(int, String) onClick,
  void Function() onMapReady,
  void Function(String) onMapError,
) {
  final callbacks = JSObject();
  callbacks.setProperty('onIdle'.toJS, onIdle.toJS);
  callbacks.setProperty('onMoveStart'.toJS, onMoveStart.toJS);
  callbacks.setProperty(
    'onMarkerClick'.toJS,
    ((JSNumber index, JSString storeId) => onClick(
      index.toDartInt,
      storeId.toDart,
    )).toJS,
  );
  callbacks.setProperty('onReady'.toJS, onMapReady.toJS);
  callbacks.setProperty(
    'onError'.toJS,
    ((JSString message) => onMapError(message.toDart)).toJS,
  );
  final registry = globalContext.getProperty<JSObject>(
    'kakaoMapCallbacks'.toJS,
  );
  registry.setProperty(viewId.toJS, callbacks);
}

@JS('setKakaoMapCenter')
external void _setKakaoMapCenter(JSString viewId, JSNumber lat, JSNumber lng);

@JS('setKakaoMapCenterFromSwipe')
external void _setKakaoMapCenterFromSwipe(
  JSString viewId,
  JSNumber lat,
  JSNumber lng,
);

@JS('setSuppressMarkerClicks')
external void _setSuppressMarkerClicks(JSString viewId, JSNumber durationMs);

@JS('updateUserLocationMarker')
external void _updateUserLocationMarker(
  JSString viewId,
  JSNumber lat,
  JSNumber lng,
);

@JS('disposeKakaoMap')
external void _disposeKakaoMap(JSString viewId);
@JS('recoverKakaoMap')
external void _recoverKakaoMap(JSString viewId);

const kakaoWebViewType = 'howmuch-kakao-map';
bool _factoryRegistered = false;

void registerKakaoWebViewFactory(String viewId) {
  if (_factoryRegistered) return;
  ui_web.platformViewRegistry.registerViewFactory(kakaoWebViewType, (
    int innerViewId, {
    Object? params,
  }) {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    final id = params is String && params.isNotEmpty
        ? params
        : 'kakao-platform-view-$innerViewId';
    div.id = id;
    div.setAttribute('aria-label', '매장 지도');
    div.style.width = '100%';
    div.style.height = '100%';
    globalContext.setProperty(id.toJS, div);
    return div;
  });
  _factoryRegistered = true;
}

@JS('fitKakaoMapStores')
external void _fitKakaoMapStores(JSString viewId, JSString coordinates);
@JS('zoomKakaoMap')
external void _zoomKakaoMap(JSString viewId, JSNumber delta);
@JS('setKakaoMapSearchMode')
external void _setKakaoMapSearchMode(JSString viewId, JSBoolean enabled);

void fitKakaoMapStoresWeb(String viewId, String coordinates) =>
    _fitKakaoMapStores(viewId.toJS, coordinates.toJS);
void zoomKakaoMapWeb(String viewId, int delta) =>
    _zoomKakaoMap(viewId.toJS, delta.toJS);
void setKakaoMapSearchModeWeb(String viewId, bool enabled) =>
    _setKakaoMapSearchMode(viewId.toJS, enabled.toJS);

void initKakaoWebMap(String viewId) {
  _initKakaoMap(viewId.toJS, 37.5665.toJS, 126.9780.toJS);
}

void disposeKakaoWebMap(String viewId) {
  _disposeKakaoMap(viewId.toJS);
}

void recoverKakaoWebMap(String viewId) => _recoverKakaoMap(viewId.toJS);

String? getKakaoMapBoundsWeb(String viewId) {
  return _getKakaoMapBounds(viewId.toJS)?.toDart;
}

void addMobileMarkersWeb(String viewId, String jsonString) {
  _addMobileMarkers(viewId.toJS, jsonString.toJS);
}

void highlightKakaoMapMarkerWeb(String viewId, int markerIndex) {
  _highlightKakaoMapMarker(viewId.toJS, markerIndex.toJS);
}

void suppressMarkerClicksWeb(String viewId, int durationMs) {
  _setSuppressMarkerClicks(viewId.toJS, durationMs.toJS);
}

void setKakaoMapCenterWeb(String viewId, double lat, double lng) {
  _setKakaoMapCenter(viewId.toJS, lat.toJS, lng.toJS);
}

void setKakaoMapCenterFromSwipeWeb(String viewId, double lat, double lng) {
  _setKakaoMapCenterFromSwipe(viewId.toJS, lat.toJS, lng.toJS);
}

void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {
  _updateUserLocationMarker(viewId.toJS, lat.toJS, lng.toJS);
}

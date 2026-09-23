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
  void Function() onIdle,
  void Function() onMoveStart,
  void Function(int) onClick,
  void Function() onMapReady,
  void Function(String) onMapError,
) {
  globalContext.setProperty('onKakaoMapIdle'.toJS, onIdle.toJS);
  globalContext.setProperty('onKakaoMapMoveStart'.toJS, onMoveStart.toJS);
  globalContext.setProperty('onKakaoMarkerClick'.toJS, onClick.toJS);
  globalContext.setProperty('onKakaoMapReady'.toJS, onMapReady.toJS);
  globalContext.setProperty(
    'onKakaoMapError'.toJS,
    ((JSString message) => onMapError(message.toDart)).toJS,
  );
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
external void _setSuppressMarkerClicks(JSNumber durationMs);

@JS('updateUserLocationMarker')
external void _updateUserLocationMarker(
  JSString viewId,
  JSNumber lat,
  JSNumber lng,
);

@JS('disposeKakaoMap')
external void _disposeKakaoMap(JSString viewId);

void registerKakaoWebViewFactory(String viewId) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int innerViewId) {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.id = viewId; // Workaround for viewId string issue
    div.style.width = '100%';
    div.style.height = '100%';
    globalContext.setProperty(viewId.toJS, div);
    return div;
  });
}

void initKakaoWebMap(String viewId) {
  _initKakaoMap(viewId.toJS, 37.5665.toJS, 126.9780.toJS);
}

void disposeKakaoWebMap(String viewId) {
  _disposeKakaoMap(viewId.toJS);
}

String? getKakaoMapBoundsWeb(String viewId) {
  return _getKakaoMapBounds(viewId.toJS)?.toDart;
}

void addMobileMarkersWeb(String viewId, String jsonString) {
  _addMobileMarkers(viewId.toJS, jsonString.toJS);
}

void highlightKakaoMapMarkerWeb(String viewId, int markerIndex) {
  _highlightKakaoMapMarker(viewId.toJS, markerIndex.toJS);
}

void suppressMarkerClicksWeb(int durationMs) {
  _setSuppressMarkerClicks(durationMs.toJS);
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

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

void registerWebCallbacks(
  void Function() onIdle,
  void Function(int) onClick,
  void Function() onMapReady,
  void Function(String) onMapError,
) {
  globalContext.setProperty('onKakaoMapIdle'.toJS, onIdle.toJS);
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

@JS('updateUserLocationMarker')
external void _updateUserLocationMarker(
  JSString viewId,
  JSNumber lat,
  JSNumber lng,
);

@JS('eval')
external void _eval(JSString code);

void _injectJsBypass() {
  _eval(
    '''
    window.kakaoLoadWaitCount = 0;
    window.kakaoMapObjects = window.kakaoMapObjects || {};
    window.initKakaoMap = function(containerId, lat, lng) {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        window.kakaoLoadWaitCount++;
        if (window.kakaoLoadWaitCount > 25) {
          if (window.onKakaoMapError) window.onKakaoMapError("카카오맵을 불러오지 못했어요.");
          return;
        }
        setTimeout(function() { window.initKakaoMap(containerId, lat, lng); }, 200);
        return;
      }
      
      var loadCheckTimer = setTimeout(function() {
        if (window.onKakaoMapError) window.onKakaoMapError("지도 인증이 지연되고 있어요.");
      }, 5000);

      kakao.maps.load(function() {
        clearTimeout(loadCheckTimer);
        var container = window[containerId];
        if (!container) {
          if (window.onKakaoMapError) window.onKakaoMapError("지도 화면을 준비하지 못했어요.");
          return;
        }
        if (container.offsetWidth === 0 || container.offsetHeight === 0) {
          if (window.onKakaoMapError) window.onKakaoMapError("지도 화면 크기가 올바르지 않아요.");
          return;
        }
        var options = { center: new kakao.maps.LatLng(lat, lng), level: 3 };
        var map = new kakao.maps.Map(container, options);
        window.kakaoMapObjects[containerId] = map;
        window.kakaoLoadWaitCount = 0;
        window.kakaoMapObjects[containerId + '_clusterer'] = new kakao.maps.MarkerClusterer({
          map: map, averageCenter: true, minLevel: 6
        });

        // 💡 맵 이벤트 리스너 추가
        var boundsTimer = null;
        kakao.maps.event.addListener(map, 'idle', function() {
          if (boundsTimer) clearTimeout(boundsTimer);
          boundsTimer = setTimeout(function() {
            if (window.onKakaoMapIdle) window.onKakaoMapIdle();
          }, 600);
        });
        
        kakao.maps.event.addListener(map, 'click', function(mouseEvent) {
          if (window.onKakaoMarkerClick) window.onKakaoMarkerClick(-1);
        });

        if (window.onKakaoMapReady) window.onKakaoMapReady(containerId);
      });
    };

    window.customOverlays = {};
    window.markerDataCache = {};

    window.onMarkerClickWeb = function(index) {
      if (window.onKakaoMarkerClick) window.onKakaoMarkerClick(index);
    }

    window.addMobileMarkers = function(containerId, markerListJson) {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        window.kakaoMarkerWaitCount = (window.kakaoMarkerWaitCount || 0) + 1;
        if (window.kakaoMarkerWaitCount > 25) {
          if (window.onKakaoMapError) window.onKakaoMapError("지도 마커를 불러오지 못했어요.");
          return;
        }
        setTimeout(function() { window.addMobileMarkers(containerId, markerListJson); }, 200);
        return;
      }
      kakao.maps.load(function() {
        var map = window.kakaoMapObjects[containerId];
        if (!map) {
          window.kakaoMarkerWaitCount = (window.kakaoMarkerWaitCount || 0) + 1;
          if (window.kakaoMarkerWaitCount > 25) {
            if (window.onKakaoMapError) window.onKakaoMapError("지도 마커를 표시하지 못했어요.");
            return;
          }
          setTimeout(function() { window.addMobileMarkers(containerId, markerListJson); }, 200);
          return;
        }
        window.kakaoMarkerWaitCount = 0;
        var markerData = JSON.parse(markerListJson);
        window.markerDataCache[containerId] = markerData;
        
        if (!window.customOverlays[containerId]) {
          window.customOverlays[containerId] = [];
        }
        var overlays = window.customOverlays[containerId];
        for (var i = 0; i < overlays.length; i++) {
          overlays[i].setMap(null);
        }
        overlays.length = 0; // 배열 비우기

        for (var i = 0; i < markerData.length; i++) {
          (function(idx) {
            var item = markerData[idx];

            var wrapper = document.createElement('div');
            wrapper.id = 'marker-wrapper-' + idx;
            wrapper.style.cssText = 'display:flex;flex-direction:column;align-items:center;transition:transform 0.2s ease;';

            var bubble = document.createElement('div');
            var bgColor = item.source === 'USER' ? '#F97316' : '#1D4ED8';
            bubble.style.cssText = [
              'cursor:pointer',
              'background:' + bgColor,
              'color:#fff',
              'border-radius:20px',
              'padding:5px 10px',
              'font-size:12px',
              'font-weight:700',
              'box-shadow:0 2px 8px rgba(0,0,0,0.25)',
              'white-space:nowrap',
              'display:flex',
              'flex-direction:column',
              'align-items:center',
              'gap:1px',
              'line-height:1.3',
              'border:1.5px solid rgba(255,255,255,0.3)',
              'transition:background 0.2s ease'
            ].join(';');

            var nameEl = document.createElement('span');
            nameEl.style.cssText = 'font-size:11px;font-weight:800;letter-spacing:-0.3px;';
            nameEl.innerText = item.title;

            var priceEl = document.createElement('span');
            priceEl.style.cssText = 'font-size:10px;font-weight:500;opacity:0.88;';
            priceEl.innerText = item.menu + '  ' + item.price;

            var tail = document.createElement('div');
            tail.style.cssText = [
              'width:0',
              'height:0',
              'border-left:5px solid transparent',
              'border-right:5px solid transparent',
              'border-top:6px solid ' + bgColor,
              'margin-top:-1px',
              'transition:border-top-color 0.2s ease'
            ].join(';');

            bubble.appendChild(nameEl);
            bubble.appendChild(priceEl);
            bubble.onclick = function() { window.onMarkerClickWeb(idx); };
            wrapper.appendChild(bubble);
            wrapper.appendChild(tail);

            var customOverlay = new kakao.maps.CustomOverlay({
                position: new kakao.maps.LatLng(item.lat, item.lng),
                content: wrapper,
                yAnchor: 1.0,
                zIndex: 3
            });
            customOverlay.setMap(map);
            overlays.push(customOverlay);
          })(i);
        }
      });
    };
  '''
        .toJS,
  );
}

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
  _injectJsBypass();
  _initKakaoMap(viewId.toJS, 37.5665.toJS, 126.9780.toJS);
}

String? getKakaoMapBoundsWeb(String viewId) {
  return _getKakaoMapBounds(viewId.toJS)?.toDart;
}

void addMobileMarkersWeb(String viewId, String jsonString) {
  _addMobileMarkers(viewId.toJS, jsonString.toJS);
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

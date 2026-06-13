import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

@JS('initKakaoMap')
external void _initKakaoMap(JSString viewId, JSNumber lat, JSNumber lng);

@JS('getKakaoMapBounds')
external JSString? _getKakaoMapBounds(JSString viewId);

@JS('addKakaoMarkers')
external void _addKakaoMarkers(JSString viewId, JSString jsonString);

@JS('setKakaoMapCenter')
external void _setKakaoMapCenter(JSString viewId, JSNumber lat, JSNumber lng);

@JS('setKakaoMapCenterFromSwipe')
external void _setKakaoMapCenterFromSwipe(JSString viewId, JSNumber lat, JSNumber lng);

@JS('updateUserLocationMarker')
external void _updateUserLocationMarker(JSString viewId, JSNumber lat, JSNumber lng);

@JS('eval')
external void _eval(JSString code);

void _injectJsBypass() {
  _eval('''
    window.kakaoLoadWaitCount = 0;
    window.initKakaoMap = function(containerId, lat, lng) {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        window.kakaoLoadWaitCount++;
        if (window.kakaoLoadWaitCount > 10) {
          alert("🚨 카카오맵 SDK 로드 지연! 네트워크 문제일 수 있습니다.");
          return;
        }
        setTimeout(function() { window.initKakaoMap(containerId, lat, lng); }, 200);
        return;
      }
      
      var loadCheckTimer = setTimeout(function() {
        alert("🚨 카카오맵 인증 실패! 카카오 디벨로퍼스에 등록되지 않은 포트(현재: " + location.port + ")를 사용 중입니다.\\n터미널에서 앱을 끄고 flutter run -d chrome --web-port 8080 명령어로 재실행해주세요!");
      }, 3000);

      kakao.maps.load(function() {
        clearTimeout(loadCheckTimer);
        var container = window[containerId];
        if (!container) {
          alert("🚨 에러: 카카오맵을 담을 HTML 컨테이너(div)를 찾을 수 없습니다!");
          return;
        }
        if (container.offsetWidth === 0 || container.offsetHeight === 0) {
          alert("🚨 에러: 카카오맵 컨테이너의 가로/세로 크기가 0입니다!");
        }
        var options = { center: new kakao.maps.LatLng(lat, lng), level: 3 };
        var map = new kakao.maps.Map(container, options);
        window.kakaoMapObjects[containerId] = map;
        window.kakaoMapObjects[containerId + '_clusterer'] = new kakao.maps.MarkerClusterer({
          map: map, averageCenter: true, minLevel: 6
        });
      });
    };

    window.addKakaoMarkers = function(containerId, markerListJson) {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        setTimeout(function() { window.addKakaoMarkers(containerId, markerListJson); }, 200);
        return;
      }
      kakao.maps.load(function() {
        var map = window.kakaoMapObjects[containerId];
        var clusterer = window.kakaoMapObjects[containerId + '_clusterer'];
        if (!map || !clusterer) {
          setTimeout(function() { window.addKakaoMarkers(containerId, markerListJson); }, 200);
          return;
        }
        var markerData = JSON.parse(markerListJson);
        var markers = markerData.map(function(item) {
          return new kakao.maps.Marker({
            position: new kakao.maps.LatLng(item.lat, item.lng),
            title: item.title
          });
        });
        clusterer.clear();
        clusterer.addMarkers(markers);
      });
    };
  '''.toJS);
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

void addKakaoMarkersWeb(String viewId, String jsonString) {
  _addKakaoMarkers(viewId.toJS, jsonString.toJS);
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

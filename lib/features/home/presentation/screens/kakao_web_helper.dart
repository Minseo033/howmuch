// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerKakaoWebViewFactory(String viewId) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = viewId.toString(); // Workaround for viewId string issue
      div.style.width = '100%';
      div.style.height = '100%';
      return div;
    },
  );
}

void initKakaoWebMap(String viewId) {
  js.context.callMethod('initKakaoMap', [viewId, 37.5665, 126.9780]);
}

String? getKakaoMapBoundsWeb(String viewId) {
  return js.context.callMethod('getKakaoMapBounds', [viewId]);
}

void addKakaoMarkersWeb(String viewId, String jsonString) {
  js.context.callMethod('addKakaoMarkers', [viewId, jsonString]);
}

void setKakaoMapCenterWeb(String viewId, double lat, double lng) {
  js.context.callMethod('setKakaoMapCenter', [viewId, lat, lng]);
}

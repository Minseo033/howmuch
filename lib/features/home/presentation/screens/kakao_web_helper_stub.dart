void registerKakaoWebViewFactory(String viewId) {}
void initKakaoWebMap(String viewId) {}
String? getKakaoMapBoundsWeb(String viewId) => null;
void addKakaoMarkersWeb(String viewId, String jsonString) {}

void setKakaoMapCenterWeb(String viewId, double lat, double lng) {}
void setKakaoMapCenterFromSwipeWeb(String viewId, double lat, double lng) {}

void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {}

// 모바일(iOS/Android)에서는 사용하지 않는 웹 전용 메서드 스텁
void registerWebCallbacks(Function searchFn, Function markerFn) {}
void addMobileMarkersWeb(String viewId, String jsonString) {}


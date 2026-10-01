const kakaoWebViewType = 'howmuch-kakao-map';
void registerKakaoWebViewFactory(String viewId) {}
void initKakaoWebMap(String viewId) {}
void disposeKakaoWebMap(String viewId) {}
void recoverKakaoWebMap(String viewId) {}
String? getKakaoMapBoundsWeb(String viewId) => null;
void registerWebCallbacks(
  String viewId,
  void Function() onIdle,
  void Function() onMoveStart,
  void Function(int, String) onClick,
  void Function() onMapReady,
  void Function(String) onMapError,
) {}
void addKakaoMarkersWeb(String viewId, String jsonString) {}
void addMobileMarkersWeb(String viewId, String jsonString) {}
void highlightKakaoMapMarkerWeb(String viewId, int markerIndex) {}
void suppressMarkerClicksWeb(String viewId, int durationMs) {}

void setKakaoMapCenterWeb(String viewId, double lat, double lng) {}
void setKakaoMapCenterFromSwipeWeb(String viewId, double lat, double lng) {}

void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {}
void fitKakaoMapStoresWeb(String viewId, String coordinates) {}
void zoomKakaoMapWeb(String viewId, int delta) {}
void setKakaoMapSearchModeWeb(String viewId, bool enabled) {}

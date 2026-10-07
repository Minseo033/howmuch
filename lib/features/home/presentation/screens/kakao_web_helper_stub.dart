const kakaoWebViewType = 'howmuch-kakao-map';
void registerKakaoWebViewFactory(String viewId) {}
void initKakaoWebMap(
  String viewId, {
  double lat = 37.5665,
  double lng = 126.9780,
  int? level,
}) {}
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
void addMobileMarkersWeb(String viewId, String jsonString) {}
void highlightKakaoMapMarkerWeb(String viewId, int markerIndex) {}
void suppressMarkerClicksWeb(String viewId, int durationMs) {}

void setKakaoMapCenterWeb(String viewId, double lat, double lng) {}
void setKakaoMapCenterFromSwipeWeb(String viewId, double lat, double lng) {}

void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {}
void fitKakaoMapStoresWeb(String viewId, String coordinates) {}
void setKakaoMapSearchModeWeb(String viewId, bool enabled) {}

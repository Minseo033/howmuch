void registerKakaoWebViewFactory(String viewId) {}
void initKakaoWebMap(String viewId) {}
void disposeKakaoWebMap(String viewId) {}
String? getKakaoMapBoundsWeb(String viewId) => null;
void registerWebCallbacks(
  void Function() onIdle,
  void Function() onMoveStart,
  void Function(int) onClick,
  void Function() onMapReady,
  void Function(String) onMapError,
) {}
void addKakaoMarkersWeb(String viewId, String jsonString) {}
void addMobileMarkersWeb(String viewId, String jsonString) {}
void highlightKakaoMapMarkerWeb(String viewId, int markerIndex) {}
void suppressMarkerClicksWeb(int durationMs) {}

void setKakaoMapCenterWeb(String viewId, double lat, double lng) {}
void setKakaoMapCenterFromSwipeWeb(String viewId, double lat, double lng) {}

void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {}

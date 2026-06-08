import re

# 1. Update kakao_web_helper.dart
with open('lib/features/home/presentation/screens/kakao_web_helper.dart', 'r') as f:
    web_helper = f.read()

if 'updateUserLocationMarkerWeb' not in web_helper:
    web_helper += """
void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {
  js.context.callMethod('updateUserLocationMarker', [viewId, lat, lng]);
}
"""
    with open('lib/features/home/presentation/screens/kakao_web_helper.dart', 'w') as f:
        f.write(web_helper)

# 2. Update kakao_web_helper_stub.dart
with open('lib/features/home/presentation/screens/kakao_web_helper_stub.dart', 'r') as f:
    stub = f.read()

if 'updateUserLocationMarkerWeb' not in stub:
    stub += """
void updateUserLocationMarkerWeb(String viewId, double lat, double lng) {}
"""
    with open('lib/features/home/presentation/screens/kakao_web_helper_stub.dart', 'w') as f:
        f.write(stub)

# 3. Update home_map_screen.dart
with open('lib/features/home/presentation/screens/home_map_screen.dart', 'r') as f:
    content = f.read()

# Add import if needed
if "import 'dart:async';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:async';")

# Add _positionStream variable
if "StreamSubscription<Position>? _positionStream;" not in content:
    content = content.replace("WebViewController? _webViewController;", "WebViewController? _webViewController;\n  StreamSubscription<Position>? _positionStream;")

# Dispose _positionStream
if "_positionStream?.cancel();" not in content:
    dispose_pattern = "void dispose() {"
    content = content.replace(dispose_pattern, "void dispose() {\n    _positionStream?.cancel();")

# Remove _MyLocationDot from Stack
content = re.sub(r"          const Positioned\(left: [0-9]+, top: [0-9]+, child: _MyLocationDot\(\)\),\n", "", content)

# Remove _MyLocationDot class
content = re.sub(r"class _MyLocationDot extends StatelessWidget \{.*?^}$", "", content, flags=re.MULTILINE | re.DOTALL)

# Add CSS for custom overlay
css_pattern = "</style>"
css_replacement = """  .my-location-dot {
          width: 16px;
          height: 16px;
          background-color: #2563EB;
          border: 3px solid #FFFFFF;
          border-radius: 50%;
          box-shadow: 0 0 10px rgba(0, 0, 0, 0.3);
        }
      </style>"""
if ".my-location-dot" not in content:
    content = content.replace(css_pattern, css_replacement)

# Add JS for updateUserLocationMarker
js_pattern = "var clusterer;"
js_replacement = "var clusterer;\n        var userLocationOverlay;"
if "var userLocationOverlay;" not in content:
    content = content.replace(js_pattern, js_replacement)

js_func_pattern = "function requestBounds() {"
js_func_replacement = """function updateUserLocationMarker(lat, lng) {
          if (!map) return;
          var position = new kakao.maps.LatLng(lat, lng);
          if (!userLocationOverlay) {
            var content = document.createElement('div');
            content.className = 'my-location-dot';
            userLocationOverlay = new kakao.maps.CustomOverlay({
              position: position,
              content: content,
              map: map
            });
          } else {
            userLocationOverlay.setPosition(position);
          }
        }

        function requestBounds() {"""
if "function updateUserLocationMarker(lat, lng)" not in content:
    content = content.replace(js_func_pattern, js_func_replacement)

# Modify _moveToCurrentLocation
dart_method_pattern = r"Position position = await Geolocator\.getCurrentPosition\(\);"
dart_method_replacement = """Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _updateLocationMarker(position.latitude, position.longitude);
      _startLocationTracking();"""
if "_startLocationTracking();" not in content:
    content = content.replace(dart_method_pattern, dart_method_replacement)

# Add _updateLocationMarker and _startLocationTracking
tracking_methods = """  void _updateLocationMarker(double lat, double lng) {
    if (kIsWeb) {
      web_helper.updateUserLocationMarkerWeb(_viewId, lat, lng);
    } else {
      _webViewController?.runJavaScript('updateUserLocationMarker(${lat}, ${lng});');
    }
  }

  void _startLocationTracking() {
    if (_positionStream != null) return;
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2, // 2미터 이상 이동 시 갱신
      ),
    ).listen((Position position) {
      _updateLocationMarker(position.latitude, position.longitude);
    });
  }

  Future<void> _searchInCurrentArea() async {"""

if "void _startLocationTracking()" not in content:
    content = content.replace("  Future<void> _searchInCurrentArea() async {", tracking_methods)


with open('lib/features/home/presentation/screens/home_map_screen.dart', 'w') as f:
    f.write(content)


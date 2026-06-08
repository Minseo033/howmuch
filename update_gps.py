import re

# 1. Update kakao_web_helper.dart
with open('lib/features/home/presentation/screens/kakao_web_helper.dart', 'r') as f:
    web_helper_content = f.read()

if 'setKakaoMapCenterWeb' not in web_helper_content:
    web_helper_content += """
void setKakaoMapCenterWeb(String viewId, double lat, double lng) {
  js.context.callMethod('setKakaoMapCenter', [viewId, lat, lng]);
}
"""
    with open('lib/features/home/presentation/screens/kakao_web_helper.dart', 'w') as f:
        f.write(web_helper_content)

# 2. Update kakao_web_helper_stub.dart
with open('lib/features/home/presentation/screens/kakao_web_helper_stub.dart', 'r') as f:
    stub_content = f.read()

if 'setKakaoMapCenterWeb' not in stub_content:
    stub_content += """
void setKakaoMapCenterWeb(String viewId, double lat, double lng) {}
"""
    with open('lib/features/home/presentation/screens/kakao_web_helper_stub.dart', 'w') as f:
        f.write(stub_content)

# 3. Update home_map_screen.dart
with open('lib/features/home/presentation/screens/home_map_screen.dart', 'r') as f:
    content = f.read()

# Add import
if "import 'package:geolocator/geolocator.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:geolocator/geolocator.dart';")

# Add JS method
if "function setMapCenter(lat, lng)" not in content:
    content = content.replace(
        "function requestBounds() {",
        """function setMapCenter(lat, lng) {
          if (map) {
            map.setCenter(new kakao.maps.LatLng(lat, lng));
          }
        }

        function requestBounds() {"""
    )

# Add Dart method
dart_method = """  Future<void> _moveToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 서비스를 활성화해주세요.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.')));
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (kIsWeb) {
        web_helper.setKakaoMapCenterWeb(_viewId, position.latitude, position.longitude);
      } else {
        _webViewController?.runJavaScript('setMapCenter(${position.latitude}, ${position.longitude});');
      }
    } catch (e) {
      debugPrint('위치 가져오기 에러: ${e}');
    }
  }

  Future<void> _searchInCurrentArea() async {"""

if "_moveToCurrentLocation()" not in content:
    content = content.replace("  Future<void> _searchInCurrentArea() async {", dart_method)

# Remove dummy markers EXCEPT the PriceMarker
# They are stacked exactly like this in the widget tree under Stack.
# We will use regex to remove them.

pattern_to_remove = r"Positioned\(\s*left: [0-9.]+,\s*top: [0-9.]+,\s*child: _StoreTapTarget\(\s*onTap: _showStore,\s*child: const _Pin[^)]+\),\s*\),\s*\),"
content = re.sub(pattern_to_remove, "", content)

# Wrap _RoundIconButton in GestureDetector
if "onTap: _moveToCurrentLocation," not in content:
    content = content.replace(
        """child: const _RoundIconButton(
                  icon: Icons.near_me_rounded,
                  color: HomeMapScreen.blue,
                ),""",
        """child: GestureDetector(
                onTap: _moveToCurrentLocation,
                child: const _RoundIconButton(
                  icon: Icons.near_me_rounded,
                  color: HomeMapScreen.blue,
                ),
              ),"""
    )

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'w') as f:
    f.write(content)


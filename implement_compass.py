import re

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'r') as f:
    content = f.read()

# 1. Add import
if "import 'package:flutter_compass/flutter_compass.dart';" not in content:
    content = content.replace("import 'package:geolocator/geolocator.dart';", "import 'package:geolocator/geolocator.dart';\nimport 'package:flutter_compass/flutter_compass.dart';")

# 2. Add _compassStream variable
if "StreamSubscription<CompassEvent>? _compassStream;" not in content:
    content = content.replace("StreamSubscription<Position>? _positionStream;", "StreamSubscription<Position>? _positionStream;\n  StreamSubscription<CompassEvent>? _compassStream;")

# 3. Cancel _compassStream in dispose
if "_compassStream?.cancel();" not in content:
    content = content.replace("_positionStream?.cancel();", "_positionStream?.cancel();\n    _compassStream?.cancel();")

# 4. Update CSS
css_old = """        .my-location-dot {
          width: 16px;
          height: 16px;
          background-color: #2563EB;
          border: 3px solid #FFFFFF;
          border-radius: 50%;
          box-shadow: 0 0 10px rgba(0, 0, 0, 0.3);
        }
      </style>"""
css_new = """        .my-location-wrapper {
          width: 40px;
          height: 40px;
          position: relative;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: transform 0.1s ease-out;
        }
        .my-location-dot {
          width: 16px;
          height: 16px;
          background-color: #2563EB;
          border: 3px solid #FFFFFF;
          border-radius: 50%;
          box-shadow: 0 0 10px rgba(0, 0, 0, 0.3);
          z-index: 2;
        }
        .my-location-direction {
          position: absolute;
          width: 0;
          height: 0;
          border-left: 8px solid transparent;
          border-right: 8px solid transparent;
          border-bottom: 20px solid rgba(37, 99, 235, 0.4);
          top: 0px;
          z-index: 1;
        }
      </style>"""
if ".my-location-wrapper" not in content:
    content = content.replace(css_old, css_new)

# 5. Update JS Functions
js_func_old = """        function updateUserLocationMarker(lat, lng) {
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
        }"""
js_func_new = """        var userHeading = 0;
        var userLocationWrapper;

        function updateUserLocationMarker(lat, lng) {
          if (!map) return;
          var position = new kakao.maps.LatLng(lat, lng);
          if (!userLocationOverlay) {
            userLocationWrapper = document.createElement('div');
            userLocationWrapper.className = 'my-location-wrapper';
            
            var dot = document.createElement('div');
            dot.className = 'my-location-dot';
            
            var direction = document.createElement('div');
            direction.className = 'my-location-direction';
            
            userLocationWrapper.appendChild(direction);
            userLocationWrapper.appendChild(dot);
            
            userLocationOverlay = new kakao.maps.CustomOverlay({
              position: position,
              content: userLocationWrapper,
              map: map
            });
          } else {
            userLocationOverlay.setPosition(position);
          }
        }

        function updateUserHeading(degree) {
          if (userLocationWrapper) {
            userHeading = degree;
            userLocationWrapper.style.transform = 'rotate(' + degree + 'deg)';
          }
        }"""
if "function updateUserHeading" not in content:
    content = content.replace(js_func_old, js_func_new)

# 6. Dart method _updateUserHeading
dart_update_heading = """  void _updateUserHeading(double heading) {
    if (kIsWeb) return; // 웹에서는 나침반 제외
    _webViewController?.runJavaScript('updateUserHeading($heading);');
  }

  void _updateLocationMarker(double lat, double lng) {"""
if "void _updateUserHeading" not in content:
    content = content.replace("  void _updateLocationMarker(double lat, double lng) {", dart_update_heading)

# 7. Start compass stream
start_tracking_old = """    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2, // 2미터 이상 이동 시 갱신
          ),
        ).listen((Position position) {
          _lastKnownPosition = position;
          _updateLocationMarker(position.latitude, position.longitude);
        });
  }"""
start_tracking_new = """    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2, // 2미터 이상 이동 시 갱신
          ),
        ).listen((Position position) {
          _lastKnownPosition = position;
          _updateLocationMarker(position.latitude, position.longitude);
        });

    if (!kIsWeb) {
      _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
        if (event.heading != null) {
          _updateUserHeading(event.heading!);
        }
      });
    }
  }"""
if "FlutterCompass.events" not in content:
    content = content.replace(start_tracking_old, start_tracking_new)

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'w') as f:
    f.write(content)


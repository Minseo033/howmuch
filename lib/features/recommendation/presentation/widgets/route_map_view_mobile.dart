import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:howmuch/core/constants/kakao_map_constants.dart';
import 'route_map_point.dart';

/// The page posts to this channel once the map is drawn or has failed.
const routeMapReadyChannel = 'RouteMapReady';

/// Hides the loading indicator even if the page never reports back.
const routeMapReadyFallback = Duration(seconds: 12);

Widget buildRouteMapView({
  required List<RouteMapPoint> points,
  double? userLatitude,
  double? userLongitude,
}) {
  return _RouteMapMobileView(
    points: points,
    userLatitude: userLatitude,
    userLongitude: userLongitude,
  );
}

/// What the map draws. An unchanged route is not reloaded on parent rebuilds.
String _routeMapContentKey(
  List<RouteMapPoint> points,
  double? userLatitude,
  double? userLongitude,
) => jsonEncode([
  for (final point in points) point.toJson(),
  userLatitude,
  userLongitude,
]);

class _RouteMapMobileView extends StatefulWidget {
  final List<RouteMapPoint> points;
  final double? userLatitude;
  final double? userLongitude;

  const _RouteMapMobileView({
    required this.points,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<_RouteMapMobileView> createState() => _RouteMapMobileViewState();
}

class _RouteMapMobileViewState extends State<_RouteMapMobileView> {
  late final WebViewController _controller;
  late String _routeKey;
  // The WebView stays blank while the map SDK and tiles load, which took a
  // few seconds on iOS. A loading indicator covers that time (QA #26).
  bool _mapReady = false;
  Timer? _readyFallback;

  @override
  void initState() {
    super.initState();
    _routeKey = _routeMapContentKey(
      widget.points,
      widget.userLatitude,
      widget.userLongitude,
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        routeMapReadyChannel,
        onMessageReceived: (_) => _markMapReady(),
      )
      ..loadHtmlString(_html, baseUrl: kakaoMapAuthorizedOrigin);
    _startReadyFallback();
  }

  @override
  void didUpdateWidget(covariant _RouteMapMobileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent rebuilds pass new lists with the same route. Reload the page only
    // when the stops or the start point actually change.
    final routeKey = _routeMapContentKey(
      widget.points,
      widget.userLatitude,
      widget.userLongitude,
    );
    if (routeKey == _routeKey) return;
    _routeKey = routeKey;
    _mapReady = false;
    _controller.loadHtmlString(_html, baseUrl: kakaoMapAuthorizedOrigin);
    _startReadyFallback();
  }

  @override
  void dispose() {
    _readyFallback?.cancel();
    super.dispose();
  }

  void _startReadyFallback() {
    _readyFallback?.cancel();
    _readyFallback = Timer(routeMapReadyFallback, _markMapReady);
  }

  void _markMapReady() {
    _readyFallback?.cancel();
    if (!mounted || _mapReady) return;
    setState(() => _mapReady = true);
  }

  String get _html {
    final pointsJson = jsonEncode(
      widget.points.map((point) => point.toJson()).toList(),
    ).replaceAll('</', '<\\/');
    final userLat = widget.userLatitude ?? 0;
    final userLng = widget.userLongitude ?? 0;

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>
    html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
  </style>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$kakaoMapJavaScriptKey&libraries=services"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    var routePoints = $pointsJson;
    var userLat = $userLat;
    var userLng = $userLng;

    var initAttempts = 0;
    var readySent = false;
    function notifyReady() {
      if (readySent) return;
      readySent = true;
      try { $routeMapReadyChannel.postMessage('ready'); } catch (error) {}
    }
    function showMapError(message) {
      document.getElementById('map').innerHTML = '<div style="height:100%;display:flex;align-items:center;justify-content:center;padding:20px;box-sizing:border-box;color:#475569;font:12px sans-serif;text-align:center;">' + message + '</div>';
      notifyReady();
    }
    function initRouteMap() {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        initAttempts += 1;
        if (initAttempts >= 25) {
          showMapError('지도를 불러오지 못했어요. 네트워크와 지도 설정을 확인해주세요.');
          return;
        }
        setTimeout(initRouteMap, 200);
        return;
      }
      try {
      var first = routePoints.length > 0 ? routePoints[0] : {latitude: userLat, longitude: userLng};
      var map = new kakao.maps.Map(document.getElementById('map'), {
        center: new kakao.maps.LatLng(first.latitude, first.longitude),
        level: 5
      });
      kakao.maps.event.addListener(map, 'tilesloaded', notifyReady);
      // Some tiles may never report back; the route is drawn by then.
      setTimeout(notifyReady, 4000);
      var bounds = new kakao.maps.LatLngBounds();
      var linePath = [];

      routePoints.forEach(function(point) {
        var position = new kakao.maps.LatLng(point.latitude, point.longitude);
        bounds.extend(position);
        linePath.push(position);
        var label = document.createElement('div');
        label.style.cssText = 'display:flex;align-items:center;justify-content:center;width:28px;height:28px;box-sizing:border-box;background:#2563EB;color:#ffffff;border:2px solid #ffffff;border-radius:50%;font-size:12px;font-weight:800;box-shadow:0 2px 8px rgba(31,52,45,.18);';
        label.innerText = point.order;
        new kakao.maps.CustomOverlay({position: position, content: label, yAnchor: 0.5, zIndex: 5}).setMap(map);
      });

      if (userLat !== 0 || userLng !== 0) {
        var userPosition = new kakao.maps.LatLng(userLat, userLng);
        bounds.extend(userPosition);
        var userLabel = document.createElement('div');
        userLabel.style.cssText = 'width:20px;height:20px;box-sizing:border-box;background:#0F172A;border:4px solid #fff;border-radius:50%;box-shadow:0 2px 8px rgba(15,23,42,.25);';
        userLabel.innerText = '';
        new kakao.maps.CustomOverlay({position: userPosition, content: userLabel, yAnchor: 0.5, zIndex: 4}).setMap(map);
      }

      if (linePath.length > 1) {
        new kakao.maps.Polyline({
          path: linePath,
          strokeWeight: 5,
          strokeColor: '#2563EB',
          strokeOpacity: 0.82,
          strokeStyle: 'solid'
        }).setMap(map);
      }

      if (routePoints.length > 1 || userLat !== 0 || userLng !== 0) {
        map.setBounds(bounds, 28, 28, 28, 28);
      }
      } catch (error) {
        showMapError('지도 데이터를 표시하지 못했어요. 잠시 후 다시 시도해주세요.');
      }
    }

    window.addEventListener('load', initRouteMap);
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (!_mapReady)
            const IgnorePointer(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                  semanticsLabel: '지도를 불러오는 중',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

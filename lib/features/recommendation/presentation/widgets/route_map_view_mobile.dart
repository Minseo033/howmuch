import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'route_map_point.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_html, baseUrl: 'http://localhost');
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
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=949e657c37f55074dbb2a14ceb273e2b&libraries=services"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    var routePoints = $pointsJson;
    var userLat = $userLat;
    var userLng = $userLng;

    function initRouteMap() {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        setTimeout(initRouteMap, 200);
        return;
      }

      var first = routePoints.length > 0 ? routePoints[0] : {latitude: 37.5665, longitude: 126.9780};
      var map = new kakao.maps.Map(document.getElementById('map'), {
        center: new kakao.maps.LatLng(first.latitude, first.longitude),
        level: 5
      });
      var bounds = new kakao.maps.LatLngBounds();
      var linePath = [];

      routePoints.forEach(function(point) {
        var position = new kakao.maps.LatLng(point.latitude, point.longitude);
        bounds.extend(position);
        linePath.push(position);
        new kakao.maps.Marker({position: position, map: map});

        var label = document.createElement('div');
        label.style.cssText = 'background:#2563EB;color:#fff;border:2px solid #fff;border-radius:999px;padding:5px 9px;font-size:11px;font-weight:700;white-space:nowrap;box-shadow:0 2px 8px rgba(15,23,42,.24);';
        label.innerText = point.order + ' ' + point.name;
        new kakao.maps.CustomOverlay({position: position, content: label, yAnchor: 2.2, zIndex: 5}).setMap(map);
      });

      if (userLat !== 0 || userLng !== 0) {
        var userPosition = new kakao.maps.LatLng(userLat, userLng);
        bounds.extend(userPosition);
        new kakao.maps.Marker({position: userPosition, map: map});
        var userLabel = document.createElement('div');
        userLabel.style.cssText = 'background:#0F172A;color:#fff;border:2px solid #fff;border-radius:999px;padding:4px 8px;font-size:10px;font-weight:700;white-space:nowrap;box-shadow:0 2px 8px rgba(15,23,42,.2);';
        userLabel.innerText = '현재 위치';
        new kakao.maps.CustomOverlay({position: userPosition, content: userLabel, yAnchor: 2.1, zIndex: 4}).setMap(map);
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
      borderRadius: BorderRadius.circular(16),
      child: WebViewWidget(controller: _controller),
    );
  }
}

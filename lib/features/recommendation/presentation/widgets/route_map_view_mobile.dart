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

  @override
  void didUpdateWidget(covariant _RouteMapMobileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.loadHtmlString(_html, baseUrl: 'http://localhost');
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

    var initAttempts = 0;
    function showMapError(message) {
      document.getElementById('map').innerHTML = '<div style="height:100%;display:flex;align-items:center;justify-content:center;padding:20px;box-sizing:border-box;color:#475569;font:12px sans-serif;text-align:center;">' + message + '</div>';
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
        var label = document.createElement('div');
        label.style.cssText = 'display:flex;align-items:center;justify-content:center;width:28px;height:28px;box-sizing:border-box;background:#2563EB;color:#fff;border:2px solid #fff;border-radius:50%;font-size:12px;font-weight:800;box-shadow:0 2px 8px rgba(15,23,42,.24);';
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
      borderRadius: BorderRadius.circular(16),
      child: WebViewWidget(controller: _controller),
    );
  }
}

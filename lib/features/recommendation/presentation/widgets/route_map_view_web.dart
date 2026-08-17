import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'route_map_point.dart';

@JS('eval')
external void _eval(JSString code);

@JS('initHowMuchRouteMap')
external void _initHowMuchRouteMap(
  JSString viewId,
  JSString pointsJson,
  JSNumber userLatitude,
  JSNumber userLongitude,
);

bool _routeMapJsInjected = false;
final Set<String> _registeredRouteMapViews = <String>{};

Widget buildRouteMapView({
  required List<RouteMapPoint> points,
  double? userLatitude,
  double? userLongitude,
}) {
  return _RouteMapWebView(
    points: points,
    userLatitude: userLatitude,
    userLongitude: userLongitude,
  );
}

class _RouteMapWebView extends StatefulWidget {
  final List<RouteMapPoint> points;
  final double? userLatitude;
  final double? userLongitude;

  const _RouteMapWebView({
    required this.points,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<_RouteMapWebView> createState() => _RouteMapWebViewState();
}

class _RouteMapWebViewState extends State<_RouteMapWebView> {
  late final String _viewId =
      'howmuch-route-map-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _injectRouteMapJs();
    _registerViewFactory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMap());
  }

  void _registerViewFactory() {
    if (!_registeredRouteMapViews.add(_viewId)) return;
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = _viewId;
      div.style.width = '100%';
      div.style.height = '100%';
      div.style.borderRadius = '16px';
      div.style.overflow = 'hidden';
      return div;
    });
  }

  void _initMap() {
    if (!mounted || widget.points.isEmpty) return;
    final json = jsonEncode(
      widget.points.map((point) => point.toJson()).toList(),
    );
    _initHowMuchRouteMap(
      _viewId.toJS,
      json.toJS,
      (widget.userLatitude ?? 0).toJS,
      (widget.userLongitude ?? 0).toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

void _injectRouteMapJs() {
  if (_routeMapJsInjected) return;
  _routeMapJsInjected = true;
  _eval(
    '''
    window.howMuchRouteMaps = window.howMuchRouteMaps || {};
    window.initHowMuchRouteMap = function(viewId, pointsJson, userLat, userLng) {
      if (typeof kakao === 'undefined' || !kakao.maps) {
        setTimeout(function() {
          window.initHowMuchRouteMap(viewId, pointsJson, userLat, userLng);
        }, 200);
        return;
      }

      kakao.maps.load(function() {
        var container = document.getElementById(viewId);
        if (!container) {
          setTimeout(function() {
            window.initHowMuchRouteMap(viewId, pointsJson, userLat, userLng);
          }, 200);
          return;
        }

        var points = JSON.parse(pointsJson);
        var first = points.length > 0 ? points[0] : {latitude: 37.5665, longitude: 126.9780};
        var map = new kakao.maps.Map(container, {
          center: new kakao.maps.LatLng(first.latitude, first.longitude),
          level: 5
        });
        window.howMuchRouteMaps[viewId] = map;

        var bounds = new kakao.maps.LatLngBounds();
        var linePath = [];
        points.forEach(function(point) {
          var position = new kakao.maps.LatLng(point.latitude, point.longitude);
          bounds.extend(position);
          linePath.push(position);

          var marker = new kakao.maps.Marker({position: position, map: map});
          var label = document.createElement('div');
          label.style.cssText = 'background:#2563EB;color:#fff;border:2px solid #fff;border-radius:999px;padding:5px 9px;font-size:11px;font-weight:700;white-space:nowrap;box-shadow:0 2px 8px rgba(15,23,42,.24);';
          label.innerText = point.order + ' ' + point.name;
          var overlay = new kakao.maps.CustomOverlay({
            position: position,
            content: label,
            yAnchor: 2.2,
            zIndex: 5
          });
          overlay.setMap(map);
        });

        if (userLat !== 0 || userLng !== 0) {
          var userPosition = new kakao.maps.LatLng(userLat, userLng);
          bounds.extend(userPosition);
          var userMarker = new kakao.maps.Marker({position: userPosition, map: map});
          var userLabel = document.createElement('div');
          userLabel.style.cssText = 'background:#0F172A;color:#fff;border:2px solid #fff;border-radius:999px;padding:4px 8px;font-size:10px;font-weight:700;white-space:nowrap;box-shadow:0 2px 8px rgba(15,23,42,.2);';
          userLabel.innerText = '현재 위치';
          var userOverlay = new kakao.maps.CustomOverlay({
            position: userPosition,
            content: userLabel,
            yAnchor: 2.1,
            zIndex: 4
          });
          userOverlay.setMap(map);
        }

        if (linePath.length > 1) {
          var polyline = new kakao.maps.Polyline({
            path: linePath,
            strokeWeight: 5,
            strokeColor: '#2563EB',
            strokeOpacity: 0.82,
            strokeStyle: 'solid'
          });
          polyline.setMap(map);
        }

        if (points.length > 1 || userLat !== 0 || userLng !== 0) {
          map.setBounds(bounds, 28, 28, 28, 28);
        } else if (points.length === 1) {
          map.setCenter(new kakao.maps.LatLng(points[0].latitude, points[0].longitude));
        }
      });
    };
  '''
        .toJS,
  );
}

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

@JS('disposeHowMuchRouteMap')
external void _disposeHowMuchRouteMap(JSString viewId);

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

/// What the map draws. An unchanged route is not rebuilt on parent rebuilds.
String _routeMapContentKey(
  List<RouteMapPoint> points,
  double? userLatitude,
  double? userLongitude,
) => jsonEncode([
  for (final point in points) point.toJson(),
  userLatitude,
  userLongitude,
]);

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
  late String _routeKey;

  @override
  void initState() {
    super.initState();
    _routeKey = _routeMapContentKey(
      widget.points,
      widget.userLatitude,
      widget.userLongitude,
    );
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
    if (!mounted) return;
    if (widget.points.isEmpty) {
      _disposeHowMuchRouteMap(_viewId.toJS);
      return;
    }
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
  void didUpdateWidget(covariant _RouteMapWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent rebuilds pass new lists with the same route. Creating another
    // Kakao map for them would stack maps in the same element.
    final routeKey = _routeMapContentKey(
      widget.points,
      widget.userLatitude,
      widget.userLongitude,
    );
    if (routeKey == _routeKey) return;
    _routeKey = routeKey;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMap());
  }

  @override
  void dispose() {
    // Drop the map and stop pending SDK retries for this view.
    _disposeHowMuchRouteMap(_viewId.toJS);
    super.dispose();
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
    window.howMuchRouteMapGenerations = window.howMuchRouteMapGenerations || {};
    window.disposeHowMuchRouteMap = function(viewId) {
      window.howMuchRouteMapGenerations[viewId] = (window.howMuchRouteMapGenerations[viewId] || 0) + 1;
      delete window.howMuchRouteMaps[viewId];
      var target = document.getElementById(viewId);
      if (target) target.innerHTML = '';
    };
    window.initHowMuchRouteMap = function(viewId, pointsJson, userLat, userLng, attempt, generation) {
      attempt = attempt || 0;
      if (generation === undefined) {
        generation = (window.howMuchRouteMapGenerations[viewId] || 0) + 1;
        window.howMuchRouteMapGenerations[viewId] = generation;
      }
      // A newer route or a disposed view stops older retries.
      function isCurrent() {
        return window.howMuchRouteMapGenerations[viewId] === generation;
      }
      function retry() {
        setTimeout(function() {
          if (isCurrent()) window.initHowMuchRouteMap(viewId, pointsJson, userLat, userLng, attempt + 1, generation);
        }, 200);
      }
      function showMapError(message) {
        var target = document.getElementById(viewId);
        if (!target) return;
        target.innerHTML = '<div style="height:100%;display:flex;align-items:center;justify-content:center;padding:20px;box-sizing:border-box;color:#475569;font:12px sans-serif;text-align:center;">' + message + '</div>';
      }
      if (typeof kakao === 'undefined' || !kakao.maps) {
        if (attempt >= 25) {
          showMapError('지도를 불러오지 못했어요. 네트워크와 지도 설정을 확인해주세요.');
          return;
        }
        retry();
        return;
      }

      kakao.maps.load(function() {
        if (!isCurrent()) return;
        var container = document.getElementById(viewId);
        if (!container) {
          if (attempt >= 25) return;
          retry();
          return;
        }
        try {
        // A changed route replaces the previous map instead of adding a
        // second one to the same element.
        delete window.howMuchRouteMaps[viewId];
        container.innerHTML = '';
        var points = JSON.parse(pointsJson);
        var first = points.length > 0 ? points[0] : {latitude: userLat, longitude: userLng};
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

          var label = document.createElement('div');
          label.style.cssText = 'display:flex;align-items:center;justify-content:center;width:28px;height:28px;box-sizing:border-box;background:#2563EB;color:#ffffff;border:2px solid #ffffff;border-radius:50%;font-size:12px;font-weight:800;box-shadow:0 2px 8px rgba(31,52,45,.18);';
          label.innerText = point.order;
          var overlay = new kakao.maps.CustomOverlay({
            position: position,
            content: label,
            yAnchor: 0.5,
            zIndex: 5
          });
          overlay.setMap(map);
        });

        if (userLat !== 0 || userLng !== 0) {
          var userPosition = new kakao.maps.LatLng(userLat, userLng);
          bounds.extend(userPosition);
          var userLabel = document.createElement('div');
          userLabel.style.cssText = 'width:20px;height:20px;box-sizing:border-box;background:#0F172A;border:4px solid #fff;border-radius:50%;box-shadow:0 2px 8px rgba(15,23,42,.25);';
          userLabel.innerText = '';
          var userOverlay = new kakao.maps.CustomOverlay({
            position: userPosition,
            content: userLabel,
            yAnchor: 0.5,
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
        } catch (error) {
          showMapError('지도 데이터를 표시하지 못했어요. 잠시 후 다시 시도해주세요.');
        }
      });
    };
  '''
        .toJS,
  );
}

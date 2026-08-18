import 'package:flutter/material.dart';
import 'route_map_point.dart';
import 'route_map_view_mobile.dart'
    if (dart.library.js) 'route_map_view_web.dart'
    as platform;

class RouteMapView extends StatelessWidget {
  final List<RouteMapPoint> points;
  final double? userLatitude;
  final double? userLongitude;

  const RouteMapView({
    super.key,
    required this.points,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  Widget build(BuildContext context) {
    return platform.buildRouteMapView(
      points: points,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    );
  }
}

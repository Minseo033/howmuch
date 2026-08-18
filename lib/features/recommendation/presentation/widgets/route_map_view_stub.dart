import 'package:flutter/material.dart';
import 'route_map_point.dart';

Widget buildRouteMapView({
  required List<RouteMapPoint> points,
  double? userLatitude,
  double? userLongitude,
}) {
  return const Center(child: Text('지도를 불러오는 중이에요.'));
}

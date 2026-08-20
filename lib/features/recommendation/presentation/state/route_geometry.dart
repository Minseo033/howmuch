import 'dart:math' as math;

typedef RouteCoordinate = ({double lat, double lng});

RouteCoordinate? parseRouteCoordinate(Object? raw) {
  if (raw is! Map) return null;
  final lat = _number(raw['latitude']);
  final lng = _number(raw['longitude']);
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
    return null;
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  if (lat == 0 && lng == 0) return null;
  return (lat: lat, lng: lng);
}

double routeDistanceMeters(RouteCoordinate from, RouteCoordinate to) {
  const earthRadiusMeters = 6371000.0;
  final latDelta = _radians(to.lat - from.lat);
  final lngDelta = _radians(to.lng - from.lng);
  final a =
      math.pow(math.sin(latDelta / 2), 2) +
      math.cos(_radians(from.lat)) *
          math.cos(_radians(to.lat)) *
          math.pow(math.sin(lngDelta / 2), 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double _radians(double degrees) => degrees * math.pi / 180;

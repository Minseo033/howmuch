import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/route_geometry.dart';

void main() {
  test('accepts numeric and numeric-string route coordinates', () {
    expect(
      parseRouteCoordinate({'latitude': '37.5665', 'longitude': 126.978}),
      (lat: 37.5665, lng: 126.978),
    );
  });

  test(
    'rejects missing, non-finite, out-of-range, and zero sentinel coordinates',
    () {
      expect(
        parseRouteCoordinate({'latitude': null, 'longitude': 127}),
        isNull,
      );
      expect(
        parseRouteCoordinate({'latitude': double.nan, 'longitude': 127}),
        isNull,
      );
      expect(parseRouteCoordinate({'latitude': 91, 'longitude': 127}), isNull);
      expect(parseRouteCoordinate({'latitude': 0, 'longitude': 0}), isNull);
    },
  );

  test('calculates route legs in meters', () {
    final distance = routeDistanceMeters(
      (lat: 37.5665, lng: 126.9780),
      (lat: 37.5674, lng: 126.9780),
    );

    expect(distance, closeTo(100, 2));
  });
}

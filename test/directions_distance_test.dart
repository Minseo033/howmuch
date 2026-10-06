import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:geolocator/geolocator.dart';

Position _position(double latitude, DateTime timestamp) => Position(
  latitude: latitude,
  longitude: 126.9780,
  timestamp: timestamp,
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _CachedThenCurrentGeolocator extends GeolocatorPlatform {
  _CachedThenCurrentGeolocator({required this.lastKnown, required this.current});

  final Position lastKnown;
  final Position current;
  int currentRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentRequests++;
    return current;
  }
}

void main() {
  group('directions start position freshness', () {
    late GeolocatorPlatform original;
    setUp(() => original = GeolocatorPlatform.instance);
    tearDown(() {
      GeolocatorPlatform.instance = original;
      HomeMapScreen.globalUserPosition = null;
    });

    test('only a fix from the last two minutes counts as fresh', () {
      final now = DateTime(2026, 10, 6, 12);
      expect(
        isFreshLastKnownPosition(
          _position(37.5, now.subtract(const Duration(seconds: 90))),
          now,
        ),
        isTrue,
      );
      expect(
        isFreshLastKnownPosition(
          _position(37.5, now.subtract(const Duration(minutes: 10))),
          now,
        ),
        isFalse,
      );
      expect(isFreshLastKnownPosition(null, now), isFalse);
    });

    for (final stale in [true, false]) {
      testWidgets(
        stale
            ? 'a stale cached fix is replaced by a current one'
            : 'a recent cached fix is used without waiting for GPS',
        (tester) async {
          final now = DateTime.now();
          final geolocator = _CachedThenCurrentGeolocator(
            // About 3.7km from the store when stale, about 56m when recent.
            lastKnown: stale
                ? _position(37.6000, now.subtract(const Duration(minutes: 30)))
                : _position(37.5665, now.subtract(const Duration(seconds: 30))),
            current: _position(37.5665, now),
          );
          GeolocatorPlatform.instance = geolocator;

          await tester.pumpWidget(
            const MaterialApp(
              home: DirectionsExternalAppScreen(
                storeName: '착한식당',
                address: '서울시 중구 세종대로 110',
                distanceLabel: '거리 정보 확인 중',
                latitude: 37.5670,
                longitude: 126.9780,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('56m'), findsOneWidget);
          expect(geolocator.currentRequests, stale ? 1 : 0);
        },
      );
    }
  });

  group('DirectionsExternalAppScreen distance resolution', () {
    tearDown(() {
      HomeMapScreen.globalUserPosition = null;
    });

    testWidgets(
      'calculates real distance in meters when start and store coordinates are close',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DirectionsExternalAppScreen(
              storeName: '착한식당',
              address: '서울시 중구 세종대로 110',
              distanceLabel: '거리 정보 확인 중', // Old uncomputed label
              latitude: 37.5670,
              longitude: 126.9780,
              startLatitude: 37.5665,
              startLongitude: 126.9780, // ~55m away
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must calculate real distance (~56m) and NEVER show '거리 정보 확인 중'
        expect(find.text('거리 정보 확인 중'), findsNothing);
        expect(find.text('56m'), findsOneWidget);
      },
    );

    testWidgets(
      'calculates real distance in km when store is over 1000m away',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DirectionsExternalAppScreen(
              storeName: '원거리 착한식당',
              address: '서울시 종로구 혜화동',
              distanceLabel: '거리 정보 확인 중',
              latitude: 37.5850,
              longitude: 126.9780,
              startLatitude: 37.5665,
              startLongitude: 126.9780, // ~2.06km away
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('거리 정보 확인 중'), findsNothing);
        expect(find.text('2.1km'), findsOneWidget);
      },
    );

    testWidgets('uses global user position when startLatitude is omitted', (
      tester,
    ) async {
      HomeMapScreen.globalUserPosition = Position(
        latitude: 37.5665,
        longitude: 126.9780,
        timestamp: DateTime(2026, 9, 14),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DirectionsExternalAppScreen(
            storeName: '착한식당',
            address: '서울시 중구 세종대로 110',
            distanceLabel: '거리 정보 확인 중',
            latitude: 37.5670,
            longitude: 126.9780,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('거리 정보 확인 중'), findsNothing);
      expect(find.text('56m'), findsOneWidget);
    });

    testWidgets('화면 진입 시 현재 위치를 출발지로 초기화한다', (tester) async {
      final position = Position(
        latitude: 37.5665,
        longitude: 126.9780,
        timestamp: DateTime(2026, 9, 20),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DirectionsExternalAppScreen(
            storeName: '착한식당',
            address: '서울시 중구 세종대로 110',
            distanceLabel: '거리 정보 확인 중',
            latitude: 37.5670,
            longitude: 126.9780,
            positionLookup: () async => position,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('출발지 · 현재 위치'), findsOneWidget);
      expect(find.text('56m'), findsOneWidget);
      expect(HomeMapScreen.globalUserPosition?.latitude, position.latitude);
    });

    testWidgets(
      'preserves already computed distance label if coordinates are missing',
      (tester) async {
        HomeMapScreen.globalUserPosition = null;

        await tester.pumpWidget(
          const MaterialApp(
            home: DirectionsExternalAppScreen(
              storeName: '착한식당',
              address: '서울시 중구 세종대로 110',
              distanceLabel: '320m',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('320m'), findsOneWidget);
        expect(find.text('거리 정보 확인 중'), findsNothing);
      },
    );

    testWidgets(
      'safely falls back to 거리 정보 없음 when coordinates are unavailable and label was 확인 중',
      (tester) async {
        HomeMapScreen.globalUserPosition = null;

        await tester.pumpWidget(
          const MaterialApp(
            home: DirectionsExternalAppScreen(
              storeName: '착한식당',
              address: '서울시 중구 세종대로 110',
              distanceLabel:
                  '거리 정보 확인 중', // uncomputed label passed without coords
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('거리 정보 확인 중'), findsNothing);
        expect(find.text('거리 정보 없음'), findsOneWidget);
      },
    );

    testWidgets('renders without overflow on 320x568 and 568x320 landscape', (
      tester,
    ) async {
      // 320x568
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: DirectionsExternalAppScreen(
            storeName: '착한식당',
            address: '서울시 중구 세종대로 110',
            distanceLabel: '56m',
            latitude: 37.5670,
            longitude: 126.9780,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 568x320 landscape
      tester.view.physicalSize = const Size(568, 320);
      await tester.pumpWidget(
        const MaterialApp(
          home: DirectionsExternalAppScreen(
            storeName: '착한식당',
            address: '서울시 중구 세종대로 110',
            distanceLabel: '56m',
            latitude: 37.5670,
            longitude: 126.9780,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

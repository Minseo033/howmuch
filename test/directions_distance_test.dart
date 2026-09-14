import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:geolocator/geolocator.dart';

void main() {
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

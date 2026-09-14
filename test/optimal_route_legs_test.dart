import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/optimal_route_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  setUp(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
    HomeMapScreen.globalUserPosition = Position(
      longitude: 126.9780,
      latitude: 37.5660, // ~55m south of store 1
      timestamp: DateTime(2026, 9, 14),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  });

  tearDown(() {
    HomeMapScreen.globalUserPosition = null;
  });

  testWidgets(
    'verifies leg connections align with inter-store legs and labels far legs as transit',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Store 1: (37.5665, 126.9780)
      // Store 2: (37.5680, 126.9780) -> ~166m from Store 1 (~2 min walk)
      // Store 3: (37.5695, 126.9780) -> ~166m from Store 2 (~2 min walk)
      // Store 4: (37.5900, 126.9780) -> ~2.27km from Store 3 (> 1500m -> transit/vehicle)
      final service = _FakeRouteService(
        route: {
          'route': '종로 일대 가성비 맛집 탐방 코스',
          'picks': [
            {
              'storeName': '1호점 국수',
              'menu1': '잔치국수',
              'price1': '4,000원',
              'latitude': 37.5665,
              'longitude': 126.9780,
              'distanceMeters': 55,
            },
            {
              'storeName': '2호점 김밥',
              'menu1': '야채김밥',
              'price1': '3,000원',
              'latitude': 37.5680,
              'longitude': 126.9780,
              'distanceMeters': 222,
            },
            {
              'storeName': '3호점 카페',
              'menu1': '아메리카노',
              'price1': '2,000원',
              'latitude': 37.5695,
              'longitude': 126.9780,
              'distanceMeters': 389,
            },
            {
              'storeName': '4호점 디저트',
              'menu1': '붕어빵',
              'price1': '2,500원',
              'latitude': 37.5900,
              'longitude': 126.9780,
              'distanceMeters': 2668,
            },
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [todaysPickServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: OptimalRouteScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // All 4 stores rendered in order
      expect(find.byKey(const ValueKey('route-step-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-step-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-step-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-step-4')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('route-step-1')),
          matching: find.text('1호점 국수'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('route-step-4')),
          matching: find.text('4호점 디저트'),
        ),
        findsOneWidget,
      );

      // Inter-store legs 1->2 (~166m) and 2->3 (~166m) must be labeled as walking (~2 min)
      expect(find.text('도보 약 2분'), findsNWidgets(2));

      // Far leg 3->4 (~2.3km) must NOT be labeled as walking (e.g. not "도보 약 28분")
      expect(
        find.textContaining('도보 약 2'),
        findsNWidgets(2),
      ); // only the two 2-minute walks
      expect(find.text('대중교통/차량 이동 (2.3km)'), findsOneWidget);

      // Total distance is aggregated safely
      expect(find.text('총 거리'), findsOneWidget);
      expect(find.text('거리 정보 없음'), findsNothing);
    },
  );

  testWidgets(
    'regression for 22.4km far leg: must show transit/vehicle label and never 도보 약 3분',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Store 1: (37.5665, 126.9780)
      // Store 2: (37.5685, 126.9780) -> ~222m from Store 1 (~3 min walk)
      // Store 3: (37.5705, 126.9780) -> ~222m from Store 2 (~3 min walk)
      // Store 4: (37.7680, 126.9780) -> ~22km from Store 3
      final service = _FakeRouteService(
        route: {
          'route': '평택 및 광역 투어',
          'picks': [
            {
              'storeName': '1호점 한식',
              'menu1': '된장찌개',
              'price1': '5,000원',
              'latitude': 37.5665,
              'longitude': 126.9780,
              'distanceMeters': 55,
            },
            {
              'storeName': '2호점 분식',
              'menu1': '떡볶이',
              'price1': '3,500원',
              'latitude': 37.5685,
              'longitude': 126.9780,
              'distanceMeters': 277,
            },
            {
              'storeName': '3호점 베이커리',
              'menu1': '소금빵',
              'price1': '2,500원',
              'latitude': 37.5705,
              'longitude': 126.9780,
              'distanceMeters': 500,
            },
            {
              'storeName': '4호점 평택 안중점',
              'menu1': '갈비탕',
              'price1': '10,000원',
              'latitude': 37.7680,
              'longitude': 126.9780,
              'distanceMeters': 22400,
            },
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [todaysPickServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: OptimalRouteScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Between Store 1 and Store 2 (~222m): 도보 약 3분
      // Between Store 2 and Store 3 (~222m): 도보 약 3분
      expect(find.text('도보 약 3분'), findsNWidgets(2));

      // Before the fix, the leg between Store 3 and Store 4 mistakenly used leg index 1 or 2 (도보 약 3분).
      // With the fix, it MUST show 대중교통/차량 이동 (22.0km), NEVER a third "도보 약 3분"!
      expect(find.text('도보 약 3분'), findsNWidgets(2)); // exactly 2, NOT 3
      expect(find.text('대중교통/차량 이동 (22.0km)'), findsOneWidget);
    },
  );

  testWidgets('renders without overflow on 320x568 and 568x320 landscape', (
    tester,
  ) async {
    final service = _FakeRouteService(
      route: {
        'route': '가성비 코스',
        'picks': [
          {
            'storeName': '착한 밥상',
            'menu1': '백반 정식',
            'price1': '5,000원',
            'latitude': 37.5665,
            'longitude': 126.9780,
          },
          {
            'storeName': '달콤 디저트',
            'menu1': '와플',
            'price1': '3,000원',
            'latitude': 37.5680,
            'longitude': 126.9780,
          },
        ],
      },
    );

    // 320x568
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [todaysPickServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: OptimalRouteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 568x320 landscape
    tester.view.physicalSize = const Size(568, 320);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [todaysPickServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: OptimalRouteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _FakeRouteService extends TodaysPickService {
  _FakeRouteService({required this.route});
  final Map<String, dynamic> route;

  @override
  Future<Map<String, dynamic>> getRoute({double? lat, double? lng}) async =>
      route;
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

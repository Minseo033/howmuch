import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
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

      // Each leg button carries the time of its own leg (QA #24): the first
      // leg starts at the current location (~55m), the others at the
      // previous stop (~166m, ~166m, ~2.3km).
      expect(_legLabel(tester, 1), '1구간: 현재 위치 → 1호점 국수 · 도보 약 1분');
      expect(_legLabel(tester, 2), '2구간: 1호점 국수 → 2호점 김밥 · 도보 약 2분');
      expect(_legLabel(tester, 3), '3구간: 2호점 김밥 → 3호점 카페 · 도보 약 2분');
      // A far leg is not labelled as a walk (e.g. not "도보 약 28분").
      expect(
        _legLabel(tester, 4),
        '4구간: 3호점 카페 → 4호점 디저트 · 대중교통/차량 이동 (2.3km)',
      );
      // No time is left between the cards, where it read as the time of the
      // leg above it: each time sits inside the button of its own leg.
      expect(find.text('도보 약 2분'), findsNWidgets(2));
      for (final leg in [2, 3]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('route-leg-$leg')),
            matching: find.text('도보 약 2분'),
          ),
          findsOneWidget,
        );
      }

      // Total distance is aggregated safely
      expect(find.text('총 거리'), findsOneWidget);
      expect(find.text('거리 정보 없음'), findsNothing);
    },
  );

  testWidgets(
    'radius policy excludes a 22.4km store instead of building a far leg',
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

      // Store 1 -> Store 2 and Store 2 -> Store 3 are ~222m walks.
      expect(_legLabel(tester, 2), endsWith('· 도보 약 3분'));
      expect(_legLabel(tester, 3), endsWith('· 도보 약 3분'));
      // The 22.4km store is outside the radius: no card and no leg to it.
      expect(find.byKey(const ValueKey('route-leg-4')), findsNothing);
      expect(find.textContaining('대중교통/차량 이동'), findsNothing);
      expect(find.byKey(const ValueKey('route-step-4')), findsNothing);
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

  testWidgets('the leg sheet opens directions for the leg that is picked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    // Store 2 has no coordinates, so neither the leg to it nor the leg
    // from it can be opened.
    final service = _FakeRouteService(
      route: {
        'picks': [
          {
            'storeName': '1호점 국수',
            'latitude': 37.5665,
            'longitude': 126.9780,
            'distanceMeters': 55,
          },
          {'storeName': '2호점 김밥', 'distanceMeters': 222},
          {
            'storeName': '3호점 카페',
            'latitude': 37.5695,
            'longitude': 126.9780,
            'distanceMeters': 389,
          },
        ],
      },
    );
    Map<String, dynamic>? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [todaysPickServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const OptimalRouteScreen()),
              GoRoute(
                path: AppRoutes.directionsExternalApp,
                builder: (_, state) {
                  opened = state.extra! as Map<String, dynamic>;
                  return const Scaffold(body: Text('길찾기 화면'));
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('구간별 길찾기'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('route-legs-sheet'));
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet('1호점 국수'), findsOneWidget);
    expect(inSheet('현재 위치에서 출발'), findsOneWidget);
    expect(inSheet('도보 약 1분 · 56m'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('route-leg-sheet-1'))),
      isSemantics(
        label: '1구간, 현재 위치에서 1호점 국수까지, 도보 약 1분, 56m',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('route-leg-sheet-2'))),
      isSemantics(
        label: '2구간, 1호점 국수에서 2호점 김밥까지, 위치 정보가 없어 이 구간을 열 수 없어요.',
        isButton: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );

    // A leg that cannot be opened keeps the sheet open.
    await tester.tap(find.byKey(const ValueKey('route-leg-sheet-2')));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(opened, isNull);

    await tester.tap(find.byKey(const ValueKey('route-leg-sheet-1')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.text('길찾기 화면'), findsOneWidget);
    expect(opened, containsPair('storeName', '1호점 국수'));
    expect(opened, containsPair('startName', '현재 위치'));
    expect(opened, containsPair('startLatitude', 37.5660));
    semantics.dispose();
  });
}

/// The full label of the "N구간" button: the leg, then its travel time.
String _legLabel(WidgetTester tester, int leg) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey('route-leg-$leg')),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.semanticsLabel ?? text.data!)
    .join(' · ');

class _FakeRouteService extends TodaysPickService {
  _FakeRouteService({required this.route});
  final Map<String, dynamic> route;

  @override
  Future<Map<String, dynamic>> getRoute({
    double? lat,
    double? lng,
    int radiusMeters = 3000,
  }) async => route;
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

  final _channels = <JavaScriptChannelParams>[];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    _channels.add(params);
  }

  /// Like a page whose map is drawn at once, it reports back after loading.
  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    scheduleMicrotask(() {
      for (final channel in _channels) {
        channel.onMessageReceived(const JavaScriptMessage(message: 'ready'));
      }
    });
  }

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

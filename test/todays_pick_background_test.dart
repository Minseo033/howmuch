import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
    HomeMapScreen.globalUserPosition = _position(37.5665);
  });
  tearDown(() => HomeMapScreen.globalUserPosition = null);

  testWidgets('cards precede pending device weather and remain nearby-based', (
    tester,
  ) async {
    final device = Completer<http.Response>();
    var deviceCalls = 0;
    final service = TodaysPickService(
      MockClient((request) async {
        if (request.url.host == 'api.open-meteo.com') {
          deviceCalls++;
          return device.future;
        }
        return _response(_picks('먼저 보이는 매장', refreshing: false));
      }),
    );
    await _show(tester, service);
    expect(deviceCalls, 1);
    expect(find.text('먼저 보이는 매장'), findsOneWidget);
    expect(find.text('주변 추천'), findsOneWidget);
    expect(find.text('날씨 기반'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    device.complete(
      _response({
        'current': {'temperature_2m': 29, 'weather_code': 0},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('29°'), findsOneWidget);
    expect(find.text('주변 추천'), findsOneWidget);
    expect(find.text('날씨 기반'), findsNothing);
    expect(find.text('✨ 거리와 가격으로 추천했어요'), findsOneWidget);
    expect(find.text('먼저 보이는 매장'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'pending weather polls same endpoint without hiding primary cards',
    (tester) async {
      final later = Completer<http.Response>();
      final requests = <http.Request>[];
      final service = TodaysPickService(
        MockClient((request) {
          requests.add(request);
          return requests.length == 1
              ? Future.value(_response(_picks('주변 매장')))
              : later.future;
        }),
      );
      await _show(tester, service);
      expect(find.text('주변 매장'), findsOneWidget);
      expect(find.text('날씨 정보를 확인하고 있어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(requests, hasLength(2));
      expect(find.text('주변 매장'), findsOneWidget);
      expect(requests.last.url, requests.first.url);
      expect(requests.last.url.path, '/api/recommendation/todays-pick');
      later.complete(_response(_picks('날씨로 다시 고른 매장', ready: true)));
      await tester.pumpAndSettle();
      expect(find.text('날씨로 다시 고른 매장'), findsOneWidget);
      expect(find.text('주변 매장'), findsNothing);
      expect(find.text('날씨 기반'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed background poll keeps cards and retries without a full-page error',
    (tester) async {
      var calls = 0;
      final service = TodaysPickService(
        MockClient((_) async {
          calls++;
          if (calls == 2) return http.Response('{}', 503);
          return _response(
            _picks(calls == 1 ? '유지되는 매장' : '복구된 날씨 매장', ready: calls > 2),
          );
        }),
      );
      await _show(tester, service);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('유지되는 매장'), findsOneWidget);
      expect(find.text('추천 서버에 문제가 생겼어요'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(calls, 3);
      expect(find.text('복구된 날씨 매장'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'device fallback starts only after server weather is definitively unavailable',
    (tester) async {
      var apiCalls = 0;
      var deviceCalls = 0;
      final device = Completer<http.Response>();
      final service = TodaysPickService(
        MockClient((request) async {
          if (request.url.host == 'api.open-meteo.com') {
            deviceCalls++;
            return device.future;
          }
          apiCalls++;
          return _response(
            _picks(
              apiCalls == 1 ? '초기 주변 매장' : '확정 주변 매장',
              refreshing: apiCalls == 1,
            ),
          );
        }),
      );
      await _show(tester, service);
      expect(deviceCalls, 0);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(apiCalls, 2);
      expect(deviceCalls, 1);
      expect(find.text('확정 주변 매장'), findsOneWidget);
      device.complete(
        _response({
          'current': {'temperature_2m': 19, 'weather_code': 0},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('19°'), findsOneWidget);
      expect(find.text('주변 추천'), findsOneWidget);
      expect(find.text('날씨 기반'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(apiCalls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('weather polling stops after four refresh attempts', (
    tester,
  ) async {
    var calls = 0;
    final service = TodaysPickService(
      MockClient((request) async {
        expect(request.url.path, '/api/recommendation/todays-pick');
        calls++;
        return _response(_picks('계속 보이는 매장'));
      }),
    );
    await _show(tester, service);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }
    expect(calls, 5);
    expect(find.text('계속 보이는 매장'), findsOneWidget);
    expect(find.text('날씨 정보를 확인하지 못했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final change in ['coordinates', 'radius', 'day', 'disposal']) {
    testWidgets('ignores late poll result after $change changes', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 21, 12);
      final later = Completer<http.Response>();
      var calls = 0;
      final service = TodaysPickService(
        MockClient((_) {
          calls++;
          if (calls == 2) return later.future;
          return Future.value(
            _response(
              _picks('현재 매장', refreshing: calls == 1, ready: calls > 2),
            ),
          );
        }),
      );
      await _show(tester, service, clock: () => now);
      final element = tester.element(find.byType(TodaysPickScreen));
      final container = ProviderScope.containerOf(element);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 2);
      if (change == 'coordinates') {
        HomeMapScreen.globalUserPosition = _position(37.566501);
      } else if (change == 'radius') {
        await container
            .read(recommendationRadiusProvider.notifier)
            .setRadius(1000);
        await tester.pump();
      } else if (change == 'day') {
        now = now.add(const Duration(days: 1));
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      later.complete(_response(_picks('이미 지난 요청의 매장', ready: true)));
      await tester.pumpAndSettle();
      expect(find.text('이미 지난 요청의 매장'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, change == 'radius' ? 3 : 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'a new load generation ignores an old device-weather completion',
    (tester) async {
      final device = Completer<http.Response>();
      var apiCalls = 0;
      final service = TodaysPickService(
        MockClient((request) async {
          if (request.url.host == 'api.open-meteo.com') return device.future;
          apiCalls++;
          return _response(
            _picks(
              apiCalls == 1 ? '첫 매장' : '새 세대 매장',
              refreshing: false,
              ready: apiCalls > 1,
            ),
          );
        }),
      );
      await _show(tester, service);
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await refresh;
      await tester.pump();
      expect(find.text('새 세대 매장'), findsOneWidget);
      expect(find.text('20°'), findsOneWidget);
      device.complete(
        _response({
          'current': {'temperature_2m': 99, 'weather_code': 0},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('99°'), findsNothing);
      expect(find.text('20°'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final contextChange in ['exact coordinates', 'new day', 'expired TTL']) {
    testWidgets('never renders cache from $contextChange', (tester) async {
      var now = DateTime(2026, 10, 21, 12);
      var calls = 0;
      final fresh = Completer<http.Response>();
      final service = TodaysPickService(
        MockClient((_) {
          calls++;
          return calls == 1
              ? Future.value(_response(_picks('다른 조건의 캐시', ready: true)))
              : fresh.future;
        }),
        const Duration(seconds: 20),
        () => now,
      );
      await service.getTodaysPick(lat: 37.5665, lng: 126.978);
      if (contextChange == 'exact coordinates') {
        HomeMapScreen.globalUserPosition = _position(37.566501);
      } else if (contextChange == 'new day') {
        now = now.add(const Duration(days: 1));
      } else {
        now = now.add(const Duration(minutes: 1));
      }
      await _show(tester, service, clock: () => now);
      expect(calls, 2);
      expect(find.text('다른 조건의 캐시'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      fresh.complete(_response(_picks('현재 조건의 매장', ready: true)));
      await tester.pumpAndSettle();
      expect(find.text('현재 조건의 매장'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final change in ['coordinates', 'day']) {
    testWidgets(
      'initial load restarts instead of spinning after $change changes',
      (tester) async {
        var now = DateTime(2026, 10, 21, 12);
        var calls = 0;
        final initial = Completer<http.Response>();
        final service = TodaysPickService(
          MockClient((_) {
            calls++;
            return calls == 1
                ? initial.future
                : Future.value(_response(_picks('바뀐 조건의 매장', ready: true)));
          }),
          const Duration(seconds: 20),
          () => now,
        );
        await _show(tester, service, clock: () => now);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        if (change == 'coordinates') {
          HomeMapScreen.globalUserPosition = _position(37.566501);
        } else {
          now = now.add(const Duration(days: 1));
        }
        initial.complete(_response(_picks('이전 조건의 응답', ready: true)));
        await tester.pump();
        await tester.pump();
        expect(calls, 2);
        expect(find.text('이전 조건의 응답'), findsNothing);
        expect(find.text('바뀐 조건의 매장'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'cached cards remain usable after explicit refresh fails and retry recovers',
    (tester) async {
      var calls = 0;
      final service = TodaysPickService(
        MockClient((_) async {
          calls++;
          if (calls == 2) return http.Response('{}', 503);
          return _response(
            _picks(calls == 1 ? '보존할 캐시 매장' : '재시도 성공 매장', ready: true),
          );
        }),
      );
      await service.getTodaysPick(lat: 37.5665, lng: 126.978);
      await _show(tester, service);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('보존할 캐시 매장'), findsOneWidget);
      expect(find.text('추천 서버에 문제가 생겼어요'), findsNothing);
      expect(find.textContaining('아래로 당겨 다시 시도해주세요.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(calls, 3);
      expect(find.text('재시도 성공 매장'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'fresh cached cards render immediately and survive same-context refresh',
    (tester) async {
      final later = Completer<http.Response>();
      var calls = 0;
      final now = DateTime(2026, 10, 21, 12);
      final service = TodaysPickService(
        MockClient((_) {
          calls++;
          return calls == 1
              ? Future.value(_response(_picks('캐시 매장', ready: true)))
              : later.future;
        }),
        const Duration(seconds: 20),
        () => now,
      );
      await service.getTodaysPick(lat: 37.5665, lng: 126.978);
      await _show(tester, service, clock: () => now);
      expect(calls, 1);
      expect(find.text('캐시 매장'), findsOneWidget);
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('캐시 매장'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      later.complete(_response(_picks('새 매장', ready: true)));
      await refresh;
      await tester.pump();
      expect(find.text('새 매장'), findsOneWidget);
      expect(find.text('캐시 매장'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _show(
  WidgetTester tester,
  TodaysPickService service, {
  DateTime Function()? clock,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [todaysPickServiceProvider.overrideWithValue(service)],
      child: MaterialApp(home: TodaysPickScreen(clock: clock)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

http.Response _response(Map<String, dynamic> data) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), 200);

Map<String, dynamic> _picks(
  String name, {
  bool refreshing = true,
  bool ready = false,
}) => {
  'weatherAvailable': ready,
  'weatherRefreshing': refreshing && !ready,
  'recommendationBasis': ready ? 'weather' : 'nearby',
  'weather': ready ? '맑음' : '알 수 없음',
  'temp': ready ? 20 : null,
  'picks': [
    {'storeName': name, 'menu1': '백반', 'price1': '7000', 'distanceMeters': 100},
  ],
};

Position _position(double lat) => Position(
  latitude: lat,
  longitude: 126.978,
  timestamp: DateTime(2026, 10, 21),
  accuracy: 8,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

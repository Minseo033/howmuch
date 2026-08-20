import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/optimal_route_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';

void main() {
  setUp(() {
    HomeMapScreen.globalUserPosition = Position(
      longitude: 126.978,
      latitude: 37.5665,
      timestamp: DateTime(2026, 8, 19),
      accuracy: 8,
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

  testWidgets('today pick handles decorated prices and long names at 360px', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      todaysPick: {
        'weather': '맑음',
        'temp': 31,
        'fcstTime': '202608192300',
        'picks': [
          {
            'storeName': '아주 긴 이름의 착한가격업소 테스트 매장 본점',
            'menu1': '아메리카노',
            'price1': '2,000원',
            'distanceMeters': 15771,
            'latitude': 37.57,
            'longitude': 126.98,
          },
        ],
      },
    );

    await tester.pumpWidget(_app(service, const TodaysPickScreen()));
    await tester.pumpAndSettle();

    expect(find.text('2,000원'), findsOneWidget);
    expect(find.text('2,000원원'), findsNothing);
    expect(find.text('15.8km'), findsOneWidget);
    expect(find.text('23시 기준'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('route screen tolerates missing coordinates at 360px', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      route: {
        'route': '좌표가 없는 매장은 지도에서 제외하고 목록으로 안내합니다.',
        'picks': [
          {
            'storeName': '좌표 정보가 누락된 아주 긴 이름의 실제 매장',
            'menu1': '잔치국수',
            'price1': '5,000원',
            'distanceMeters': 803,
          },
        ],
      },
    );

    await tester.pumpWidget(_app(service, const OptimalRouteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('매장 좌표가 없어 지도를 표시할 수 없어요.'), findsOneWidget);
    expect(find.text('5,000원'), findsOneWidget);
    expect(find.text('총 예상 비용'), findsOneWidget);
    _expectNoFlutterError(tester);
  });
}

Widget _app(TodaysPickService service, Widget child) {
  return ProviderScope(
    overrides: [todaysPickServiceProvider.overrideWithValue(service)],
    child: MaterialApp(home: child),
  );
}

Future<void> _setMobileViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectNoFlutterError(WidgetTester tester) {
  final error = tester.takeException();
  if (error is FlutterError) fail(error.toStringDeep());
  expect(error, isNull);
}

class _FakeTodaysPickService extends TodaysPickService {
  _FakeTodaysPickService({this.todaysPick = const {}, this.route = const {}});

  final Map<String, dynamic> todaysPick;
  final Map<String, dynamic> route;

  @override
  Future<Map<String, dynamic>> getTodaysPick({
    double? lat,
    double? lng,
  }) async => todaysPick;

  @override
  Future<Map<String, dynamic>> getRoute({double? lat, double? lng}) async =>
      route;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/optimal_route_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_failure.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/store/store_model.dart';

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
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.setMapStores(const []);
  });

  testWidgets('today pick names a timeout instead of a generic failure', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      todaysPick: recommendationError(RecommendationFailure.timeout),
    );

    await tester.pumpWidget(
      _app(
        service,
        TodaysPickScreen(fallbackCatalogLoader: () async => const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('서버 응답이 늦어지고 있어요'), findsOneWidget);
    expect(find.text('오늘의 픽을 불러오지 못했어요'), findsNothing);
    expect(find.text('설정 열기'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('today pick asks for location permission when none is known', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    HomeMapScreen.globalUserPosition = null;
    final service = _FakeTodaysPickService();

    await tester.pumpWidget(_app(service, const TodaysPickScreen()));
    await tester.pumpAndSettle();

    expect(find.text('현재 위치를 확인할 수 없어요'), findsOneWidget);
    expect(find.text('주변 추천을 보려면 위치 권한을 허용해주세요.'), findsOneWidget);
    expect(find.text('설정 열기'), findsOneWidget);
    expect(service.todaysPickCalls, 0);
    _expectNoFlutterError(tester);
  });

  testWidgets(
    'today pick loads the catalog for the local fallback when memory is empty',
    (tester) async {
      await _setMobileViewport(tester, const Size(360, 800));
      final service = _FakeTodaysPickService(
        todaysPick: recommendationError(
          RecommendationFailure.server,
          statusCode: 500,
        ),
      );
      var catalogRequests = 0;

      await tester.pumpWidget(
        _app(
          service,
          TodaysPickScreen(
            fallbackCatalogLoader: () async {
              catalogRequests++;
              return [_store('근처 백반집', 37.5666, 126.9781)];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalogRequests, 1);
      expect(find.text('근처 백반집'), findsOneWidget);
      expect(find.text('추천 서버에 문제가 생겼어요'), findsNothing);
      // The loaded catalog is kept, so a retry does not download it again.
      expect(HomeMapScreen.globalSearchCatalog, hasLength(1));
      _expectNoFlutterError(tester);
    },
  );

  testWidgets('route screen explains the hourly request limit', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      route: recommendationError(
        RecommendationFailure.rateLimited,
        statusCode: 429,
      ),
    );

    await tester.pumpWidget(_app(service, const OptimalRouteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('요청이 너무 많아요'), findsOneWidget);
    expect(find.text('추천 경로를 불러오지 못했어요'), findsNothing);
    _expectNoFlutterError(tester);
  });

  testWidgets('distance-ordered routes are not labelled as AI routes', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    Map<String, dynamic> routeWith(String text) => {
      'route': text,
      'picks': [
        {
          'storeName': '좌표 없는 국숫집',
          'menu1': '잔치국수',
          'price1': '5000',
          'distanceMeters': 300,
        },
      ],
    };

    await tester.pumpWidget(
      _app(
        _FakeTodaysPickService(
          route: routeWith('현재는 거리순으로 추천 루트를 안내합니다.\n1. 좌표 없는 국숫집'),
        ),
        const OptimalRouteScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('가까운 순서로 정한 동선'), findsOneWidget);
    expect(find.text('동선 안내'), findsOneWidget);
    expect(find.textContaining('AI 추천'), findsNothing);

    await tester.pumpWidget(
      _app(
        _FakeTodaysPickService(route: routeWith('1. 좌표 없는 국숫집 - 비 오는 날 국물')),
        const OptimalRouteScreen(key: ValueKey('ai-route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 추천 동선'), findsOneWidget);
    expect(find.text('AI 추천 이유'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('user reports are not labelled government certified', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      todaysPick: {
        'picks': [
          {
            'storeName': '동네 제보 식당',
            'menu1': '백반',
            'price1': '6500',
            'source': 'USER',
            'distanceMeters': 120,
          },
        ],
      },
    );
    await tester.pumpWidget(_app(service, const TodaysPickScreen()));
    await tester.pumpAndSettle();
    expect(find.text('사용자 제보'), findsOneWidget);
    expect(find.text('착한가격업소'), findsNothing);
    _expectNoFlutterError(tester);
  });

  testWidgets('a store with an unknown source is not labelled certified', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      todaysPick: {
        'picks': [
          {
            'storeName': '출처 미상 식당',
            'menu1': '백반',
            'price1': '6500',
            'source': 'UNKNOWN',
            'distanceMeters': 120,
          },
        ],
      },
    );
    await tester.pumpWidget(_app(service, const TodaysPickScreen()));
    await tester.pumpAndSettle();
    expect(find.text('출처 확인 필요'), findsOneWidget);
    expect(find.text('착한가격업소'), findsNothing);
    _expectNoFlutterError(tester);
  });

  testWidgets(
    'today pick hides distant entries and handles long names at 360px',
    (tester) async {
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
              'distanceMeters': 2000,
              'latitude': 37.57,
              'longitude': 126.98,
            },
            {
              'storeName': '상한 밖의 먼 매장',
              'menu1': '백반',
              'price1': '7,000원',
              'distanceMeters': 15771,
              'latitude': 37.7,
              'longitude': 127.1,
            },
          ],
        },
      );

      await tester.pumpWidget(_app(service, const TodaysPickScreen()));
      await tester.pumpAndSettle();

      expect(find.text('2,000원'), findsOneWidget);
      expect(find.text('2,000원원'), findsNothing);
      expect(find.text('2.0km'), findsOneWidget);
      expect(find.text('상한 밖의 먼 매장'), findsNothing);
      expect(find.text('23시 기준'), findsOneWidget);
      _expectNoFlutterError(tester);
    },
  );

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
    expect(find.text('5,000원 (표시 가격 합계)'), findsOneWidget);
    expect(find.text('총 예상 비용'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('route uses the matched menu for each card and total cost', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(360, 800));
    final service = _FakeTodaysPickService(
      route: {
        'picks': [
          {
            'storeId': 'test-pork',
            'storeName': '천이오겹살',
            'menu1': '삼겹살',
            'price1': '10000',
            'menu2': '비빔국수',
            'price2': '4000',
            'matchedMenu': '비빔국수',
            'distanceMeters': 100,
          },
          {
            'storeId': 'test-noodles',
            'storeName': '맛양값 칼국수',
            'menu1': '칼국수',
            'price1': '6000',
            'distanceMeters': 200,
          },
        ],
      },
    );

    await tester.pumpWidget(_app(service, const OptimalRouteScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('비빔국수 · 4,000원'), findsOneWidget);
    expect(find.textContaining('칼국수 · 6,000원'), findsOneWidget);
    expect(find.text('10,000원 (표시 가격 합계)'), findsOneWidget);
    expect(find.textContaining('삼겹살 · 10,000원'), findsNothing);
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
  int todaysPickCalls = 0;

  @override
  Future<Map<String, dynamic>> getTodaysPick({
    double? lat,
    double? lng,
    int radiusMeters = 3000,
  }) async {
    todaysPickCalls++;
    return todaysPick;
  }

  @override
  Future<Map<String, dynamic>> getRoute({
    double? lat,
    double? lng,
    int radiusMeters = 3000,
  }) async => route;
}

Store _store(String name, double lat, double lng) => Store(
  id: name,
  storeName: name,
  address: '서울',
  phoneNumber: '',
  industry: '한식',
  menu1: '백반',
  price1: '7000',
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: lat,
  longitude: lng,
  source: 'GOV',
);

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final cityHall = _store('city-hall', '시청 칼국수', 37.5665, 126.978);
  final busan = _store('busan', '부산 칼국수', 35.1796, 129.0756);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeMapScreen.setSearchCatalog([cityHall]);
    HomeMapScreen.globalUserPosition = null;
  });

  tearDown(() {
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.globalUserPosition = null;
  });

  test('the home route turns a search result into the map search', () {
    final result = buildSearchMapResult(
      query: '칼국수',
      filter: const SearchFilter(),
      stores: [cityHall],
    );
    final fromSearch = buildHomeMapScreenForExtra(result);
    expect(fromSearch.initialSearchResult, same(result));
    expect(fromSearch.initialRecommendation, isNull);

    final ai = AiMapRecommendationResult(
      storeIds: const ['city-hall'],
      stores: [cityHall],
    );
    final fromAi = buildHomeMapScreenForExtra(ai);
    expect(fromAi.initialRecommendation, same(ai));
    expect(fromAi.initialSearchResult, isNull);

    final plain = buildHomeMapScreenForExtra(null);
    expect(plain.initialSearchResult, isNull);
    expect(plain.initialRecommendation, isNull);
  });

  test('only the home map asks search to hand its result back', () {
    expect(
      buildSearchResultScreenForExtra(const {
        'query': '칼국수',
        'returnToMap': true,
      }).returnsResultToMap,
      isTrue,
    );
    expect(
      buildSearchResultScreenForExtra(const {'query': ''}).returnsResultToMap,
      isFalse,
    );
    final fromText = buildSearchResultScreenForExtra('국밥');
    expect(fromText.initialQuery, '국밥');
    expect(fromText.returnsResultToMap, isFalse);
  });

  testWidgets(
    'a search opened from the community shows its result on the home map',
    (tester) async {
      Object? homeExtra = 'home not opened';
      final router = _router(
        initialLocation: '/community',
        onHome: (extra) => homeExtra = extra,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('커뮤니티 검색'));
      await tester.pumpAndSettle();
      expect(find.text('시청 칼국수'), findsOneWidget);

      await tester.tap(find.text('지도에서 보기'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
      final result = homeExtra as Map<String, dynamic>;
      expect(result['query'], '칼국수');
      expect((result['stores'] as List<Store>).single.id, 'city-hall');
    },
  );

  testWidgets('back from a community search returns to the community', (
    tester,
  ) async {
    Object? homeExtra = 'home not opened';
    final router = _router(
      initialLocation: '/community',
      onHome: (extra) => homeExtra = extra,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('커뮤니티 검색'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
    expect(homeExtra, 'home not opened');
  });

  testWidgets('a search opened from home pops its result back to that map', (
    tester,
  ) async {
    final returned = <Map<String, dynamic>?>[];
    final router = _router(
      initialLocation: AppRoutes.home,
      onHome: (_) {},
      onHomeSearchResult: returned.add,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('지도 검색'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지도에서 보기'));
    await tester.pumpAndSettle();
    expect(returned.single?['query'], '칼국수');
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
  });

  testWidgets('the distance filter finds the position when home has none', (
    tester,
  ) async {
    HomeMapScreen.setSearchCatalog([cityHall, busan]);
    var lookups = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(
          initialQuery: '칼국수',
          initialFilter: const SearchFilter(distance: '1km 이내'),
          positionLookup: () async {
            lookups++;
            return _position(37.5662, 126.9779);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(lookups, 1);
    expect(find.text('시청 칼국수'), findsOneWidget);
    expect(find.text('부산 칼국수'), findsNothing);
    expect(HomeMapScreen.globalUserPosition?.latitude, 37.5662);
  });

  testWidgets('without a position the distance filter explains and retries', (
    tester,
  ) async {
    var lookups = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(
          initialQuery: '칼국수',
          initialFilter: const SearchFilter(distance: '1km 이내'),
          positionLookup: () async {
            lookups++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('거리 필터를 사용하려면 현재 위치 권한이 필요해요.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(lookups, 2);
  });
}

GoRouter _router({
  required String initialLocation,
  required ValueSetter<Object?> onHome,
  ValueSetter<Map<String, dynamic>?>? onHomeSearchResult,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/community',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push(
                AppRoutes.searchResult,
                extra: const {'query': '칼국수'},
              ),
              child: const Text('커뮤니티 검색'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          onHome(state.extra);
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await context.push<Map<String, dynamic>>(
                    AppRoutes.searchResult,
                    extra: const {'query': '칼국수', 'returnToMap': true},
                  );
                  onHomeSearchResult?.call(result);
                },
                child: const Text('지도 검색'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.searchResult,
        builder: (_, state) => buildSearchResultScreenForExtra(state.extra),
      ),
    ],
  );
}

Store _store(String id, String name, double latitude, double longitude) =>
    Store.fromJson({
      'id': id,
      'storeName': name,
      'address': '서울특별시 중구',
      'industry': '한식',
      'menu1': '칼국수',
      'price1': '8000',
      'latitude': latitude,
      'longitude': longitude,
    });

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

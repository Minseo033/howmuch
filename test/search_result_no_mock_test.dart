import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/search/presentation/state/search_history_store.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows a retry state instead of fabricated stores', (
    tester,
  ) async {
    final previousStores = HomeMapScreen.globalAllStores;
    HomeMapScreen.globalAllStores = <Store>[];
    addTearDown(() => HomeMapScreen.globalAllStores = previousStores);

    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(
          initialQuery: '김치찌개',
          storeCatalogLoader: () async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('매장 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('김치찌개 맛집 1호'), findsNothing);
  });

  testWidgets('loads the full catalog only when a search needs it', (
    tester,
  ) async {
    final previousStores = HomeMapScreen.globalAllStores;
    HomeMapScreen.globalAllStores = <Store>[];
    addTearDown(() => HomeMapScreen.globalAllStores = previousStores);
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(
          initialQuery: '김치찌개',
          storeCatalogLoader: () async {
            loadCount++;
            return [
              Store(
                id: 'store-1',
                storeName: '실제 김치찌개 식당',
                address: '서울특별시 중구',
                phoneNumber: '',
                industry: '한식',
                menu1: '김치찌개',
                price1: '7000',
                menu2: '',
                price2: '',
                menu3: '',
                price3: '',
                menu4: '',
                price4: '',
                latitude: 37.5665,
                longitude: 126.9780,
                source: 'GOV',
              ),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);
    expect(find.text('실제 김치찌개 식당'), findsOneWidget);
  });

  testWidgets('empty search fits an iPhone-sized viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousStores = HomeMapScreen.globalAllStores;
    HomeMapScreen.globalAllStores = List.generate(
      4,
      (index) => Store(
        id: 'store-$index',
        storeName: '실제 매장 $index',
        address: '서울특별시 중구',
        phoneNumber: '',
        industry: '한식',
        menu1: '메뉴 $index',
        price1: '7000',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.5665,
        longitude: 126.9780,
        source: 'GOV',
      ),
    );
    addTearDown(() => HomeMapScreen.globalAllStores = previousStores);

    await tester.pumpWidget(
      const MaterialApp(home: SearchResultScreen(initialQuery: '없는 메뉴')),
    );
    await tester.pumpAndSettle();

    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty query shows persistent recent searches with delete actions',
    (tester) async {
      final history = SearchHistoryStore();
      await history.add('한식');
      await history.add('커피');

      await tester.pumpWidget(
        MaterialApp(
          home: SearchResultScreen(
            initialQuery: '',
            searchHistoryStore: history,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('최근 검색'), findsOneWidget);
      expect(find.text('커피'), findsOneWidget);
      expect(find.text('한식'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remove-recent-search-한식')));
      await tester.pumpAndSettle();
      expect(find.text('한식'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('clear-recent-searches')));
      await tester.pumpAndSettle();
      expect(find.text('커피'), findsNothing);
      expect(find.text('아직 검색 기록이 없어요'), findsOneWidget);
    },
  );

  testWidgets('tapping a recent search runs it and moves it to the front', (
    tester,
  ) async {
    final previousStores = HomeMapScreen.globalAllStores;
    HomeMapScreen.globalAllStores = [
      Store(
        id: 'coffee-store',
        storeName: '역삼 커피',
        address: '서울특별시 강남구',
        phoneNumber: '',
        industry: '카페',
        menu1: '커피',
        price1: '3000',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.5,
        longitude: 127.0,
        source: 'GOV',
      ),
    ];
    addTearDown(() => HomeMapScreen.globalAllStores = previousStores);

    final history = SearchHistoryStore();
    await history.add('커피');
    await history.add('한식');

    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(initialQuery: '', searchHistoryStore: history),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recent-search-커피')));
    await tester.pumpAndSettle();

    expect(find.text('역삼 커피'), findsOneWidget);
    expect((await history.load()).first, '커피');
  });
}

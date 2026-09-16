import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/search/presentation/state/search_filter_policy.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SearchFilterPolicy findMatchingMenu', () {
    final testStore = Store(
      id: 's1',
      storeName: '착한반점',
      address: '서울시 역삼동',
      phoneNumber: '02-123-4567',
      industry: '중식',
      menu1: '짜장면',
      price1: '5000',
      menu2: '해물짬뽕',
      price2: '7000',
      menu3: '탕수육',
      price3: '12000',
      menu4: '군만두',
      price4: '4000',
      latitude: 37.5,
      longitude: 127.0,
      source: 'GOV',
    );

    test('query matching menu2 returns menu2 with price and index', () {
      final match = SearchFilterPolicy.findMatchingMenu(testStore, '짬뽕');
      expect(match, isNotNull);
      expect(match!.name, '해물짬뽕');
      expect(match.price, '7000');
      expect(match.index, 2);
    });

    test('query matching menu3 returns menu3 with price and index', () {
      final match = SearchFilterPolicy.findMatchingMenu(testStore, '탕수육');
      expect(match, isNotNull);
      expect(match!.name, '탕수육');
      expect(match.price, '12000');
      expect(match.index, 3);
    });

    test('query matching store name or unrelated query returns null', () {
      expect(SearchFilterPolicy.findMatchingMenu(testStore, '착한반점'), isNull);
      expect(SearchFilterPolicy.findMatchingMenu(testStore, '피자'), isNull);
      expect(SearchFilterPolicy.findMatchingMenu(testStore, ''), isNull);
    });
  });

  group('SearchResultScreen match prioritization widget tests', () {
    testWidgets('prioritizes the matched menu and displays search menu badge', (
      tester,
    ) async {
      final previous = HomeMapScreen.globalAllStores;
      HomeMapScreen.globalAllStores = [
        Store(
          id: 's-cafe',
          storeName: '맛있는 카페',
          address: '서울시 강남구',
          phoneNumber: '02-111-2222',
          industry: '카페',
          menu1: '아메리카노',
          price1: '2500',
          menu2: '치아바타 샌드위치',
          price2: '6000',
          menu3: '',
          price3: '',
          menu4: '',
          price4: '',
          latitude: 37.5,
          longitude: 127.0,
          source: 'GOV',
        ),
      ];
      HomeMapScreen.setSearchCatalog(HomeMapScreen.globalAllStores);
      addTearDown(() => HomeMapScreen.globalAllStores = previous);

      await tester.pumpWidget(
        const MaterialApp(home: SearchResultScreen(initialQuery: '샌드위치')),
      );
      await tester.pumpAndSettle();

      expect(find.text('맛있는 카페'), findsOneWidget);
      expect(find.text('검색 메뉴'), findsOneWidget);
      expect(find.text('치아바타 샌드위치  6,000원'), findsOneWidget);
      expect(find.text('아메리카노  2,500원'), findsNothing);
    });

    testWidgets(
      'displays menu1 without search badge when searching by store name',
      (tester) async {
        final previous = HomeMapScreen.globalAllStores;
        HomeMapScreen.globalAllStores = [
          Store(
            id: 's-cafe',
            storeName: '맛있는 카페',
            address: '서울시 강남구',
            phoneNumber: '02-111-2222',
            industry: '카페',
            menu1: '아메리카노',
            price1: '2500',
            menu2: '치아바타 샌드위치',
            price2: '6000',
            menu3: '',
            price3: '',
            menu4: '',
            price4: '',
            latitude: 37.5,
            longitude: 127.0,
            source: 'GOV',
          ),
        ];
        HomeMapScreen.setSearchCatalog(HomeMapScreen.globalAllStores);
        addTearDown(() => HomeMapScreen.globalAllStores = previous);

        await tester.pumpWidget(
          const MaterialApp(home: SearchResultScreen(initialQuery: '맛있는 카페')),
        );
        await tester.pumpAndSettle();

        expect(find.text('맛있는 카페'), findsNWidgets(2));
        expect(find.text('검색 메뉴'), findsNothing);
        expect(find.text('아메리카노  2,500원'), findsOneWidget);
      },
    );

    testWidgets('handles long menu names and prices without layout overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final previous = HomeMapScreen.globalAllStores;
      HomeMapScreen.globalAllStores = [
        Store(
          id: 's-long',
          storeName: '매우 길고 장황한 이름의 착한가격 모범 매장 식당 본점',
          address: '서울특별시 강남구 테헤란로 123길 45 지하 1층 101호',
          phoneNumber: '02-999-8888',
          industry: '한식/일반음식점',
          menu1: '기본 정식 백반',
          price1: '5000',
          menu2: '스페셜 프리미엄 한우 차돌 된장찌개와 돌솥밥 세트 정식 메뉴',
          price2: '15000',
          menu3: '',
          price3: '',
          menu4: '',
          price4: '',
          latitude: 37.5,
          longitude: 127.0,
          source: 'GOV',
        ),
      ];
      HomeMapScreen.setSearchCatalog(HomeMapScreen.globalAllStores);
      addTearDown(() => HomeMapScreen.globalAllStores = previous);

      await tester.pumpWidget(
        const MaterialApp(home: SearchResultScreen(initialQuery: '된장찌개')),
      );
      await tester.pumpAndSettle();

      expect(find.text('검색 메뉴'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

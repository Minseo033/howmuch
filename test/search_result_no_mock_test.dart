import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  testWidgets('shows a retry state instead of fabricated stores', (
    tester,
  ) async {
    final previousStores = HomeMapScreen.globalAllStores;
    HomeMapScreen.globalAllStores = <Store>[];
    addTearDown(() => HomeMapScreen.globalAllStores = previousStores);

    await tester.pumpWidget(
      const MaterialApp(home: SearchResultScreen(initialQuery: '김치찌개')),
    );
    await tester.pump();

    expect(find.text('매장 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('김치찌개 맛집 1호'), findsNothing);
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
}

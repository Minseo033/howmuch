import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/store_catalog_loader.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Store _store(String name) => Store.fromJson({
  'storeId': name,
  'storeName': name,
  'menu1': '김치찌개',
  'price1': '5000',
  'latitude': 37.5,
  'longitude': 127.0,
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeMapScreen.setSearchCatalog(const []);
  });
  tearDown(() => HomeMapScreen.setSearchCatalog(const []));

  testWidgets('a stalled loader times out, retries, and ignores late results', (
    tester,
  ) async {
    final stalled = Completer<List<Store>>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(
          initialQuery: '김치찌개',
          storeCatalogLoader: () {
            calls++;
            return calls == 1
                ? stalled.future
                : Future.value([_store('재시도 식당')]);
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('매장 정보를 불러오고 있어요'), findsOneWidget);
    await tester.pump(storeCatalogLoadTimeout);
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('재시도 식당'), findsOneWidget);

    stalled.complete([_store('늦은 식당')]);
    await tester.pumpAndSettle();
    expect(find.text('늦은 식당'), findsNothing);
    expect(HomeMapScreen.globalSearchCatalog.single.storeName, '재시도 식당');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending searches share a loader and only show the latest query',
    (tester) async {
      final pending = Completer<List<Store>>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SearchResultScreen(
            initialQuery: '처음',
            storeCatalogLoader: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '김치찌개');
      await tester.pump(const Duration(milliseconds: 400));
      pending.complete([_store('현재 검색 식당')]);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('현재 검색 식당'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('leaving during a request does not update a disposed screen', (
    tester,
  ) async {
    final pending = Completer<List<Store>>();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultScreen(
          initialQuery: '김치찌개',
          storeCatalogLoader: () => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete([_store('완료 식당')]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(HomeMapScreen.globalSearchCatalog, isEmpty);
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/store/presentation/screens/price_history_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/store_model.dart';

class _NoReviews extends StoreReviewNotifier {
  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {
    state = {...state, storeId: const AsyncValue.data([])};
  }
}

void main() {
  test(
    'price history request retains the exact store identity and selected menu',
    () {
      final store = Store.fromJson({
        'storeId': 'exact-store-id',
        'storeName': '동명 매장',
        'menu1': '커피',
        'price1': '3000 / 3500',
        'menu2': '무료 물',
        'price2': '0',
        'free2': true,
      });
      final uri = priceHistoryUri(store, 2);
      expect(uri.path, endsWith('/exact-store-id/price-history'));
      expect(uri.queryParameters['menu'], '무료 물');
      expect(priceHistoryUri(store, 1).queryParameters['menu'], '커피');
    },
  );

  testWidgets(
    'detail history button transfers the second menu rather than the first',
    (tester) async {
      final store = Store.fromJson({
        'storeId': 'history-store',
        'storeName': '이력 매장',
        'menu1': '커피',
        'price1': '3000 / 3500',
        'menu2': '무료 물',
        'price2': '0',
        'free2': true,
      });
      PriceHistoryTarget? received;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => StoreDetailScreen(store: store),
          ),
          GoRoute(
            path: AppRoutes.priceHistory,
            builder: (_, state) {
              received = state.extra as PriceHistoryTarget;
              return const Scaffold(body: Text('선택한 메뉴 이력'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStoreDetailProvider(
              store.id,
            ).overrideWith((ref) async => store),
            storeReviewProvider.overrideWith((ref) => _NoReviews()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('무료 물 가격 이력'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('무료 물 가격 이력'));
      await tester.pumpAndSettle();
      expect(received?.store.id, store.id);
      expect(received?.menuIndex, 2);
      expect(find.text('선택한 메뉴 이력'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canonical detail replaces stale data and disables closed-store actions',
    (tester) async {
      final result = Completer<Store>();
      final stale = Store.fromJson({
        'storeId': 'qa-store',
        'storeName': '이전 매장명',
        'menu1': '칼국수',
        'price1': '5000',
      });
      final latest = Store.fromJson({
        'storeId': 'qa-store',
        'storeName': '현재 매장명',
        'menu1': '칼국수',
        'price1': '3000 / 3500',
        'isClosed': true,
        'correctionRevision': 2,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStoreDetailProvider(
              'qa-store',
            ).overrideWith((ref) => result.future),
            storeReviewProvider.overrideWith((ref) => _NoReviews()),
          ],
          child: MaterialApp(home: StoreDetailScreen(store: stale)),
        ),
      );
      await tester.pump();
      expect(find.text('이전 매장명'), findsWidgets);
      result.complete(latest);
      await tester.pumpAndSettle();
      expect(find.text('현재 매장명'), findsWidgets);
      expect(find.text('이전 매장명'), findsNothing);
      expect(find.textContaining('폐업으로 확인된 매장'), findsOneWidget);
      final action = find.ancestor(
        of: find.text('방문 인증'),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(action).onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

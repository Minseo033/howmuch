import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets(
    'light catalog detail loads source-backed hours without claiming they are absent',
    (tester) async {
      final details = Completer<Store>();
      final preview = Store.fromJson({
        'storeId': 'light-store',
        'storeName': '상세 매장',
        'menu1': '김밥',
        'price1': '4000',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStoreDetailProvider(
              'light-store',
            ).overrideWith((ref) => details.future),
            storeReviewProvider.overrideWith((ref) => _NoReviews()),
          ],
          child: MaterialApp(home: StoreDetailScreen(store: preview)),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('영업시간을 확인하고 있어요.'));
      expect(find.text('등록된 영업시간이 없어요.'), findsNothing);
      details.complete(
        Store.fromJson({
          ...preview.toJson(),
          'openingHours': {
            'status': 'SOURCE_VERIFIED',
            'text': '매일 09:00~18:00',
            'sourceName': '행정안전부 착한가격업소',
            'sourceUrl':
                'https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=123',
            'checkedAt': '2026-10-21',
            'parkingYn': true,
          },
        }),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('매일 09:00~18:00'));
      expect(find.text('영업시간을 확인하고 있어요.'), findsNothing);
      expect(find.textContaining('2026.10.21 자료 조회'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

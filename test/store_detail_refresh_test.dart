import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

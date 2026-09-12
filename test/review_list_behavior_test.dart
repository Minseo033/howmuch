import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';

class LocalReviews extends StoreReviewNotifier {
  LocalReviews() {
    state = {
      '식당': AsyncValue.data([
        Review(
          id: 'a',
          storeId: '식당',
          authorName: '최근 작성자',
          stars: 2,
          content: '최근 리뷰',
          createdAt: DateTime(2026, 9, 12),
        ),
        Review(
          id: 'b',
          storeId: '식당',
          authorName: '이전 작성자',
          stars: 5,
          content: '이전 리뷰',
          createdAt: DateTime(2026, 9, 1),
        ),
      ]),
    };
  }
  int retries = 0;
  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {
    if (force) {
      retries++;
      state = {storeId: const AsyncValue.data([])};
    }
  }

  void fail() => state = {
    '식당': AsyncValue.error(StateError('offline'), StackTrace.current),
  };
}

void main() {
  testWidgets(
    'review ordering works and failed loading can recover to an empty state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final notifier = LocalReviews();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeReviewProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            home: ReviewListScreen(store: Store.fromJson({'storeName': '식당'})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('최근 리뷰')).dy,
        lessThan(tester.getTopLeft(find.text('이전 리뷰')).dy),
      );
      await tester.tap(find.text('별점 높은순'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('이전 리뷰')).dy,
        lessThan(tester.getTopLeft(find.text('최근 리뷰')).dy),
      );
      expect(find.text('댓글'), findsNothing);
      notifier.fail();
      await tester.pumpAndSettle();
      expect(find.text('리뷰를 불러오지 못했어요'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(notifier.retries, 1);
      expect(find.text('아직 리뷰가 없어요. 첫 리뷰를 남겨보세요!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

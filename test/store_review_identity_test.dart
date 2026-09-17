import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BranchReviews extends StoreReviewNotifier {
  _BranchReviews() {
    state = {
      'store_mokpo': const AsyncValue.data([
        Review(
          storeId: 'store_mokpo',
          authorName: '목포 손님',
          stars: 5,
          content: '목포 지점 리뷰',
        ),
      ]),
      'store_danyang': const AsyncValue.data([
        Review(
          storeId: 'store_danyang',
          authorName: '단양 손님',
          stars: 2,
          content: '단양 지점 리뷰',
        ),
      ]),
      '경남식당': const AsyncValue.data([
        Review(
          storeId: '경남식당',
          authorName: '이전 손님',
          stars: 1,
          content: '소속 불명 리뷰',
        ),
      ]),
    };
  }

  final requestedIds = <String>[];

  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {
    requestedIds.add(storeId);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  for (final detail in [false, true]) {
    for (final branch in ['mokpo', 'danyang']) {
      testWidgets(
        '${detail ? 'detail' : 'list'} isolates same-name $branch reviews',
        (tester) async {
          tester.view.physicalSize = const Size(430, 1500);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final notifier = _BranchReviews();
          final store = Store.fromJson({
            'storeId': 'store_$branch',
            'storeName': '경남식당',
            'address': branch == 'mokpo' ? '목포' : '단양',
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [storeReviewProvider.overrideWith((ref) => notifier)],
              child: MaterialApp(
                home: detail
                    ? StoreDetailScreen(store: store)
                    : ReviewListScreen(store: store),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(notifier.requestedIds, contains('store_$branch'));
          expect(notifier.requestedIds, isNot(contains('경남식당')));
          expect(
            find.text(branch == 'mokpo' ? '목포 지점 리뷰' : '단양 지점 리뷰'),
            findsOneWidget,
          );
          expect(
            find.text(branch == 'mokpo' ? '단양 지점 리뷰' : '목포 지점 리뷰'),
            findsNothing,
          );
          expect(find.text('소속 불명 리뷰'), findsNothing);
          if (detail) {
            expect(find.text(branch == 'mokpo' ? '5.0' : '2.0'), findsWidgets);
            expect(find.text('1.0'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

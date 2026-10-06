import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/utils/text_initial.dart';
import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmojiReviews extends StoreReviewNotifier {
  _EmojiReviews() {
    state = {
      'store_emoji': const AsyncValue.data([
        Review(
          id: 'emoji',
          storeId: 'store_emoji',
          authorName: '😀먹보',
          stars: 6,
          content: '이모지 닉네임 리뷰',
        ),
      ]),
    };
  }

  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {}
}

void main() {
  test('avatar initials keep whole emoji and grapheme clusters', () {
    expect(displayInitial('😀먹보'), '😀');
    expect(displayInitial('👨‍👩‍👧 가족'), '👨‍👩‍👧');
    expect(displayInitial('  김철수'), '김');
    expect(displayInitial('   '), '?');
    expect(displayInitial(null), '?');
    expect(
      const Review(storeId: 's', authorName: '🍜', stars: 5, content: '').initial,
      '🍜',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  for (final detail in [false, true]) {
    testWidgets(
      '${detail ? 'detail' : 'list'} renders an emoji nickname avatar',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = Store.fromJson({
          'storeId': 'store_emoji',
          'storeName': '이모지식당',
          'address': '서울',
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storeReviewProvider.overrideWith((ref) => _EmojiReviews()),
            ],
            child: MaterialApp(
              home: detail
                  ? StoreDetailScreen(store: store)
                  : ReviewListScreen(store: store),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('이모지 닉네임 리뷰'), findsOneWidget);
        expect(find.text('😀'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

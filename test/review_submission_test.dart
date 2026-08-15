import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/presentation/state/review_form_validator.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReviewFormValidator', () {
    test('rejects empty and out-of-range review fields', () {
      expect(ReviewFormValidator.validateMenu('   '), isNotNull);
      expect(ReviewFormValidator.validatePrice('0'), isNotNull);
      expect(ReviewFormValidator.validatePrice('10,000,001'), isNotNull);
      expect(ReviewFormValidator.validateContent('\n  '), isNotNull);
      expect(ReviewFormValidator.validateRating(0), isNotNull);
      expect(
        ReviewFormValidator.validateConfirmations(
          visitedRecently: true,
          priceChecked: false,
        ),
        isNotNull,
      );
    });

    test('parses a valid comma-separated price', () {
      expect(ReviewFormValidator.validateMenu('김치찌개'), isNull);
      expect(ReviewFormValidator.validatePrice('8,000'), isNull);
      expect(ReviewFormValidator.parsePrice('8,000'), 8000);
      expect(ReviewFormValidator.validateContent('가격이 합리적이에요.'), isNull);
      expect(ReviewFormValidator.validateRating(5), isNull);
      expect(
        ReviewFormValidator.validateConfirmations(
          visitedRecently: true,
          priceChecked: true,
        ),
        isNull,
      );
    });
  });

  testWidgets('empty review stays empty and never reaches the API notifier', (
    tester,
  ) async {
    final notifier = _RecordingStoreReviewNotifier();
    await _pumpReviewScreen(tester, notifier);

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields, hasLength(3));
    expect(fields.every((field) => field.controller!.text.isEmpty), isTrue);

    await tester.tap(find.text('리뷰 등록하기'));
    await tester.pump();

    expect(notifier.submitCount, 0);
    expect(find.text('방문 메뉴를 입력해주세요.'), findsOneWidget);
    expect(find.text('실제 결제 가격을 입력해주세요.'), findsOneWidget);
    expect(find.text('리뷰 내용을 입력해주세요.'), findsOneWidget);
    expect(find.text('별점을 선택해주세요.'), findsOneWidget);
    expect(find.text('정말 좋은 매장이네요!'), findsNothing);
  });

  testWidgets('valid review is trimmed and rapid duplicate taps submit once', (
    tester,
  ) async {
    final notifier = _RecordingStoreReviewNotifier(
      pendingResult: Completer<bool>(),
    );
    await _pumpReviewScreen(tester, notifier);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  김치찌개  ');
    await tester.enterText(fields.at(1), '8,000');
    await tester.enterText(fields.at(2), '  가격이 합리적이에요.  ');
    await tester.tap(find.byIcon(Icons.star_rounded).last);
    tester.widget<Checkbox>(find.byType(Checkbox).at(0)).onChanged!(true);
    await tester.pump();
    tester.widget<Checkbox>(find.byType(Checkbox).at(1)).onChanged!(true);
    await tester.pump();

    final submitButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    submitButton.onPressed!();
    submitButton.onPressed!();
    await tester.pump();

    expect(notifier.submitCount, 1);
    expect(notifier.submittedReview?.menu, '김치찌개');
    expect(notifier.submittedReview?.price, 8000);
    expect(notifier.submittedReview?.content, '가격이 합리적이에요.');
    expect(notifier.submittedReview?.stars, 5);
    expect(find.text('등록 중...'), findsOneWidget);

    notifier.pendingResult!.complete(false);
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpReviewScreen(
  WidgetTester tester,
  _RecordingStoreReviewNotifier notifier,
) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  await ApiClient.setSessionToken('review-test-token');
  addTearDown(() => ApiClient.setSessionToken(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [storeReviewProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(home: ReviewWriteScreen(store: _sampleStore)),
    ),
  );
  await tester.pumpAndSettle();
}

final _sampleStore = Store(
  storeName: '테스트 식당',
  address: '서울시 테스트구',
  phoneNumber: '',
  industry: '한식',
  menu1: '기본 메뉴',
  price1: '9,000',
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: 37.5,
  longitude: 127.0,
  source: 'GOV',
);

class _RecordingStoreReviewNotifier extends StoreReviewNotifier {
  _RecordingStoreReviewNotifier({this.pendingResult});

  final Completer<bool>? pendingResult;
  int submitCount = 0;
  Review? submittedReview;

  @override
  Future<bool> addReview(Review review) {
    submitCount += 1;
    submittedReview = review;
    return pendingResult?.future ?? Future.value(false);
  }
}

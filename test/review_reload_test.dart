import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_reviews_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA #11: reviews written elsewhere (another device, the web) must appear
/// when a review screen is opened again, and a reload must not show
/// mismatched summary numbers while it runs.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'my reviews keep the loaded list while reloading and after a failure',
    () async {
      await ApiClient.setSessionToken('session');
      addTearDown(() => ApiClient.setSessionToken(null));
      final server = _ReviewServer([_review('a', 5), _review('b', 4)]);

      await http.runWithClient(() async {
        final notifier = MyReviewsNotifier();
        addTearDown(notifier.dispose);
        await notifier.loadReviews();
        expect(_ids(notifier.state), ['a', 'b']);

        server.reviews = [_review('c', 3), ...server.reviews];
        server.gate = Completer<void>();
        final reload = notifier.loadReviews(force: true);
        expect(notifier.state.isLoading, isTrue);
        expect(_ids(notifier.state), ['a', 'b']);
        server.gate!.complete();
        await reload;
        expect(_ids(notifier.state), ['c', 'a', 'b']);

        server.fails = true;
        await notifier.loadReviews(force: true);
        expect(notifier.state.hasError, isTrue);
        expect(_ids(notifier.state), ['c', 'a', 'b']);
      }, () => server.client);
    },
  );

  testWidgets('opening my reviews again shows a review written elsewhere', (
    tester,
  ) async {
    _usePhone(tester);
    await ApiClient.setSessionToken('session');
    addTearDown(() => ApiClient.setSessionToken(null));
    final server = _ReviewServer([_review('a', 5), _review('b', 4)]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Future<void> show(Widget child) => tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: child),
    );

    await http.runWithClient(() async {
      await show(const MaterialApp(home: MyReviewsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('총 2 개', findRichText: true), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);

      // Leave the screen. A review is written on the web meanwhile.
      await show(const SizedBox());
      server.reviews = [_review('c', 3), ...server.reviews];
      server.gate = Completer<void>();

      await show(const MaterialApp(home: MyReviewsScreen()));
      await tester.pump();
      await tester.pump();
      expect(server.requests, 2, reason: 'opening the screen reloads');
      // The reload keeps the last numbers instead of showing zeros.
      expect(find.text('총 2 개', findRichText: true), findsOneWidget);
      expect(find.text('2 개 작성', findRichText: true), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);

      server.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('총 3 개', findRichText: true), findsOneWidget);
      expect(find.text('3 개 작성', findRichText: true), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('리뷰 c'), findsOneWidget);
    }, () => server.client);
  });

  testWidgets('a failed pull to refresh keeps my reviews and says so', (
    tester,
  ) async {
    _usePhone(tester);
    await ApiClient.setSessionToken('session');
    addTearDown(() => ApiClient.setSessionToken(null));
    final server = _ReviewServer([_review('a', 5), _review('b', 4)]);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MyReviewsScreen())),
      );
      await tester.pumpAndSettle();

      server.fails = true;
      await tester.fling(find.text('리뷰 a'), const Offset(0, 400), 1200);
      await tester.pumpAndSettle();

      expect(find.text('리뷰 a'), findsOneWidget);
      expect(find.text('총 2 개', findRichText: true), findsOneWidget);
      expect(find.text('내 리뷰를 불러오지 못했어요.'), findsNothing);
      expect(find.text('내 리뷰를 새로고침하지 못했어요. 잠시 후 다시 시도해주세요.'), findsOneWidget);
    }, () => server.client);
  });

  for (final detail in [false, true]) {
    testWidgets(
      '${detail ? 'store detail' : 'store review list'} reloads on every visit',
      (tester) async {
        _usePhone(tester, height: 1500);
        await ApiClient.setSessionToken(null);
        final server = _ReviewServer([_review('a', 5, day: 1)]);
        final store = Store.fromJson({
          'storeId': 'store-1',
          'storeName': '구백년짜장',
          'address': '서울',
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        Widget screen() => MaterialApp(
          home: detail
              ? StoreDetailScreen(store: store)
              : ReviewListScreen(store: store),
        );
        Future<void> show(Widget child) => tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: child),
        );

        await http.runWithClient(() async {
          await show(screen());
          await tester.pumpAndSettle();
          expect(find.text('리뷰 a'), findsOneWidget);

          await show(const SizedBox());
          server.reviews = [_review('b', 4, day: 2), ...server.reviews];
          server.gate = Completer<void>();

          await show(screen());
          await tester.pump();
          await tester.pump();
          expect(server.reviewRequests, 2, reason: 'each visit reloads');
          // The reviews already loaded stay instead of a loading state.
          expect(find.text('리뷰 a'), findsOneWidget);
          expect(find.text('리뷰를 불러오고 있어요'), findsNothing);
          if (!detail) {
            expect(find.byType(CircularProgressIndicator), findsNothing);
          }

          server.gate!.complete();
          await tester.pumpAndSettle();
          expect(find.text('리뷰 b'), findsOneWidget);
          expect(find.text('리뷰 a'), findsOneWidget);
        }, () => server.client);
      },
    );
  }
}

List<String>? _ids(AsyncValue<List<Review>> state) =>
    state.valueOrNull?.map((review) => review.id).toList();

Map<String, Object?> _review(String id, int stars, {int day = 1}) => {
  'id': id,
  'storeId': 'store-1',
  'storeName': '구백년짜장',
  'storeSource': 'GOV',
  'authorName': '손님 $id',
  'stars': stars,
  'content': '리뷰 $id',
  'createdAt': DateTime.utc(2026, 10, day).toIso8601String(),
};

void _usePhone(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Answers review requests with [reviews]; other requests get a 404.
class _ReviewServer {
  _ReviewServer(this.reviews);

  List<Map<String, Object?>> reviews;

  /// While set, review responses wait until it completes.
  Completer<void>? gate;
  bool fails = false;
  int requests = 0;
  int reviewRequests = 0;

  http.Client get client => MockClient((request) async {
    requests++;
    if (!request.url.path.startsWith('/api/review')) {
      return http.Response('{}', 404);
    }
    reviewRequests++;
    await gate?.future;
    if (fails) return http.Response('{"message":"error"}', 503);
    return http.Response.bytes(utf8.encode(jsonEncode(reviews)), 200);
  });
}

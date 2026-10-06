import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const review = Review(
  storeId: 'store',
  authorName: 'user',
  stars: 5,
  content: 'new',
);
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'failed public review requests can be retried instead of cached as empty',
    () async {
      var calls = 0;
      final client = MockClient(
        (_) async => ++calls == 1
            ? http.Response('error', 500)
            : http.Response('[]', 200),
      );
      await http.runWithClient(() async {
        final notifier = StoreReviewNotifier();
        addTearDown(notifier.dispose);
        await notifier.loadReviews('store');
        expect(notifier.state['store']!.hasError, isTrue);
        await notifier.loadReviews('store');
        expect(calls, 2);
        expect(notifier.state['store']!.requireValue, isEmpty);
      }, () => client);
    },
  );
  test('a late list response retains a newly submitted review', () async {
    final response = Completer<http.Response>();
    final client = MockClient(
      (request) async => request.method == 'GET'
          ? response.future
          : http.Response('{"reviewId":"new"}', 200),
    );
    await http.runWithClient(() async {
      final notifier = StoreReviewNotifier();
      addTearDown(notifier.dispose);
      final load = notifier.loadReviews('store');
      expect(await notifier.addReview(review), isTrue);
      response.complete(
        http.Response(
          jsonEncode([
            {'id': 'old', 'storeId': 'store', 'stars': 3, 'content': 'old'},
          ]),
          200,
        ),
      );
      await load;
      expect(notifier.reviewsFor('store').map((r) => r.id), ['new', 'old']);
    }, () => client);
  });

  group('a review request without a response', () {
    const submitted = Review(
      storeId: 'store',
      authorName: 'user',
      stars: 4,
      menu: '칼국수',
      content: '국물이 진해요',
    );

    Future<(bool?, Object?, int)> submitWith(
      Future<http.Response> Function() myReviews,
    ) async {
      var posts = 0;
      bool? result;
      Object? error;
      await http.runWithClient(() async {
        final notifier = StoreReviewNotifier(
          submissionRecheckDelay: Duration.zero,
        );
        addTearDown(notifier.dispose);
        try {
          result = await notifier.addReview(submitted);
        } catch (caught) {
          error = caught;
        }
        if (result == true) {
          expect(notifier.reviewsFor('store').first.id, 'server-id');
        }
      }, () => MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          throw http.ClientException('connection lost after sending');
        }
        expect(request.url.path, '/api/review/me');
        return myReviews();
      }));
      return (result, error, posts);
    }

    test('counts as saved when the server already stored it', () async {
      final (result, error, posts) = await submitWith(
        () async => http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'id': 'server-id',
                'storeId': 'store',
                'menu': '칼국수',
                'content': '국물이 진해요',
                'stars': 4,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              },
            ]),
          ),
          200,
        ),
      );
      expect(result, isTrue);
      expect(error, isNull);
      expect(posts, 1);
    });

    test('is reported as failed when the server has no such review', () async {
      final (result, error, _) = await submitWith(
        () async => http.Response('[]', 200),
      );
      expect(result, isFalse);
      expect(error, isNull);
    });

    test('is reported as unconfirmed when the check also fails', () async {
      final (result, error, _) = await submitWith(
        () async => http.Response('{}', 503),
      );
      expect(result, isNull);
      expect(error, isA<ReviewSubmissionUnconfirmedException>());
    });
  });

  test('a saved review shows the author name chosen by the server', () async {
    await http.runWithClient(
      () async {
        final notifier = StoreReviewNotifier();
        addTearDown(notifier.dispose);
        expect(await notifier.addReview(review), isTrue);
        final saved = notifier.reviewsFor('store').single;
        expect(saved.id, 'r1');
        expect(saved.authorName, '익명');
      },
      () => MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({'success': true, 'reviewId': 'r1', 'authorName': '익명'}),
          ),
          200,
        ),
      ),
    );
  });

  test(
    'switching accounts discards personal providers and late review responses',
    () async {
      await ApiClient.setSessionToken('old-session');
      addTearDown(() => ApiClient.setSessionToken(null));
      final response = Completer<http.Response>();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final oldReviews = container.read(myReviewsProvider.notifier);
      final oldNotifications = container.read(notificationsProvider.notifier);
      final oldChat = container.read(aiChatHistoryProvider.notifier);
      await http.runWithClient(() async {
        final load = oldReviews.loadReviews();
        container.read(authStateProvider.notifier).state = const AuthState(
          isLoggedIn: true,
          provider: 'kakao',
          email: '',
          firebaseUid: 'new-user',
          sessionToken: 'new-session',
        );
        expect(
          container.read(myReviewsProvider.notifier),
          isNot(same(oldReviews)),
        );
        expect(
          container.read(notificationsProvider.notifier),
          isNot(same(oldNotifications)),
        );
        expect(
          container.read(aiChatHistoryProvider.notifier),
          isNot(same(oldChat)),
        );
        response.complete(http.Response('[{"id":"old-user-review"}]', 200));
        await expectLater(load, completes);
        expect(container.read(myReviewsProvider).valueOrNull, isNull);
      }, () => MockClient((_) => response.future));
    },
  );
}

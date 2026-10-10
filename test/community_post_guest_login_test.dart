import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/login_flow_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = 'community-guest-session';
const _typed = '아직 5000원이에요';
const _likeMessage = "'도움이 돼요'는 로그인 후 누를 수 있어요.";

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

/// Kakao login that succeeds at once and, like the real service, stores the
/// session and marks the visitor logged in.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(this.ref) : super(ref);

  final Ref ref;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    await ApiClient.setSessionToken(_session);
    ref
        .read(authStateProvider.notifier)
        .update(
          (state) => state.copyWith(isLoggedIn: true, sessionToken: _session),
        );
    return const KakaoLoginResult(KakaoLoginStatus.success);
  }
}

/// The community API as the backend serves it: anyone can read, a session
/// also gets its own like and alert state, and writes need a session. Likes
/// and alerts are set per account, so repeating one changes nothing.
class _Backend {
  _Backend({this.liked = false, this.alertsOn = false});

  bool liked;
  bool alertsOn;
  final writes = <http.Request>[];
  final _replies = <Map<String, Object?>>[];
  final _comments = <Map<String, Object?>>[
    {'id': 'c1', 'author': '민서', 'content': '원 댓글'},
  ];

  int get _likes => 2 + (liked ? 1 : 0);

  MockClient get client => MockClient((request) async {
    final member = request.headers['Authorization'] == 'Bearer $_session';
    if (request.method != 'GET') {
      if (!member) return _json({'message': '로그인이 필요해요.'}, 401);
      writes.add(request);
    }
    final content = request.body.isEmpty
        ? null
        : (jsonDecode(request.body) as Map)['content'];
    switch ((request.method, request.url.path)) {
      case ('GET', '/api/community/feed/p1'):
        return _json({
          'id': 'p1',
          'title': '동네 식당 국수 5000',
          'storeName': '동네 식당',
          'author': '다나',
          'location': '구로구',
          'status': 'APPROVED',
          'likes': _likes,
          'comments': _comments.length + _replies.length,
          'likedByMe': member && liked,
          'notificationEnabled': member && alertsOn,
        });
      case ('GET', '/api/community/feed/p1/comments'):
        return _json([
          for (final comment in _comments)
            if (comment['id'] == 'c1')
              {...comment, 'replyCount': _replies.length}
            else
              comment,
        ]);
      case ('POST', '/api/community/feed/p1/comments'):
        final created = {'id': 'c2', 'author': '나', 'content': content};
        _comments.add(created);
        return _json(created);
      case ('GET', '/api/community/comments/c1/replies'):
        return _json(_replies);
      case ('POST', '/api/community/comments/c1/replies'):
        final created = {'id': 'r1', 'author': '나', 'content': content};
        _replies.add(created);
        return _json(created);
      case (final method, '/api/community/feed/p1/like'):
        liked = method == 'POST';
        return _json({'likes': _likes, 'likedByMe': liked});
      case (final method, '/api/community/feed/p1/notification'):
        alertsOn = method == 'POST';
        return _json({'notificationEnabled': alertsOn});
    }
    return _json({}, 404);
  });

  List<String> get writeTargets => [
    for (final request in writes) '${request.method} ${request.url.path}',
  ];
}

Future<void> _pumpPost(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/post',
    routes: [
      GoRoute(
        path: '/post',
        builder: (_, _) => const CommunityPostDetailScreen(postId: 'p1'),
      ),
      GoRoute(
        path: AppRoutes.loginFlow,
        builder: (_, _) => const LoginFlowScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kakaoLoginServiceProvider.overrideWith(_FakeLoginService.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Checks that the prompt explains [message], then logs in with Kakao.
Future<void> _logInFromPrompt(WidgetTester tester, String message) async {
  expect(find.text('로그인이 필요해요'), findsOneWidget);
  expect(find.text(message), findsOneWidget);
  await tester.tap(find.byKey(const Key('login_required_confirm')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('카카오로 계속하기'));
  await tester.pumpAndSettle();
  expect(
    find.byType(LoginFlowScreen),
    findsNothing,
    reason: 'back on the post',
  );
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  // The send button turns on once the typed text is shown.
  await tester.pump();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

String _composerText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      authTermsAcceptedPreferenceKey: true,
    });
    await ApiClient.setSessionToken(null);
  });
  tearDown(() => ApiClient.setSessionToken(null));

  for (final kind in ['댓글', '답글']) {
    testWidgets('a guest\'s $kind is sent after logging in on the post', (
      tester,
    ) async {
      final backend = _Backend();
      await http.runWithClient(() async {
        await _pumpPost(tester);
        if (kind == '답글') {
          await tester.tap(find.text('답글'));
          await tester.pump();
        }
        await _send(tester, _typed);
        await _logInFromPrompt(tester, '$kind은 로그인 후 남길 수 있어요. 쓴 내용은 그대로 있어요.');

        expect(backend.writeTargets, [
          kind == '답글'
              ? 'POST /api/community/comments/c1/replies'
              : 'POST /api/community/feed/p1/comments',
        ]);
        expect(jsonDecode(backend.writes.single.body), {'content': _typed});
        expect(find.text(_typed), findsOneWidget, reason: 'shown on the post');
        expect(_composerText(tester), isEmpty);
        expect(find.text('민서님에게 답글'), findsNothing);
      }, () => backend.client);
    });
  }

  for (final likedBefore in [false, true]) {
    testWidgets(
      likedBefore
          ? 'logging in to like keeps the account\'s earlier like'
          : 'a guest\'s like is applied after logging in',
      (tester) async {
        final backend = _Backend(liked: likedBefore);
        await http.runWithClient(() async {
          await _pumpPost(tester);
          // A guest sees the count, never their own like.
          expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
          await tester.tap(find.text('도움이 돼요 ${likedBefore ? 3 : 2}'));
          await tester.pumpAndSettle();
          await _logInFromPrompt(tester, _likeMessage);

          expect(backend.writeTargets, [
            if (!likedBefore) 'POST /api/community/feed/p1/like',
          ]);
          expect(backend.liked, isTrue);
          expect(find.text('도움이 돼요 3'), findsOneWidget);
          expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
        }, () => backend.client);
      },
    );
  }

  for (final alertsBefore in [false, true]) {
    testWidgets(
      alertsBefore
          ? 'logging in for alerts keeps the account\'s alerts on'
          : 'a guest turns on new comment alerts by logging in',
      (tester) async {
        final backend = _Backend(alertsOn: alertsBefore);
        await http.runWithClient(() async {
          await _pumpPost(tester);
          await tester.tap(find.text('새 댓글 알림'));
          await tester.pumpAndSettle();
          await _logInFromPrompt(tester, '새 댓글 알림은 로그인 후 받을 수 있어요.');

          expect(backend.writeTargets, [
            if (!alertsBefore) 'POST /api/community/feed/p1/notification',
          ]);
          expect(backend.alertsOn, isTrue);
          expect(find.text('알림 켜짐'), findsOneWidget);
        }, () => backend.client);
      },
    );
  }

  testWidgets('choosing later leaves the guest on the post with the text', (
    tester,
  ) async {
    final backend = _Backend();
    await http.runWithClient(() async {
      await _pumpPost(tester);
      await _send(tester, _typed);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();

      expect(_composerText(tester), _typed);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason: 'can still send it',
      );

      await tester.tap(find.text('도움이 돼요 2'));
      await tester.pumpAndSettle();
      expect(find.text(_likeMessage), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginFlowScreen), findsNothing);
      expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
      expect(backend.writes, isEmpty);
      expect(ApiClient.isAuthenticated, isFalse);
    }, () => backend.client);
  });
}

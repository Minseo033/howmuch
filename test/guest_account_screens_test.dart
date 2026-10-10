import 'dart:async';
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
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_inquiries_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_reviews_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_report_dashboard_screen.dart';
import 'package:howmuch/features/system/presentation/screens/notifications_screen.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account screens a guest can open: logging in from their login button
/// happens on top of the screen and comes back to it with the account's data.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      authTermsAcceptedPreferenceKey: true,
    });
    await ApiClient.setSessionToken(null);
  });
  tearDown(() => ApiClient.setSessionToken(null));

  group('savings report', () {
    Object savings(String path) {
      if (path.endsWith('/api/savings/stats')) {
        return {'totalSavedAmount': 12000, 'totalVisits': 3, 'chartItems': []};
      }
      if (path.endsWith('/api/savings/goal')) return {'goalAmount': 50000};
      return []; // favorites and my reports
    }

    testWidgets('a guest logs in on the report and sees their savings', (
      tester,
    ) async {
      final server = _Server(savings);
      await http.runWithClient(() async {
        await _pumpAsGuest(tester, const SavingsReportDashboardScreen());

        await _openLoginAndLeave(tester);
        expect(find.text('절약 리포트를 보려면 로그인해주세요'), findsOneWidget);
        expect(server.requests, isEmpty);

        await _logInFromButton(tester);
        expect(find.byType(SavingsReportDashboardScreen), findsOneWidget);
        expect(find.text('로그인이 필요해요'), findsNothing);
        expect(find.text('목표 대비 24% 달성'), findsOneWidget);
      }, () => server.client);
    });

    testWidgets('a guest setting a goal logs in first, then sets it', (
      tester,
    ) async {
      final server = _Server(savings);
      await http.runWithClient(() async {
        await _pumpAsGuest(
          tester,
          const SavingsReportDashboardScreen(),
          routes: [
            GoRoute(
              path: AppRoutes.savingsGoalSetting,
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('목표 화면 닫기'),
                ),
              ),
            ),
          ],
        );

        await tester.tap(find.text('목표 설정'));
        await tester.pumpAndSettle();
        expect(find.text('절약 목표는 로그인하면 설정할 수 있어요.'), findsOneWidget);
        await tester.tap(find.text('나중에'));
        await tester.pumpAndSettle();
        expect(find.text('목표 화면 닫기'), findsNothing);
        expect(server.requests, isEmpty);

        await tester.tap(find.text('목표 설정'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_required_confirm')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pumpAndSettle();
        expect(find.text('목표 화면 닫기'), findsOneWidget);

        await tester.tap(find.text('목표 화면 닫기'));
        await tester.pumpAndSettle();
        expect(find.text('목표 대비 24% 달성'), findsOneWidget);
      }, () => server.client);
    });

    testWidgets('logging in from the inbox reloads the report on return', (
      tester,
    ) async {
      final server = _Server(savings);
      await http.runWithClient(() async {
        await _pumpAsGuest(
          tester,
          const SavingsReportDashboardScreen(),
          routes: [
            GoRoute(
              path: AppRoutes.notifications,
              builder: (context, _) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => openLoginFlow(context),
                      child: const Text('알림에서 로그인'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('알림 닫기'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        await tester.tap(find.byIcon(Icons.notifications_none_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('알림에서 로그인'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('알림 닫기'));
        await tester.pumpAndSettle();

        expect(find.text('로그인이 필요해요'), findsNothing);
        expect(find.text('목표 대비 24% 달성'), findsOneWidget);
      }, () => server.client);
    });

    testWidgets('a goal saved while the report still loads after login is '
        'the one shown', (tester) async {
      var goal = 50000;
      var holdAnswers = true;
      final firstLoad = Completer<void>();
      // The report that starts loading at login reads the goal before the
      // save, and its answers arrive only after the save.
      final client = MockClient((request) async {
        if (request.headers['Authorization'] != 'Bearer $_session') {
          return http.Response('{}', 401);
        }
        final path = request.url.path;
        final body = path.endsWith('/api/savings/goal')
            ? {'goalAmount': goal}
            : savings(path);
        if (holdAnswers) await firstLoad.future;
        return http.Response(jsonEncode(body), 200);
      });
      await http.runWithClient(() async {
        await _pumpAsGuest(
          tester,
          const SavingsReportDashboardScreen(),
          routes: [
            GoRoute(
              path: AppRoutes.savingsGoalSetting,
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    goal = 100000;
                    context.pop(goal);
                  },
                  child: const Text('10만 원으로 저장'),
                ),
              ),
            ),
          ],
        );

        await tester.tap(find.text('목표 설정'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_required_confirm')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pumpAndSettle();

        holdAnswers = false;
        await tester.tap(find.text('10만 원으로 저장'));
        await tester.pump();
        firstLoad.complete();
        await tester.pumpAndSettle();

        // 12,000원 of 100,000원, not of the old 50,000원 (24%).
        expect(find.text('목표 대비 12% 달성'), findsOneWidget);
      }, () => client);
    });
  });

  testWidgets('a guest logs in on the inbox and sees their notifications', (
    tester,
  ) async {
    final server = _Server(
      (_) => [
        {
          'id': 'n1',
          'title': '문의 답변',
          'body': '문의에 답변이 달렸어요',
          'type': 'inquiry',
        },
      ],
    );
    await _pumpAsGuest(
      tester,
      const NotificationsScreen(),
      overrides: [
        notificationApiServiceProvider.overrideWithValue(
          NotificationApiService(server.client),
        ),
      ],
    );

    await _openLoginAndLeave(tester);
    expect(
      find.text('로그인하면 가격 변동, 제보 결과, 댓글, 문의 답변 알림을 볼 수 있어요.'),
      findsOneWidget,
    );
    expect(server.requests, isEmpty);

    await _logInFromButton(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('문의에 답변이 달렸어요'), findsOneWidget);
    expect(server.requests, ['/api/notifications']);
  });

  testWidgets('a guest logs in on notification settings and sees theirs', (
    tester,
  ) async {
    final server = _Server(
      (_) => {
        'all': false,
        'review': true,
        'report': true,
        'price': false,
        'todayPick': false,
        'quietHours': true,
        'quietStart': '23:30',
        'quietEnd': '07:00',
      },
    );
    await _pumpAsGuest(
      tester,
      const NotificationSettingsScreen(),
      overrides: [
        notificationSettingsApiServiceProvider.overrideWithValue(
          NotificationSettingsApiService(server.client),
        ),
      ],
    );
    expect(find.text('로그인한 뒤 알림 설정을 변경할 수 있어요.'), findsOneWidget);
    final guestRequests = server.requests.length;

    await _openLoginAndLeave(tester);
    expect(find.text('로그인한 뒤 알림 설정을 변경할 수 있어요.'), findsOneWidget);
    expect(server.requests, hasLength(guestRequests));

    await _logInFromButton(tester);
    expect(find.text('오후 11:30'), findsOneWidget);
    expect(server.requests, hasLength(guestRequests + 1));
  });

  testWidgets('a guest logs in on my reviews and sees their reviews', (
    tester,
  ) async {
    final server = _Server(
      (_) => [
        {
          'id': 'r1',
          'storeId': 'store-1',
          'storeName': '구백년짜장',
          'storeSource': 'GOV',
          'authorName': '손님',
          'stars': 4,
          'content': '짜장면이 맛있어요',
          'createdAt': '2026-10-09T03:00:00Z',
        },
      ],
    );
    await http.runWithClient(() async {
      await _pumpAsGuest(tester, const MyReviewsScreen());

      await _openLoginAndLeave(tester);
      expect(find.text('내가 작성한 리뷰는 로그인 후 확인할 수 있어요.'), findsOneWidget);
      expect(server.requests, isEmpty);

      await _logInFromButton(tester);
      expect(find.text('짜장면이 맛있어요'), findsOneWidget);
      expect(find.text('총 1 개', findRichText: true), findsOneWidget);
    }, () => server.client);
  });

  testWidgets('a guest logs in on my inquiries and sees their inquiries', (
    tester,
  ) async {
    final server = _Server(
      (_) => [
        {
          'id': 'q1',
          'title': '영업시간이 달라요',
          'content': '토요일에도 문을 열어요.',
          'category': '매장 정보 오류',
          'status': 'PENDING',
          'createdAt': '2026-10-09T03:00:00Z',
        },
      ],
    );
    await _pumpAsGuest(
      tester,
      const MyInquiriesScreen(),
      overrides: [
        inquiryServiceProvider.overrideWithValue(InquiryService(server.client)),
      ],
    );
    expect(find.text('내가 남긴 문의와 답변은 로그인 후 확인할 수 있어요.'), findsOneWidget);
    final guestRequests = server.requests.length;

    await _openLoginAndLeave(tester);
    expect(find.text('내가 남긴 문의와 답변은 로그인 후 확인할 수 있어요.'), findsOneWidget);
    expect(server.requests, hasLength(guestRequests));

    await _logInFromButton(tester);
    expect(find.text('영업시간이 달라요'), findsOneWidget);
    expect(server.requests, hasLength(guestRequests + 1));
  });

  // A new account whose profile request fails is logged in for a moment and
  // then a guest again, and login comes back with a guest. Every account
  // screen ends on its login prompt, never on a spinner.
  for (final (name, screen, prompt) in [
    ('my reviews', const MyReviewsScreen(), '내가 작성한 리뷰는 로그인 후 확인할 수 있어요.'),
    (
      'notifications',
      const NotificationsScreen(),
      '로그인하면 가격 변동, 제보 결과, 댓글, 문의 답변 알림을 볼 수 있어요.',
    ),
    (
      'notification settings',
      const NotificationSettingsScreen(),
      '로그인한 뒤 알림 설정을 변경할 수 있어요.',
    ),
    (
      'my inquiries',
      const MyInquiriesScreen(),
      '내가 남긴 문의와 답변은 로그인 후 확인할 수 있어요.',
    ),
    (
      'savings report',
      const SavingsReportDashboardScreen(),
      '절약 리포트를 보려면 로그인해주세요',
    ),
  ]) {
    testWidgets('$name asks for login again after a login that ends as a '
        'guest', (tester) async {
      final server = _Server(_accountData);
      await http.runWithClient(() async {
        await _pumpAsGuest(
          tester,
          screen,
          login: _LoginEndingAsGuest.new,
          overrides: _accountServices(server),
        );
        await tester.tap(find.text('로그인하기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('나중에 할게요'));
        await tester.pumpAndSettle();

        expect(ApiClient.isAuthenticated, isFalse);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(prompt), findsOneWidget);
        expect(find.text('로그인하기'), findsOneWidget);
      }, () => server.client);
    });
  }

  // Logging in can't help a member the server turns down: login would come
  // straight back. They get the screen's error with a retry instead.
  for (final (name, screen, error, loaded) in [
    (
      'notifications',
      const NotificationsScreen(),
      '알림을 불러오지 못했어요',
      '문의에 답변이 달렸어요',
    ),
    (
      'notification settings',
      const NotificationSettingsScreen(),
      '설정을 불러오지 못했어요',
      '오후 11:30',
    ),
    (
      'my inquiries',
      const MyInquiriesScreen(),
      '문의 내역을 불러오지 못했어요',
      '영업시간이 달라요',
    ),
  ]) {
    testWidgets('$name offers a member turned down with 403 a retry', (
      tester,
    ) async {
      final server = _Server(_accountData)..memberStatus = 403;
      await _pumpAsMember(tester, screen, overrides: _accountServices(server));

      expect(find.text(error), findsOneWidget);
      expect(find.text('로그인하기'), findsNothing);

      server.memberStatus = 200;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text(loaded), findsOneWidget);
    });
  }

  // Kakao can answer after the visitor already closed login. The account
  // then changes under a screen that shows the guest's login prompt, and the
  // screen shows the account's data without another tap.
  for (final (name, screen, loaded) in [
    ('my reviews', const MyReviewsScreen(), '짜장면이 맛있어요'),
    ('notifications', const NotificationsScreen(), '문의에 답변이 달렸어요'),
    ('notification settings', const NotificationSettingsScreen(), '오후 11:30'),
    ('my inquiries', const MyInquiriesScreen(), '영업시간이 달라요'),
  ]) {
    testWidgets('$name shows the account when a login finishes after the '
        'visitor left login', (tester) async {
      final server = _Server(_accountData);
      await http.runWithClient(() async {
        await _pumpAsGuest(tester, screen, overrides: _accountServices(server));
        expect(find.text('로그인하기'), findsOneWidget);

        await ApiClient.setSessionToken(_session);
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
            .read(authStateProvider.notifier)
            .update(
              (state) => state.copyWith(
                isLoggedIn: true,
                provider: '카카오',
                firebaseUid: 'account-uid',
                sessionToken: _session,
              ),
            );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(loaded), findsOneWidget);
      }, () => server.client);
    });
  }
}

const _session = 'account-session';

/// Kakao login that succeeds at once. Like the real service it stores the
/// session and updates the login state that account screens follow.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(this.ref) : super(ref);

  final Ref ref;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    await ApiClient.setSessionToken(_session);
    ref
        .read(authStateProvider.notifier)
        .update(
          (state) => state.copyWith(
            isLoggedIn: true,
            provider: '카카오',
            firebaseUid: 'account-uid',
            sessionToken: _session,
          ),
        );
    return const KakaoLoginResult(KakaoLoginStatus.success);
  }
}

/// Kakao login for a new account whose profile request fails. Like the real
/// service, it logs the visitor in, ends the session again and reports the
/// failure, so login comes back with a guest.
class _LoginEndingAsGuest extends KakaoLoginService {
  _LoginEndingAsGuest(this.ref) : super(ref);

  final Ref ref;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    await ApiClient.setSessionToken(_session);
    ref
        .read(authStateProvider.notifier)
        .update(
          (state) => state.copyWith(
            isLoggedIn: true,
            provider: '카카오',
            firebaseUid: 'new-account-uid',
            sessionToken: _session,
          ),
        );
    await clearLocalSession(unregisterDevice: false);
    return const KakaoLoginResult(
      KakaoLoginStatus.failed,
      '로그인 중 통신 오류가 발생했습니다.',
    );
  }
}

/// Answers the logged-in account with [data] and turns a guest down with a
/// 401, recording the path of every request that reaches it.
class _Server {
  _Server(this.data);

  final Object Function(String path) data;
  final requests = <String>[];

  /// The status the account gets; anything but 200 comes without [data].
  int memberStatus = 200;

  http.Client get client => MockClient((request) async {
    requests.add(request.url.path);
    if (request.headers['Authorization'] != 'Bearer $_session') {
      return http.Response('{}', 401);
    }
    if (memberStatus != 200) return http.Response('{}', memberStatus);
    return http.Response.bytes(
      utf8.encode(jsonEncode(data(request.url.path))),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// What the account has on each screen that loads through a service.
Object _accountData(String path) => switch (path) {
  '/api/review/me' => [
    {
      'id': 'r1',
      'storeId': 'store-1',
      'storeName': '구백년짜장',
      'storeSource': 'GOV',
      'authorName': '손님',
      'stars': 4,
      'content': '짜장면이 맛있어요',
      'createdAt': '2026-10-09T03:00:00Z',
    },
  ],
  '/api/notifications' => [
    {'id': 'n1', 'title': '문의 답변', 'body': '문의에 답변이 달렸어요', 'type': 'inquiry'},
  ],
  '/api/notifications/settings' => {
    'all': false,
    'review': true,
    'report': true,
    'price': false,
    'todayPick': false,
    'quietHours': true,
    'quietStart': '23:30',
    'quietEnd': '07:00',
  },
  '/api/inquiry/my' => [
    {
      'id': 'q1',
      'title': '영업시간이 달라요',
      'content': '토요일에도 문을 열어요.',
      'category': '매장 정보 오류',
      'status': 'PENDING',
      'createdAt': '2026-10-09T03:00:00Z',
    },
  ],
  _ => const <Object>[],
};

/// The services of the inbox, notification settings and inquiries, all
/// answered by [server].
List<Override> _accountServices(_Server server) => [
  notificationApiServiceProvider.overrideWithValue(
    NotificationApiService(server.client),
  ),
  notificationSettingsApiServiceProvider.overrideWithValue(
    NotificationSettingsApiService(server.client),
  ),
  inquiryServiceProvider.overrideWithValue(InquiryService(server.client)),
];

/// Opens [screen] as a guest, with the real login screen to log in from.
Future<void> _pumpAsGuest(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  List<RouteBase> routes = const [],
  KakaoLoginService Function(Ref ref) login = _FakeLoginService.new,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/account',
    routes: [
      GoRoute(path: '/account', builder: (_, _) => screen),
      GoRoute(
        path: AppRoutes.loginFlow,
        builder: (_, _) => const LoginFlowScreen(),
      ),
      ...routes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [kakaoLoginServiceProvider.overrideWith(login), ...overrides],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens [screen] for a logged-in member.
Future<void> _pumpAsMember(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  await ApiClient.setSessionToken(_session);
  await _pumpAsGuest(
    tester,
    screen,
    overrides: [
      authStateProvider.overrideWith(
        (ref) => const AuthState(
          isLoggedIn: true,
          provider: '카카오',
          email: '',
          firebaseUid: 'account-uid',
          sessionToken: _session,
        ),
      ),
      ...overrides,
    ],
  );
}

/// Opens login from the screen's button and leaves it again.
Future<void> _openLoginAndLeave(WidgetTester tester) async {
  await tester.tap(find.text('로그인하기'));
  await tester.pumpAndSettle();
  expect(find.text('카카오로 계속하기'), findsOneWidget);
  await tester.tap(find.text('나중에 할게요'));
  await tester.pumpAndSettle();
}

Future<void> _logInFromButton(WidgetTester tester) async {
  await tester.tap(find.text('로그인하기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('카카오로 계속하기'));
  await tester.pumpAndSettle();
}

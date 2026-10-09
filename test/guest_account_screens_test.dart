import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
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

/// Answers the logged-in account with [data] and turns a guest down with a
/// 401, recording the path of every request that reaches it.
class _Server {
  _Server(this.data);

  final Object Function(String path) data;
  final requests = <String>[];

  http.Client get client => MockClient((request) async {
    requests.add(request.url.path);
    if (request.headers['Authorization'] != 'Bearer $_session') {
      return http.Response('{}', 401);
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(data(request.url.path))),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// Opens [screen] as a guest, with the real login screen to log in from.
Future<void> _pumpAsGuest(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  List<RouteBase> routes = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/account',
    routes: [
      GoRoute(path: '/account', builder: (_, _) => screen),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, state) => LoginScreen(entry: loginEntryOf(state.extra)),
      ),
      ...routes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kakaoLoginServiceProvider.overrideWith(_FakeLoginService.new),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
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

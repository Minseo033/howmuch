import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_route_observer.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/login_flow_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = 'member-session';

/// Kakao login that succeeds at once and, like the real service, marks the
/// visitor as logged in.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(super.ref) : _authRef = ref;

  final Ref _authRef;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    await ApiClient.setSessionToken(_session);
    _authRef.read(authStateProvider.notifier).state = const AuthState(
      isLoggedIn: true,
      provider: '카카오',
      email: 'saver@example.com',
      sessionToken: _session,
    );
    return const KakaoLoginResult(KakaoLoginStatus.success);
  }
}

/// The account has one report.
class _AccountReports extends ReportService {
  _AccountReports() : super(MockClient((_) async => http.Response('', 500)));

  @override
  Future<List<UserReportStatus>?> fetchMyReports() async => [
    UserReportStatus.fromJson({
      'id': 'report-1',
      'storeName': '정장군숯불구이',
      'menu1': '한식',
      'price1': '6500',
      'status': 'PENDING',
      'createdAt': '2026-10-01T03:00:00Z',
    }),
  ];
}

/// A phone that supports pushes but has not allowed them yet.
class _PhonePermissions extends DevicePermissionService {
  @override
  bool get supportsPush => true;

  @override
  Future<DeviceAccess> location() async => DeviceAccess.allowed;

  @override
  Future<DeviceAccess> push() async => DeviceAccess.denied;
}

class _RecordingPush extends PushNotificationService {
  _RecordingPush(super.ref, this.registrations);

  final List<String?> registrations;

  @override
  Future<bool> registerForCurrentSession() async {
    registrations.add(ApiClient.sessionToken);
    return true;
  }
}

class _RecordingInquiries extends InquiryService {
  final sent = <String>[];

  @override
  Future<Map<String, dynamic>> createInquiry({
    required String title,
    required String content,
    String? category,
    List<String> imageUrls = const [],
  }) async {
    sent.add('$title / $content / $category / ${ApiClient.sessionToken}');
    return const {'id': 'inquiry-1'};
  }

  @override
  Future<List<Inquiry>> getMyInquiries() async => const [];
}

/// The server answers a guest with 401 and an account with its alerts.
class _AccountPriceAlerts extends PriceAlertApiService {
  _AccountPriceAlerts()
    : super(MockClient((_) async => http.Response('{}', 500)));

  var fetches = 0;

  @override
  Future<PriceAlertSettings> fetchSettings() async {
    fetches++;
    if (!ApiClient.isAuthenticated) {
      throw const PriceAlertApiException(
        '가격 알림을 사용하려면 로그인이 필요합니다.',
        statusCode: 401,
      );
    }
    return const PriceAlertSettings(
      all: true,
      stores: [
        PriceAlertStore(
          storeId: 'store-1',
          storeName: '착한식당 1호점',
          menuName: '비빔밥 5,000원',
          enabled: true,
        ),
      ],
      notifyOnRise: true,
      notifyOnDrop: true,
      notifyOnNewMenu: false,
    );
  }
}

/// Screens MY opens, standing in for the real ones.
const _mypageDestinations = [
  AppRoutes.myReportsV2,
  AppRoutes.favoriteStores,
  AppRoutes.myReviews,
  AppRoutes.visitHistory,
  AppRoutes.notificationSettings,
  AppRoutes.accountManagement,
  AppRoutes.notifications,
  AppRoutes.publicDataSource,
  AppRoutes.inquiry,
  AppRoutes.profileEdit,
  AppRoutes.savingsReportDashboard,
];

GoRoute _loginRoute() => GoRoute(
  path: AppRoutes.loginFlow,
  builder: (_, _) => const LoginFlowScreen(),
);

ProviderScope _app(GoRouter router, List<Override> overrides) => ProviderScope(
  overrides: [
    kakaoLoginServiceProvider.overrideWith((ref) => _FakeLoginService(ref)),
    ...overrides,
  ],
  child: MaterialApp.router(routerConfig: router),
);

void _phone(WidgetTester tester, {double height = 844}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, height);
  addTearDown(tester.view.reset);
}

/// A tappable MY row or shortcut. The profile card repeats some labels as
/// plain text.
Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell));

Future<void> _tapKakaoLogin(WidgetTester tester) async {
  await tester.tap(find.text('카카오로 계속하기'));
  await tester.pumpAndSettle();
}

/// Opens MY as a guest. The server answers account requests for the session
/// the fake login creates, and [requests] records their paths. The body gets
/// the sessions this device registered for pushes with.
Future<void> _withGuestMypage(
  WidgetTester tester,
  Future<void> Function(GoRouter router, List<String?> pushRegistrations)
  body, {
  List<String>? requests,
}) async {
  // Tall enough to reach every MY row without scrolling.
  _phone(tester, height: 1200);
  await http.runWithClient(
    () async {
      final observer = RouteObserver<PageRoute<dynamic>>();
      final router = GoRouter(
        initialLocation: AppRoutes.mypage,
        observers: [observer],
        routes: [
          GoRoute(
            path: AppRoutes.mypage,
            builder: (_, _) => const MypageScreen(),
          ),
          _loginRoute(),
          for (final path in _mypageDestinations)
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text('도착 $path')),
            ),
        ],
      );
      addTearDown(router.dispose);
      final pushRegistrations = <String?>[];
      await tester.pumpWidget(
        _app(router, [
          appRouteObserverProvider.overrideWithValue(observer),
          reportServiceProvider.overrideWithValue(_AccountReports()),
          devicePermissionServiceProvider.overrideWithValue(
            _PhonePermissions(),
          ),
          pushNotificationServiceProvider.overrideWith(
            (ref) => _RecordingPush(ref, pushRegistrations),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await body(router, pushRegistrations);
    },
    () => MockClient((request) async {
      requests?.add(request.url.path);
      final Object body = switch (request.url.path) {
        '/api/user/profile' => {
          'nickname': '알뜰한 민',
          'email': 'saver@example.com',
          'region': '서울',
        },
        '/api/savings/stats' => {'totalSavedAmount': 12000, 'totalVisits': 3},
        '/api/favorites' => [
          {'storeId': 'store-1'},
          {'storeId': 'store-2'},
        ],
        _ => const <String, Object>{},
      };
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    }),
  );
}

Future<_RecordingInquiries> _pumpInquiry(WidgetTester tester) async {
  _phone(tester);
  final inquiries = _RecordingInquiries();
  final router = GoRouter(
    initialLocation: AppRoutes.mypage,
    routes: [
      GoRoute(
        path: AppRoutes.mypage,
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(AppRoutes.inquiry),
            child: const Text('문의 열기'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.inquiry,
        builder: (_, _) => const InquiryScreen(),
      ),
      GoRoute(
        path: AppRoutes.inquiryHistory,
        builder: (_, _) => const Scaffold(body: Text('도착 내 문의 내역')),
      ),
      _loginRoute(),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _app(router, [inquiryServiceProvider.overrideWithValue(inquiries)]),
  );
  await tester.tap(find.text('문의 열기'));
  await tester.pumpAndSettle();
  return inquiries;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      authTermsAcceptedPreferenceKey: true,
    });
    await ApiClient.setSessionToken(null);
  });
  tearDown(() => ApiClient.setSessionToken(null));

  group('MY', () {
    testWidgets('a guest logs in from the profile card and MY shows the '
        'account', (tester) async {
      final requests = <String>[];
      await _withGuestMypage(tester, requests: requests, (_, _) async {
        expect(find.text('게스트'), findsOneWidget);
        expect(find.text('로그인하면 기록이 남아요'), findsOneWidget);
        expect(find.text('로그인하면 보낸 제보의 처리 상태를 볼 수 있어요'), findsOneWidget);
        expect(requests, isEmpty, reason: 'a guest has no account to load');

        await tester.tap(
          find.byKey(const ValueKey('mypage-profile-login-button')),
        );
        await tester.pumpAndSettle();
        // The button names the action, so login opens without a prompt.
        expect(find.text('로그인이 필요해요'), findsNothing);
        await _tapKakaoLogin(tester);

        expect(find.byType(LoginFlowScreen), findsNothing);
        expect(find.text('알뜰한 민'), findsOneWidget);
        expect(find.text('saver@example.com'), findsOneWidget);
        expect(find.text('12,000원'), findsOneWidget);
        expect(find.text('1건'), findsOneWidget);
        expect(find.text('2곳'), findsOneWidget);
        expect(find.text('정장군숯불구이'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mypage-profile-edit-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mypage-profile-login-button')),
          findsNothing,
        );
      });
    });

    testWidgets('account-only entries ask a guest to log in, and later keeps '
        'them on MY with nothing turned on', (tester) async {
      final semantics = tester.ensureSemantics();
      await _withGuestMypage(tester, (_, pushRegistrations) async {
        final entries = <String, Finder>{
          '내 제보': _row('내 제보'),
          '찜한 매장': _row('찜한 매장'),
          '내 리뷰': _row('내 리뷰'),
          '방문 기록': _row('방문 기록'),
          '알림 설정 바로가기': _row('알림 설정').first,
          '알림 설정 메뉴': _row('알림 설정').last,
          '계정 관리': _row('계정 관리'),
          '내 제보 전체보기': find.text('전체보기'),
          '알림함': find.bySemanticsLabel('알림'),
          '계정 설정': find.bySemanticsLabel('계정 설정'),
          '이 기기 푸시 알림': _row('이 기기 푸시 알림'),
        };
        for (final MapEntry(key: name, value: entry) in entries.entries) {
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(find.text('로그인이 필요해요'), findsOneWidget, reason: name);

          await tester.tap(find.text('나중에'));
          await tester.pumpAndSettle();
          expect(find.textContaining('도착'), findsNothing, reason: name);
          expect(find.byType(LoginFlowScreen), findsNothing, reason: name);
        }
        expect(pushRegistrations, isEmpty);
        expect(find.textContaining('푸시 알림을 켜지 못했어요'), findsNothing);
      });
      semantics.dispose();
    });

    testWidgets('a guest who logs in from an entry lands on it, and MY shows '
        'the account on return', (tester) async {
      await _withGuestMypage(tester, (router, _) async {
        await tester.tap(_row('찜한 매장'));
        await tester.pumpAndSettle();
        expect(find.text('로그인하면 찜한 매장을 모아 볼 수 있어요.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('login_required_confirm')));
        await tester.pumpAndSettle();
        await _tapKakaoLogin(tester);

        expect(find.text('도착 ${AppRoutes.favoriteStores}'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('알뜰한 민'), findsOneWidget);
        expect(find.text('2곳'), findsOneWidget);
      });
    });

    for (final (label, path) in [
      ('공공데이터 출처 안내', AppRoutes.publicDataSource),
      ('문의하기', AppRoutes.inquiry),
      ('절약 리포트', AppRoutes.savingsReportDashboard),
    ]) {
      testWidgets('$label opens for a guest without a login prompt', (
        tester,
      ) async {
        await _withGuestMypage(tester, (_, _) async {
          await tester.tap(_row(label));
          await tester.pumpAndSettle();
          expect(find.text('로그인이 필요해요'), findsNothing);
          expect(find.text('도착 $path'), findsOneWidget);
        });
      });
    }
  });

  group('inquiry', () {
    testWidgets('later keeps a guest on the form with nothing sent', (
      tester,
    ) async {
      final inquiries = await _pumpInquiry(tester);
      await tester.enterText(find.byType(TextField).at(0), '지도 오류');
      await tester.enterText(find.byType(TextField).at(1), '매장 위치가 달라요');
      await tester.tap(find.text('문의 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('문의는 로그인 후 보낼 수 있어요. 작성한 내용은 그대로 있어요.'), findsOneWidget);

      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(inquiries.sent, isEmpty);
      expect(find.byType(InquiryScreen), findsOneWidget);
      expect(find.text('지도 오류'), findsOneWidget);
      expect(find.text('매장 위치가 달라요'), findsOneWidget);
    });

    testWidgets('a guest who logs in at send sends the inquiry they wrote', (
      tester,
    ) async {
      final inquiries = await _pumpInquiry(tester);
      await tester.tap(find.text('기타'));
      await tester.enterText(find.byType(TextField).at(0), '지도 오류');
      await tester.enterText(find.byType(TextField).at(1), '매장 위치가 달라요');
      await tester.tap(find.text('문의 보내기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login_required_confirm')));
      await tester.pumpAndSettle();
      await _tapKakaoLogin(tester);

      expect(inquiries.sent, ['지도 오류 / 매장 위치가 달라요 / 기타 / $_session']);
      expect(find.byType(InquiryScreen), findsNothing);
      expect(find.text('문의가 접수되었어요.'), findsOneWidget);
    });

    testWidgets('a guest opens their inquiry history after logging in', (
      tester,
    ) async {
      await _pumpInquiry(tester);
      await tester.tap(find.byTooltip('내 문의 내역'));
      await tester.pumpAndSettle();
      expect(find.text('로그인하면 보낸 문의와 답변을 볼 수 있어요.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('login_required_confirm')));
      await tester.pumpAndSettle();
      await _tapKakaoLogin(tester);

      expect(find.text('도착 내 문의 내역'), findsOneWidget);
    });
  });

  testWidgets('price alerts offer a guest login and show the account\'s '
      'alerts after it', (tester) async {
    _phone(tester);
    final alerts = _AccountPriceAlerts();
    final router = GoRouter(
      initialLocation: AppRoutes.priceAlertSubscription,
      routes: [
        GoRoute(
          path: AppRoutes.priceAlertSubscription,
          builder: (_, _) => const PriceAlertSubscriptionScreen(),
        ),
        GoRoute(
          path: AppRoutes.notificationSettings,
          builder: (_, _) => const Scaffold(body: Text('도착 알림 설정')),
        ),
        _loginRoute(),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _app(router, [priceAlertApiServiceProvider.overrideWithValue(alerts)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('로그인하면 찜한 매장의 가격 변동 알림을 받을 수 있어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);

    await tester.tap(find.text('로그인하기'));
    await tester.pumpAndSettle();
    await _tapKakaoLogin(tester);

    expect(find.text('착한식당 1호점'), findsOneWidget);
    expect(find.text('설정 저장'), findsOneWidget);
    expect(alerts.fetches, 2);
  });
}

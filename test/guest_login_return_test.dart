import 'dart:async';

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
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kakao login for an existing or a new account. With [hold] it waits for
/// [release], like a backend that is still waking up.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(super.ref, {required this.newUser, required this.hold});

  final bool newUser;
  final bool hold;
  final navigateRequests = <bool>[];
  final _release = Completer<void>();
  var logoutCalls = 0;

  void release() => _release.complete();

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    navigateRequests.add(navigate);
    if (hold) await _release.future;
    await ApiClient.setSessionToken('guest-flow-session');
    return newUser
        ? const KakaoLoginResult.newUser()
        : const KakaoLoginResult(KakaoLoginStatus.success);
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await ApiClient.setSessionToken(null);
  }
}

class _FakeProfileService extends UserProfileApiService {
  @override
  Future<bool> saveProfile({
    required String nickname,
    required String email,
    required String region,
    required List<String> favoriteCategories,
    String? profileImageUrl,
    bool? nicknamePublic,
    bool? activityPublic,
  }) async => true;
}

/// A screen whose favorite button needs an account.
class _Origin extends StatefulWidget {
  const _Origin();

  @override
  State<_Origin> createState() => _OriginState();
}

class _OriginState extends State<_Origin> {
  String _status = '찜 전';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(_status),
          TextButton(
            onPressed: () async {
              final loggedIn = await requireLogin(
                context,
                message: '찜한 매장은 로그인하면 저장돼요.',
              );
              if (mounted) setState(() => _status = loggedIn ? '찜 완료' : '찜 취소');
            },
            child: const Text('찜하기'),
          ),
        ],
      ),
    );
  }
}

typedef _Harness = ({GoRouter router, _FakeLoginService service});

Future<_Harness> _pump(
  WidgetTester tester, {
  bool termsAccepted = true,
  bool newUser = false,
  bool hold = false,
  String initialLocation = '/origin',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    if (termsAccepted) authTermsAcceptedPreferenceKey: true,
  });
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/origin', builder: (_, _) => const _Origin()),
      GoRoute(
        path: AppRoutes.loginFlow,
        builder: (_, _) => const LoginFlowScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingNearby,
        builder: (_, _) => const OnboardingNearbyScreen(initialStep: 2),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('홈 도착')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kakaoLoginServiceProvider.overrideWith(
          (ref) => _FakeLoginService(ref, newUser: newUser, hold: hold),
        ),
        userProfileApiServiceProvider.overrideWithValue(_FakeProfileService()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
  );
  return (
    router: router,
    service: container.read(kakaoLoginServiceProvider) as _FakeLoginService,
  );
}

Future<void> _askToLogin(WidgetTester tester) async {
  await tester.tap(find.text('찜하기'));
  await tester.pumpAndSettle();
  expect(find.text('로그인이 필요해요'), findsOneWidget);
  expect(find.text('찜한 매장은 로그인하면 저장돼요.'), findsOneWidget);
  await tester.tap(find.byKey(const Key('login_required_confirm')));
  await tester.pumpAndSettle();
}

Future<void> _agreeToTerms(WidgetTester tester) async {
  expect(find.text('로그인 전에\n약관을 확인해주세요'), findsOneWidget);
  await tester.tap(find.text('필수 약관 전체 동의'));
  await tester.pump();
  await tester.tap(find.text('동의하고 로그인하기'));
  await tester.pumpAndSettle();
}

Future<void> _saveProfile(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '절약왕');
  await tester.enterText(find.byType(TextField).at(1), '서울 마포구');
  await tester.pump(const Duration(milliseconds: 400));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('한식'));
  await tester.tap(find.text('한식'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('가입 완료하고 시작하기'));
  await tester.pumpAndSettle();
}

/// What the browser's back button does: it hands go_router the screens saved
/// for the previous history entry, and go_router rebuilds them.
Future<void> _browserBack(
  WidgetTester tester,
  GoRouter router,
  RouteInformation previous,
) async {
  await router.routeInformationProvider.didPushRouteInformation(previous);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('a first login agrees to the terms and returns to finish', (
    tester,
  ) async {
    final harness = await _pump(tester, termsAccepted: false);
    await _askToLogin(tester);
    await _agreeToTerms(tester);

    expect(find.text('나중에 할게요'), findsOneWidget);
    expect(find.text('로그인 없이 둘러보기'), findsNothing);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('찜 완료'), findsOneWidget);
    expect(find.byType(LoginFlowScreen), findsNothing);
    expect(harness.service.navigateRequests, [false]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(authTermsAcceptedPreferenceKey), isTrue);
  });

  for (final leave in ['나중에 할게요', '뒤로가기']) {
    testWidgets('leaving login with $leave returns as a guest', (tester) async {
      final harness = await _pump(tester);
      await _askToLogin(tester);

      await tester.tap(
        leave == '뒤로가기' ? find.byTooltip(leave) : find.text(leave),
      );
      await tester.pumpAndSettle();

      expect(find.text('찜 취소'), findsOneWidget);
      expect(harness.service.navigateRequests, isEmpty);
      expect(ApiClient.isAuthenticated, isFalse);
    });
  }

  testWidgets('declining the terms returns without logging in', (tester) async {
    final harness = await _pump(tester, termsAccepted: false);
    await _askToLogin(tester);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('찜 취소'), findsOneWidget);
    expect(harness.service.navigateRequests, isEmpty);
  });

  testWidgets('choosing later in the prompt keeps the guest on the screen', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('찜하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    expect(find.text('찜 취소'), findsOneWidget);
    expect(find.byType(LoginFlowScreen), findsNothing);
    expect(harness.service.navigateRequests, isEmpty);
  });

  testWidgets('a new account saves its profile before returning', (
    tester,
  ) async {
    final harness = await _pump(tester, newUser: true);
    await _askToLogin(tester);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    await _saveProfile(tester);

    expect(find.text('찜 완료'), findsOneWidget);
    expect(harness.service.logoutCalls, 0);
    expect(ApiClient.isAuthenticated, isTrue);
  });

  testWidgets('leaving profile setup ends the new session', (tester) async {
    final harness = await _pump(tester, newUser: true);
    await _askToLogin(tester);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(harness.service.logoutCalls, 1);
    expect(ApiClient.isAuthenticated, isFalse);
    expect(find.text('프로필을 저장해야 가입이 끝나요.'), findsOneWidget);
    expect(find.text('카카오로 계속하기'), findsOneWidget, reason: 'can retry');

    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();
    expect(find.text('찜 취소'), findsOneWidget);
  });

  testWidgets('a logged in visitor carries on without a prompt', (
    tester,
  ) async {
    await _pump(tester);
    await ApiClient.setSessionToken('existing-session');
    await tester.tap(find.text('찜하기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인이 필요해요'), findsNothing);
    expect(find.text('찜 완료'), findsOneWidget);
  });

  // On the web, go_router rebuilds the screens from browser history and the
  // result of a closed screen never arrives (flutter/flutter#128122).
  for (final step in ['terms', 'login', 'profile setup']) {
    testWidgets('the browser back button on $step closes the whole flow', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        termsAccepted: step != 'terms',
        newUser: step == 'profile setup',
      );
      final beforeLogin = harness.router.routeInformationProvider.value;
      expect(beforeLogin.state, isA<Map<Object?, Object?>>());
      await _askToLogin(tester);
      if (step == 'profile setup') {
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pumpAndSettle();
        expect(find.text('프로필 설정'), findsOneWidget);
      }

      await _browserBack(tester, harness.router, beforeLogin);

      expect(find.byType(LoginFlowScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('찜 취소'), findsOneWidget);
      expect(ApiClient.isAuthenticated, isFalse);
      expect(harness.service.logoutCalls, step == 'profile setup' ? 1 : 0);

      // Nothing is left waiting: the next tap asks again.
      await _askToLogin(tester);
      expect(find.byType(LoginFlowScreen), findsOneWidget);
    });
  }

  for (final newUser in [false, true]) {
    testWidgets(
      'leaving while Kakao login is still running, '
      '${newUser ? 'a new account is signed out' : 'a member stays logged in'}',
      (tester) async {
        final harness = await _pump(tester, newUser: newUser, hold: true);
        await _askToLogin(tester);
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pump();

        await tester.tap(find.text('나중에 할게요'));
        await tester.pumpAndSettle();
        expect(find.text('찜 취소'), findsOneWidget);
        expect(find.byType(LoginFlowScreen), findsNothing);

        harness.service.release();
        await tester.pumpAndSettle();

        expect(ApiClient.isAuthenticated, !newUser);
        expect(harness.service.logoutCalls, newUser ? 1 : 0);
        expect(
          find.text('카카오로 로그인했어요.'),
          newUser ? findsNothing : findsOneWidget,
        );
        expect(find.text('찜 취소'), findsOneWidget);
      },
    );
  }

  testWidgets('the onboarding login link comes back to the slides', (
    tester,
  ) async {
    await _pump(tester, initialLocation: AppRoutes.onboardingNearby);

    await tester.tap(find.text('이미 계정이 있나요? 로그인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    expect(find.text('이미 계정이 있나요? 로그인'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_completed'), isNull);

    await tester.tap(find.text('이미 계정이 있나요? 로그인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('홈 도착'), findsOneWidget);
    expect(preferences.getBool('onboarding_completed'), isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/auth_terms_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kakao login that succeeds at once, for an existing or a new account.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(super.ref, {required this.newUser});

  final bool newUser;
  final navigateRequests = <bool>[];
  var logoutCalls = 0;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    navigateRequests.add(navigate);
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

/// Stands in for profile setup: saves or leaves.
class _ProfileSetupStub extends StatelessWidget {
  const _ProfileSetupStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('프로필 저장'),
          ),
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('프로필 나가기'),
          ),
        ],
      ),
    );
  }
}

Future<_FakeLoginService> _pumpOrigin(
  WidgetTester tester, {
  bool termsAccepted = true,
  bool newUser = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    if (termsAccepted) authTermsAcceptedPreferenceKey: true,
  });
  final router = GoRouter(
    initialLocation: '/origin',
    routes: [
      GoRoute(path: '/origin', builder: (_, _) => const _Origin()),
      GoRoute(
        path: AppRoutes.authTerms,
        builder: (_, state) =>
            AuthTermsScreen(entry: loginEntryOf(state.extra)),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, state) => LoginScreen(entry: loginEntryOf(state.extra)),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (_, _) => const _ProfileSetupStub(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kakaoLoginServiceProvider.overrideWith(
          (ref) => _FakeLoginService(ref, newUser: newUser),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
        tester.element(find.byType(_Origin)),
      ).read(kakaoLoginServiceProvider)
      as _FakeLoginService;
}

Future<void> _askToLogin(WidgetTester tester) async {
  await tester.tap(find.text('찜하기'));
  await tester.pumpAndSettle();
  expect(find.text('로그인이 필요해요'), findsOneWidget);
  expect(find.text('찜한 매장은 로그인하면 저장돼요.'), findsOneWidget);
  await tester.tap(find.byKey(const Key('login_required_confirm')));
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
    final service = await _pumpOrigin(tester, termsAccepted: false);
    await _askToLogin(tester);

    expect(find.text('필수 약관 전체 동의'), findsOneWidget);
    await tester.tap(find.text('필수 약관 전체 동의'));
    await tester.pump();
    await tester.tap(find.text('동의하고 로그인하기'));
    await tester.pumpAndSettle();

    expect(find.text('나중에 할게요'), findsOneWidget);
    expect(find.text('로그인 없이 둘러보기'), findsNothing);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('찜 완료'), findsOneWidget);
    expect(service.navigateRequests, [false]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(authTermsAcceptedPreferenceKey), isTrue);
  });

  for (final leave in ['나중에 할게요', '뒤로가기']) {
    testWidgets('leaving login with $leave returns as a guest', (tester) async {
      final service = await _pumpOrigin(tester);
      await _askToLogin(tester);

      await tester.tap(
        leave == '뒤로가기' ? find.byTooltip(leave) : find.text(leave),
      );
      await tester.pumpAndSettle();

      expect(find.text('찜 취소'), findsOneWidget);
      expect(service.navigateRequests, isEmpty);
      expect(ApiClient.isAuthenticated, isFalse);
    });
  }

  testWidgets('declining the terms returns without logging in', (tester) async {
    final service = await _pumpOrigin(tester, termsAccepted: false);
    await _askToLogin(tester);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('찜 취소'), findsOneWidget);
    expect(service.navigateRequests, isEmpty);
  });

  testWidgets('choosing later in the prompt keeps the guest on the screen', (
    tester,
  ) async {
    final service = await _pumpOrigin(tester);
    await tester.tap(find.text('찜하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    expect(find.text('찜 취소'), findsOneWidget);
    expect(find.text('카카오로 계속하기'), findsNothing);
    expect(service.navigateRequests, isEmpty);
  });

  testWidgets('a new account saves its profile before returning', (
    tester,
  ) async {
    final service = await _pumpOrigin(tester, newUser: true);
    await _askToLogin(tester);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('프로필 저장'));
    await tester.pumpAndSettle();

    expect(find.text('찜 완료'), findsOneWidget);
    expect(service.logoutCalls, 0);
  });

  testWidgets('leaving profile setup ends the new session', (tester) async {
    final service = await _pumpOrigin(tester, newUser: true);
    await _askToLogin(tester);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('프로필 나가기'));
    await tester.pumpAndSettle();

    expect(service.logoutCalls, 1);
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
    await _pumpOrigin(tester);
    await ApiClient.setSessionToken('existing-session');
    await tester.tap(find.text('찜하기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인이 필요해요'), findsNothing);
    expect(find.text('찜 완료'), findsOneWidget);
  });
}

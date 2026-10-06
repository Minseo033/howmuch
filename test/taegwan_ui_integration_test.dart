import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';
import 'package:howmuch/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final skip in [false, true]) {
    testWidgets(
      'onboarding ${skip ? 'guest browsing' : 'completion'} persists its choice',
      (tester) async {
        _setViewport(tester, const Size(390, 844));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: AppRoutes.onboardingNearby,
          routes: [
            GoRoute(
              path: AppRoutes.onboardingNearby,
              builder: (_, _) => const OnboardingNearbyScreen(initialStep: 2),
            ),
            GoRoute(
              path: AppRoutes.authTerms,
              builder: (_, _) => const Scaffold(body: Text('약관 화면 도착')),
            ),
            GoRoute(
              path: AppRoutes.permissionSetup,
              builder: (_, _) => const Scaffold(body: Text('권한 화면 도착')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(skip ? '로그인 없이 둘러보기' : '시작하기'));
        await tester.pumpAndSettle();

        // '시작하기' signs up through the terms; browsing skips straight to
        // the guest path that the login screen also offers.
        expect(find.text(skip ? '권한 화면 도착' : '약관 화면 도착'), findsOneWidget);
        expect(container.read(onboardingCompletedProvider), isTrue);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getBool('onboarding_completed'), isTrue);
      },
    );
  }

  final actions = {
    '지도에서 주변 매장 더 보기': AppRoutes.home,
    '내 제보 내역 확인': AppRoutes.myReportsV2,
  };
  for (final viewport in [const Size(320, 568), const Size(568, 320)]) {
    for (final action in actions.entries) {
      testWidgets('report action ${action.key} is reachable at $viewport', (
        tester,
      ) async {
        _setViewport(tester, viewport);
        final router = GoRouter(
          initialLocation: AppRoutes.reportComplete,
          routes: [
            GoRoute(
              path: AppRoutes.reportComplete,
              builder: (_, _) => const ReportCompleteScreen(),
            ),
            GoRoute(
              path: action.value,
              builder: (_, _) => const Scaffold(body: Text('선택한 화면 도착')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userReportsProvider.overrideWith(
                (_) => UserReportsNotifier([
                  UserReportStatus.fromJson({
                    'id': 'integration-test',
                    'storeName': '테스트 식당',
                    'menu1': '칼국수',
                    'price1': '5000',
                    'status': 'PENDING',
                    'createdAt': '2026-09-30T09:00:00+09:00',
                  }),
                ]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -350),
          );
          await tester.pumpAndSettle();
        }
        final button = find.text(action.key).hitTestable();
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('선택한 화면 도착'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/screens/auth_terms_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stays inside narrow and landscape viewports', (tester) async {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthTermsScreen()));
      await tester.pump();

      expect(find.text('필수 약관 전체 동의'), findsOneWidget);
      expect(find.text('동의하고 로그인하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('requires both mandatory agreements before entering login', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.authTerms,
      routes: [
        GoRoute(
          path: AppRoutes.authTerms,
          builder: (_, _) => const AuthTermsScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('로그인 화면')),
        ),
        GoRoute(
          path: AppRoutes.termsOfService,
          builder: (_, _) => const Scaffold(),
        ),
        GoRoute(
          path: AppRoutes.privacyPolicy,
          builder: (_, _) => const Scaffold(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('동의하고 로그인하기'));
    await tester.pump();
    expect(find.text('로그인 화면'), findsNothing);

    await tester.tap(find.text('필수 약관 전체 동의'));
    await tester.pump();
    await tester.tap(find.text('동의하고 로그인하기'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 화면'), findsOneWidget);
  });
}

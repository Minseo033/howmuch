import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_route_observer.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/startup_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('direct web route cold start still begins at splash validation', () {
    binding.platformDispatcher.defaultRouteNameTestValue = AppRoutes.mypage;
    addTearDown(binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.splash);
    expect(
      container.read(startupLocationProvider).pending,
      AppRoutes.mypage,
      reason: 'the reloaded address opens after the session check',
    );
  });

  testWidgets(
    'a requested address waits through login and ends when another screen opens first',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      binding.platformDispatcher.defaultRouteNameTestValue =
          AppRoutes.communityFeed;
      addTearDown(binding.platformDispatcher.clearDefaultRouteNameTestValue);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);
      final startup = container.read(startupLocationProvider);

      router.go(AppRoutes.login);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(startup.pending, AppRoutes.communityFeed);

      // For example browsing without login, or any screen before login ends.
      router.go(AppRoutes.privacyPolicy);
      await tester.pumpAndSettle();
      expect(startup.take(), AppRoutes.home);
    },
  );

  // The web unread banner relies on this to stay off dialogs and retire when
  // the page changes (QA 10/7 #21).
  testWidgets('the navigation tracker follows router pages and dialogs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    final tracker = container.read(appNavigationTrackerProvider);

    router.go(AppRoutes.login);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final pagesAtLogin = tracker.pageChanges;

    router.go(AppRoutes.privacyPolicy);
    await tester.pumpAndSettle();
    expect(tracker.pageChanges, greaterThan(pagesAtLogin));
    expect(tracker.hasPopup, isFalse);

    final navigator = router.routerDelegate.navigatorKey;
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('확인')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tracker.hasPopup, isTrue);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tracker.hasPopup, isFalse);
  });

  test('reloaded addresses reopen their screen, their tab or home', () {
    const reopened = {
      '/community': '/community',
      '/mypage/': '/mypage',
      '/savings/dashboard': '/savings/dashboard',
      '/notifications': '/notifications',
      '/community/reports-v2': '/community/reports-v2',
      '/community/report-detail-v2?id=r1': '/community/report-detail-v2?id=r1',
      '/community/report-detail-v2': '/community/reports-v2',
      '/mypage/account': '/mypage/account',
      '/mypage/favorite-stores': '/mypage',
      '/community/post/detail?id=p1': '/community',
      '/savings/detail?startDate=2026-10-01': '/savings/dashboard',
    };
    for (final MapEntry(key: requested, value: expected) in reopened.entries) {
      expect(reopenableStartupLocation(requested), expected, reason: requested);
    }
    for (final requested in [
      '/',
      '/splash',
      '/login',
      '/oauth?code=c',
      '/home/ai-fab',
      '/store/detail',
      '/search/result',
      '/no-such-page',
    ]) {
      expect(reopenableStartupLocation(requested), isNull, reason: requested);
    }
  });
}

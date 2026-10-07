import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/widgets/route_page_title.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  testWidgets('the browser tab names the visible screen and follows back', (
    tester,
  ) async {
    final titles = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
        titles.add((call.arguments as Map)['label'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        for (final path in [
          AppRoutes.home,
          AppRoutes.communityFeed,
          AppRoutes.notifications,
          AppRoutes.storeDetail,
          '/unlisted',
        ])
          GoRoute(path: path, builder: (_, _) => const SizedBox.expand()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        title: '얼마고?',
        routerConfig: router,
        builder: (context, child) =>
            RoutePageTitle(router: router, child: child!),
      ),
    );
    await tester.pump();
    expect(titles.last, '홈 · 얼마고?');

    router.go(AppRoutes.communityFeed);
    await tester.pumpAndSettle();
    expect(titles.last, '동네 제보 · 얼마고?');

    router.push(AppRoutes.notifications);
    await tester.pumpAndSettle();
    expect(
      titles.last,
      '알림 · 얼마고?',
      reason: 'a pushed screen keeps the tab URL',
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(titles.last, '동네 제보 · 얼마고?', reason: 'closing it renames the tab');

    router.push(
      AppRoutes.storeDetail,
      extra: Store.fromJson({'id': 's1', 'storeName': '청년밥상문간 이화여자대학교점'}),
    );
    await tester.pumpAndSettle();
    expect(titles.last, '청년밥상문간 이화여자대학교점 · 얼마고?');

    router.go('/unlisted');
    await tester.pumpAndSettle();
    expect(titles.last, '얼마고?');
  });
}

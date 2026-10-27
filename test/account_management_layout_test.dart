import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/screens/account_management_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('account card fits long nicknames and opens the editor', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).state = UserProfile.guest
        .copyWith(nickname: '아주아주긴닉네임을쓰는절약왕사용자입니다정말로길어요');
    final router = GoRouter(
      initialLocation: AppRoutes.accountManagement,
      routes: [
        GoRoute(
          path: AppRoutes.accountManagement,
          builder: (_, _) => const AccountManagementScreen(),
        ),
        GoRoute(
          path: AppRoutes.profileEdit,
          builder: (_, _) => const Scaffold(body: Text('프로필 수정 화면')),
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
    expect(tester.takeException(), isNull);

    final edit = find.bySemanticsLabel('프로필 편집');
    expect(tester.getSize(edit), const Size(48, 44));

    await tester.tap(find.text('닉네임 변경'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 수정 화면'), findsOneWidget);
    semantics.dispose();
  });
}

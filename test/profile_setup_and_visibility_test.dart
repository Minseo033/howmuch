import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileService extends UserProfileApiService {
  _FakeProfileService({required this.result});

  bool result;
  final saved = <Map<String, Object?>>[];

  @override
  Future<bool> saveProfile({
    required String nickname,
    required String email,
    required String region,
    required List<String> favoriteCategories,
    String? profileImageUrl,
    bool? nicknamePublic,
    bool? activityPublic,
  }) async {
    saved.add({
      'nickname': nickname,
      'region': region,
      'favoriteCategories': favoriteCategories,
    });
    return result;
  }
}

void _mobileViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile setup stays put when the profile save fails', (
    tester,
  ) async {
    _mobileViewport(tester);
    final service = _FakeProfileService(result: false);
    final container = ProviderContainer(
      overrides: [userProfileApiServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.profileSetup,
      routes: [
        GoRoute(
          path: AppRoutes.profileSetup,
          builder: (_, _) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

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

    expect(service.saved, hasLength(1));
    expect(find.text('HOME'), findsNothing);
    expect(
      find.text('프로필을 저장하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요.'),
      findsOneWidget,
    );
    expect(
      container.read(userProfileProvider).nickname,
      UserProfile.guest.nickname,
      reason: 'local state must not claim a profile the server never stored',
    );

    service.result = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가입 완료하고 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    final profile = container.read(userProfileProvider);
    expect(profile.nickname, '절약왕');
    expect(profile.region, '서울 마포구');
    expect(profile.favoriteCategories, ['한식']);
  });

  testWidgets('category chips announce their selected state', (tester) async {
    _mobileViewport(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileSetupScreen())),
    );
    await tester.pumpAndSettle();

    final chip = find.bySemanticsLabel('한식');
    expect(
      tester.getSemantics(chip),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
    await tester.ensureVisible(find.text('한식'));
    await tester.tap(find.text('한식'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(chip),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    semantics.dispose();
  });

  testWidgets('profile edit shows the stored visibility choice', (
    tester,
  ) async {
    _mobileViewport(tester);
    final semantics = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userProfileProvider.notifier).state = UserProfile.guest
        .copyWith(nickname: '절약왕', nicknamePublic: false);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileEditScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('닉네임 공개')),
      isSemantics(hasToggledState: true, isToggled: false),
    );
    expect(find.text('커뮤니티 글·댓글과 리뷰에 익명으로 보여요'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-privacy-readonly-note')),
      findsOneWidget,
    );

    container.read(userProfileProvider.notifier).state = container
        .read(userProfileProvider)
        .copyWith(nicknamePublic: true);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('닉네임 공개')),
      isSemantics(hasToggledState: true, isToggled: true),
    );
    expect(find.text('커뮤니티 글·댓글에 닉네임과 프로필 사진이, 리뷰에 닉네임이 보여요'), findsOneWidget);

    await tester.tap(find.text('닉네임 공개'));
    await tester.pumpAndSettle();
    expect(
      find.text('닉네임 공개 설정은 아직 바꿀 수 없어요. 커뮤니티와 리뷰에 닉네임이 표시돼요.'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

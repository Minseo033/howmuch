import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/howmuch_app.dart';
import 'package:howmuch/app/app_routes.dart';

void main() {
  testWidgets('starts at the first onboarding screen', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    expect(find.text('정부 인증 · 공공데이터'), findsOneWidget);
    expect(find.text('내 주변 착한가격업소를 한눈에'), findsOneWidget);
  });

  testWidgets('moves through onboarding, login, permission, and home', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('절약 리포트'), findsOneWidget);
    expect(find.text('오늘 아낀 금액이 쌓여요'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('사용자 제보'), findsAtLeastNWidgets(1));
    expect(find.text('좋은 가격은 함께 나눠요'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('얼마고?'), findsOneWidget);
    expect(find.text('카카오로 계속하기'), findsOneWidget);

    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();
    expect(find.text('더 정확한 추천을 위해\n권한이 필요해요'), findsOneWidget);
    expect(find.text('앱 시작하기'), findsOneWidget);

    await tester.tap(find.text('앱 시작하기').first);
    await tester.pumpAndSettle();
    expect(find.text('가게명, 메뉴, 지역 검색'), findsOneWidget);
    expect(find.text('따뜻한 국물 메뉴 3곳'), findsOneWidget);
  });

  testWidgets('opens mypage', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('절약왕 민서'), findsOneWidget);
    expect(find.text('내 제보 상태'), findsOneWidget);
  });

  testWidgets('opens mypage notification and account screens', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.notificationSettings);
    expect(find.text('알림 설정'), findsAtLeastNWidgets(1));
    expect(find.text('가격 변동 알림'), findsOneWidget);
    expect(find.text('설정 저장'), findsOneWidget);

    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('알림 설정을 저장했어요.'), findsOneWidget);

    await _goToRoute(tester, AppRoutes.accountManagement);
    expect(find.text('계정 관리'), findsAtLeastNWidgets(1));
    expect(find.text('연결된 소셜 계정'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
  });

  testWidgets('manages connected social accounts', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.connectedSocialAccounts);
    expect(find.text('연결된 소셜 계정'), findsAtLeastNWidgets(1));
    expect(find.text('연결된 계정 · 2개'), findsOneWidget);
    expect(find.text('Apple ID'), findsOneWidget);

    await tester.tap(find.text('주 계정 변경'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple ID').last);
    await tester.pumpAndSettle();
    expect(find.text('Apple ID 계정을 주 계정으로 변경했어요.'), findsOneWidget);

    await tester.tap(find.text('해제'));
    await tester.pumpAndSettle();
    expect(find.text('카카오 계정을 해제했어요.'), findsOneWidget);
  });

  testWidgets('opens withdrawal screen and asks for final confirmation', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.withdrawal);
    expect(find.text('회원 탈퇴'), findsAtLeastNWidgets(1));
    expect(find.text('탈퇴 전 꼭 확인해주세요'), findsOneWidget);
    expect(find.text('가격 정보가 정확하지 않아요'), findsOneWidget);

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('선택한 사유: 가격 정보가 정확하지 않아요'), findsOneWidget);

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('opens price alert subscription and toggles settings', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.notificationSettings);
    await tester.tap(find.text('구독 중인 가격 알림'));
    await tester.pumpAndSettle();

    expect(find.text('가격 알림 구독'), findsAtLeastNWidgets(1));
    expect(find.text('착한분식'), findsOneWidget);
    expect(find.text('알림 조건'), findsOneWidget);

    await tester.tap(find.text('새 메뉴 등록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(find.text('알림 설정'), findsAtLeastNWidgets(1));
    expect(find.text('가격 알림을 저장했어요.'), findsOneWidget);
  });

  testWidgets('opens profile edit and saves profile visibility', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsAtLeastNWidgets(1));
    expect(find.text('저장하기'), findsOneWidget);
    expect(find.text('닉네임 공개'), findsOneWidget);

    await tester.tap(find.text('절약왕 민서'));
    await tester.pumpAndSettle();
    expect(find.text('닉네임 변경'), findsNothing);

    await tester.tap(find.text('서울시 강남구 역삼동'));
    await tester.pumpAndSettle();
    expect(find.text('현재 동네 변경'), findsNothing);

    await tester.tap(find.text('활동 내역 공개'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('프로필을 저장했어요.'), findsOneWidget);
  });

  testWidgets('opens public data source and sends inquiry', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.publicDataSource);
    expect(find.text('공공데이터 출처'), findsAtLeastNWidgets(1));
    expect(find.text('행정안전부 착한가격업소'), findsOneWidget);
    expect(find.text('data.go.kr'), findsOneWidget);

    await tester.tap(find.text('문의하기'));
    await tester.pumpAndSettle();
    expect(find.text('문의 유형'), findsOneWidget);
    expect(find.text('착한분식 가격이 변경된 것 같아요'), findsOneWidget);
    expect(find.text('문의 보내기'), findsOneWidget);

    await tester.tap(find.text('기타'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('문의 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('문의가 접수되었어요.'), findsOneWidget);
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    permissionChannel,
    (call) async {
      if (call.method == 'requestPermissions') {
        final permissions = (call.arguments as List).cast<int>();
        return {for (final permission in permissions) permission: 1};
      }

      if (call.method == 'checkPermissionStatus') {
        return 1;
      }

      if (call.method == 'shouldShowRequestPermissionRationale') {
        return false;
      }

      if (call.method == 'openAppSettings') {
        return true;
      }

      return null;
    },
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionChannel,
      null,
    ),
  );
}

Future<void> _goToRoute(WidgetTester tester, String route) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
  await tester.pumpAndSettle();
}

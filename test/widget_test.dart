import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/howmuch_app.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

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
    expect(find.text('개발용 관리자 모드'), findsOneWidget);
    expect(find.text('관리자 제보 검토'), findsNothing);
    expect(find.text('관리자 문의 검토'), findsNothing);
  });

  testWidgets('toggles temporary admin mode from mypage QA row', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    expect(find.text('관리자 제보 검토'), findsNothing);

    await tester.ensureVisible(find.text('개발용 관리자 모드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개발용 관리자 모드'));
    await tester.pumpAndSettle();

    expect(find.text('개발용 관리자 모드를 켰어요.'), findsOneWidget);
    await tester.ensureVisible(find.text('관리자 제보 검토'));
    await tester.pumpAndSettle();
    expect(find.text('관리자 제보 검토'), findsOneWidget);
    expect(find.text('관리자 문의 검토'), findsOneWidget);
  });

  testWidgets('shows admin menu only for admin users', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => const AuthState(
              isLoggedIn: true,
              isAdmin: true,
              provider: '카카오',
              email: 'admin@howmuch.local',
            ),
          ),
        ],
        child: const HowmuchApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    await tester.ensureVisible(find.text('관리자 제보 검토'));
    await tester.pumpAndSettle();

    expect(find.text('관리자 제보 검토'), findsOneWidget);
    expect(find.text('관리자 문의 검토'), findsOneWidget);
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

  testWidgets('opens policy and terms screens from account management', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.accountManagement);
    await tester.tap(find.text('개인정보 처리방침'));
    await tester.pumpAndSettle();
    expect(find.text('얼마고? 개인정보 처리방침'), findsOneWidget);
    expect(find.text('개인정보 보호 책임자'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('계정 관리'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('서비스 이용약관'));
    await tester.pumpAndSettle();
    expect(find.text('한눈에 보는 약관'), findsOneWidget);
    expect(find.text('본 약관에 동의하지 않으시면 서비스 이용이 제한됩니다.'), findsOneWidget);

    await tester.tap(find.text('제보·리뷰 게시 책임'));
    await tester.pumpAndSettle();
    expect(find.text('확인'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('서비스 이용약관'), findsAtLeastNWidgets(1));
  });

  testWidgets('opens admin review screens and updates local workflow', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.adminReportReview);

    expect(find.text('제보 검토'), findsOneWidget);
    expect(find.text('골목밥상'), findsOneWidget);
    expect(find.text('검증 체크리스트'), findsOneWidget);

    await tester.tap(find.text('중복 매장 여부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('승인').last);
    await tester.pumpAndSettle();
    expect(find.text('골목밥상 제보를 승인했어요.'), findsOneWidget);

    await _goToRoute(tester, AppRoutes.adminInquiryReview);
    expect(find.text('문의 검토'), findsOneWidget);
    expect(find.text('제보한 매장이 7일째 검토 중이에요'), findsOneWidget);

    await tester.tap(find.textContaining('답변하기').first);
    await tester.pumpAndSettle();
    expect(find.text('답변 내용'), findsOneWidget);
    expect(find.text('답변 보내기'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('send_admin_inquiry_reply')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send_admin_inquiry_reply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('답변 내용'), findsNothing);

    await tester.tap(find.text('완료').last);
    await tester.pumpAndSettle();
    expect(find.text('답변 완료'), findsAtLeastNWidgets(1));
    expect(find.text('제보한 매장이 7일째 검토 중이에요'), findsOneWidget);
  });

  testWidgets('opens empty search result from home and handles actions', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.home);
    await tester.tap(find.text('가게명, 메뉴, 지역 검색'));
    await tester.pumpAndSettle();

    expect(find.text('주차요금'), findsOneWidget);
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(find.text('필터 초기화하기'), findsOneWidget);

    await tester.tap(find.text('김치찌개'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('김치찌개 검색어로 다시 찾아볼게요.'), findsOneWidget);

    await tester.tap(find.text('필터 초기화하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('필터를 초기화했어요.'), findsOneWidget);

    await tester.tap(find.text('전체 매장 보기'));
    await tester.pumpAndSettle();
    expect(find.text('따뜻한 국물 메뉴 3곳'), findsOneWidget);
  });

  testWidgets('opens report delete confirmation and deletes local report', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    await tester.tap(find.text('골목밥상'));
    await tester.pumpAndSettle();

    expect(find.text('제보를 삭제할까요?'), findsOneWidget);
    expect(find.text('삭제하기'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('골목밥상'), findsOneWidget);

    await tester.tap(find.text('골목밥상'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();

    expect(find.text('골목밥상'), findsNothing);
    expect(find.text('골목밥상 제보를 삭제했어요.'), findsOneWidget);
  });

  testWidgets('opens network error state and handles recovery actions', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    await tester.ensureVisible(find.text('네트워크 오류 화면'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('네트워크 오류 화면'));
    await tester.pumpAndSettle();
    expect(find.text('연결할 수 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('오프라인 저장 매장 보기'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('연결 상태를 다시 확인했어요.'), findsOneWidget);

    await tester.tap(find.text('오프라인 저장 매장 보기'));
    await tester.pumpAndSettle();
    expect(find.text('가게명, 메뉴, 지역 검색'), findsOneWidget);
  });

  testWidgets('opens session expired state and relogs in', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToRoute(tester, AppRoutes.mypage);
    await tester.ensureVisible(find.text('세션 만료 · 재로그인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('세션 만료 · 재로그인'));
    await tester.pumpAndSettle();
    expect(find.text('다시 로그인이 필요해요'), findsOneWidget);
    expect(find.text('로그인 없이 이용 가능'), findsOneWidget);
    expect(find.text('카카오로 다시 로그인'), findsOneWidget);
    expect(find.text('나중에 할게요'), findsOneWidget);

    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();
    expect(find.text('가게명, 메뉴, 지역 검색'), findsOneWidget);

    await _goToRoute(tester, AppRoutes.sessionExpired);
    await tester.tap(find.text('카카오로 다시 로그인'));
    await tester.pumpAndSettle();
    expect(find.text('가게명, 메뉴, 지역 검색'), findsOneWidget);
    expect(find.text('카카오로 다시 로그인했어요.'), findsOneWidget);
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

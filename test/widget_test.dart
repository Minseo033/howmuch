import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/howmuch_app.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

  testWidgets('starts at the first onboarding screen', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    expect(find.text('정부 인증 · 공공데이터'), findsOneWidget);
    expect(find.text('내 주변 착한가격업소를 한눈에'), findsOneWidget);
  });

  testWidgets('moves through onboarding, login, and permission setup', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

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
    expect(find.text('네이버로 계속하기'), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.text('준비 중'), findsNWidgets(2));

    await tester.tap(find.text('로그인 없이 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('더 정확한 추천을 위해\n권한이 필요해요'), findsOneWidget);
    expect(find.text('앱 시작하기'), findsOneWidget);
  });

  testWidgets('unavailable social login explains its status', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('네이버로 계속하기'));
    await tester.pump();
    expect(find.text('네이버 로그인은 준비 중이에요.'), findsOneWidget);

    await tester.tap(find.text('Google로 계속하기'));
    await tester.pump();
    expect(find.text('Google 로그인은 준비 중이에요.'), findsOneWidget);
  });

  testWidgets('opens mypage', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.mypage);
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('게스트'), findsOneWidget);
    expect(find.text('내 제보 상태'), findsOneWidget);
    expect(find.text('네트워크 오류 화면'), findsNothing);
    expect(find.text('세션 만료 · 재로그인'), findsNothing);

    final locationDivider = tester.getRect(
      find.byKey(const ValueKey('mypage-location-divider')),
    );
    final locationRow = tester.getRect(
      find.byKey(const ValueKey('mypage-location-row')),
    );
    final locationAction = tester.getRect(
      find.byKey(const ValueKey('mypage-location-action')),
    );
    final locationStatus = tester.getRect(
      find.byKey(const ValueKey('mypage-location-status')),
    );
    final locationChevron = tester.getRect(
      find.byKey(const ValueKey('mypage-location-chevron')),
    );

    final mypageScale = locationRow.height / 44;
    expect(
      locationDivider.left - locationRow.left,
      closeTo(16 * mypageScale, 0.1),
    );
    expect(
      locationRow.right - locationDivider.right,
      closeTo(16 * mypageScale, 0.1),
    );
    expect(locationAction.center.dy, closeTo(locationRow.center.dy, 0.1));
    expect(locationStatus.center.dy, closeTo(locationChevron.center.dy, 0.1));

    final profileEditButton = tester.getRect(
      find.byKey(const ValueKey('mypage-profile-edit-button')),
    );
    final profileEditContent = tester.getRect(
      find.byKey(const ValueKey('mypage-profile-edit-content')),
    );
    final profileEditLabel = tester.getRect(
      find.byKey(const ValueKey('mypage-profile-edit-label')),
    );
    final profileEditChevron = tester.getRect(
      find.byKey(const ValueKey('mypage-profile-edit-chevron')),
    );
    expect(
      profileEditContent.center.dx,
      closeTo(profileEditButton.center.dx, 0.1),
    );
    final profileEditScale = profileEditButton.height / 30;
    expect(
      profileEditLabel.center.dy,
      closeTo(profileEditChevron.center.dy - profileEditScale, 0.1),
    );

    await _goToRoute(tester, AppRoutes.favoriteStores);
    expect(find.text('찜한 매장'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
  });

  testWidgets('opens mypage notification and account screens', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, _appWithNotificationSettingsApi());

    await _goToRoute(tester, AppRoutes.notificationSettings);
    expect(find.text('알림 설정'), findsAtLeastNWidgets(1));
    expect(find.text('가격 변동 알림'), findsOneWidget);
    expect(find.text('설정 저장'), findsOneWidget);

    final allNotificationCard = tester.getRect(
      find.byKey(const ValueKey('all-notification-card')),
    );
    final allNotificationToggle = tester.getRect(
      find.byKey(const ValueKey('all-notification-toggle')),
    );
    expect(
      allNotificationToggle.center.dy,
      closeTo(allNotificationCard.center.dy, 0.1),
    );

    final notificationTypeCard = tester.getRect(
      find.byKey(const ValueKey('notification-type-card')),
    );
    final notificationTitle = tester.getRect(find.text('가격 변동 알림'));
    final notificationDivider = tester.getRect(
      find.byKey(const ValueKey('notification-type-divider')),
    );
    expect(notificationDivider.left, closeTo(notificationTitle.left, 0.1));
    expect(
      notificationTypeCard.right - notificationDivider.right,
      closeTo(notificationDivider.left - notificationTypeCard.left, 0.1),
    );
    for (final label in ['시작 시간', '종료 시간']) {
      final quietTimeLabel = tester.getRect(
        find.byKey(ValueKey('quiet-time-label-$label')),
      );
      final quietTimeValue = tester.getRect(
        find.byKey(ValueKey('quiet-time-value-$label')),
      );
      expect(quietTimeLabel.left, closeTo(quietTimeValue.left, 0.1));
    }
    final notificationSaveButton = tester.getRect(
      find.byKey(const ValueKey('notification-save-button')),
    );
    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final notificationSaveScale =
        notificationSaveButton.height / 51.9886360168457;
    expect(
      screenBottom - notificationSaveButton.bottom,
      closeTo(16 * notificationSaveScale, 0.1),
    );

    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('알림 설정을 저장했어요.'), findsOneWidget);

    await _goToRoute(tester, AppRoutes.accountManagement);
    expect(find.text('계정 관리'), findsAtLeastNWidgets(1));
    expect(find.text('로그인 계정'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
    expect(find.text('카카오'), findsOneWidget);
    expect(find.text('K'), findsNothing);
    final kakaoBadge = tester.widget<Container>(
      find.byKey(const ValueKey('kakao-provider-badge')),
    );
    final kakaoBadgeDecoration = kakaoBadge.decoration! as BoxDecoration;
    expect(kakaoBadgeDecoration.color, const Color(0xFFFEE500));
    expect(kakaoBadgeDecoration.shape, BoxShape.rectangle);
    expect(kakaoBadgeDecoration.borderRadius, isNotNull);
  });

  testWidgets('quiet time picker stays inside the app frame', (tester) async {
    tester.view.physicalSize = const Size(1200, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, _appWithNotificationSettingsApi());

    await _goToRoute(tester, AppRoutes.notificationSettings);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('오후 10:00'));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(
      find.byKey(const ValueKey('quiet-time-bottom-sheet')),
    );
    expect(sheet.width, lessThanOrEqualTo(430));
    expect(sheet.center.dx, closeTo(600, 0.1));
    expect(sheet.top, greaterThanOrEqualTo(0));
    expect(sheet.bottom, lessThanOrEqualTo(650));

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });

  testWidgets('mypage child screens return with their header back buttons', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    for (final label in ['계정 관리', '공공데이터 출처 안내', '문의하기']) {
      await _goToRoute(tester, AppRoutes.mypage);
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(
        find.text(label == '공공데이터 출처 안내' ? '공공데이터 출처' : label),
        findsAtLeastNWidgets(1),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('마이'), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('direct mypage child routes handle the system back action', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    for (final route in [
      AppRoutes.accountManagement,
      AppRoutes.publicDataSource,
      AppRoutes.inquiry,
    ]) {
      await _goToRoute(tester, route);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('마이'), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('shows login account without fabricated social accounts', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.connectedSocialAccounts);
    expect(find.text('로그인 계정'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const ValueKey('connected-accounts-back-button')),
      findsOneWidget,
    );
    expect(find.text('로그인 정보 없음'), findsOneWidget);
    expect(find.text('현재는 카카오 로그인만 지원합니다.'), findsOneWidget);
    expect(find.text('Apple ID'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('connected-accounts-back-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('계정 관리'), findsAtLeastNWidgets(1));
  });

  testWidgets('opens withdrawal screen and asks for final confirmation', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.withdrawal);
    expect(find.text('회원 탈퇴'), findsAtLeastNWidgets(1));
    expect(find.text('탈퇴 전 꼭 확인해주세요'), findsOneWidget);
    expect(find.text('가격 정보가 정확하지 않아요'), findsOneWidget);

    final deletedDataCard = tester.getRect(
      find.byKey(const ValueKey('withdrawal-deleted-data-card')),
    );
    final deletedDataDivider = tester.getRect(
      find.byKey(const ValueKey('withdrawal-deleted-divider-0')),
    );
    final deletedDataScale = deletedDataCard.width / 335.45452880859375;
    expect(
      deletedDataDivider.left - deletedDataCard.left,
      closeTo(16.903 * deletedDataScale, 0.1),
    );
    expect(
      deletedDataCard.right - deletedDataDivider.right,
      closeTo(16.904 * deletedDataScale, 0.1),
    );

    final withdrawalActionRow = tester.getRect(
      find.byKey(const ValueKey('withdrawal-action-row')),
    );
    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final withdrawalScale = withdrawalActionRow.height / 50;
    expect(
      screenBottom - withdrawalActionRow.bottom,
      closeTo(16 * withdrawalScale, 0.1),
    );

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('탈퇴 동의 내용을 확인해주세요.'), findsOneWidget);

    final consent = find.byKey(const ValueKey('withdrawal-consent'));
    await tester.ensureVisible(consent);
    await tester.pumpAndSettle();
    await tester.tap(consent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('계정 정보와 이용 기록은 복구할 수 없어요.'), findsOneWidget);

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('opens price alert subscription and toggles settings', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, _appWithNotificationSettingsApi());

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

  testWidgets('opens profile edit and explains unavailable visibility', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.mypage);
    await tester.tap(find.text('프로필 수정'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsAtLeastNWidgets(1));
    expect(find.text('저장하기'), findsOneWidget);
    expect(find.text('닉네임 공개'), findsOneWidget);

    final nicknameLabelLeft = tester.getTopLeft(find.text('닉네임')).dx;
    final emailLabelLeft = tester.getTopLeft(find.text('이메일')).dx;
    expect(emailLabelLeft, closeTo(nicknameLabelLeft, 0.1));

    final nicknameRow = tester.getRect(
      find.byKey(const ValueKey('nickname-public-row')),
    );
    final nicknameSwitch = tester.getRect(
      find.byKey(const ValueKey('nickname-public-switch')),
    );
    expect(nicknameSwitch.center.dy, closeTo(nicknameRow.center.dy, 0.1));

    await tester.tap(find.byKey(const ValueKey('profile-nickname-edit')));
    await tester.pumpAndSettle();
    expect(find.text('닉네임 변경'), findsOneWidget);
    final nicknameField = tester.getRect(
      find.byKey(const ValueKey('profile-nickname-field')),
    );
    final nicknameHelper = tester.getRect(
      find.byKey(const ValueKey('profile-nickname-helper')),
    );
    final nicknameCounter = tester.getRect(
      find.byKey(const ValueKey('profile-nickname-counter')),
    );
    expect(nicknameHelper.left, closeTo(nicknameField.left, 0.1));
    expect(nicknameCounter.right, closeTo(nicknameField.right, 0.1));
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname-field')),
      'QA 닉네임',
    );
    await tester.tap(find.text('변경'));
    await tester.pumpAndSettle();
    expect(find.text('QA 닉네임'), findsOneWidget);

    await tester.tap(find.text('활동 내역 공개'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 공개 설정은 현재 제공하지 않아요.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 저장에 실패했어요. 다시 시도해주세요.'), findsOneWidget);
  });

  testWidgets('opens public data source and sends inquiry', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, _appWithInquiryApi());

    await _goToRoute(tester, AppRoutes.publicDataSource);
    expect(find.text('공공데이터 출처'), findsAtLeastNWidgets(1));
    expect(find.text('행정안전부 착한가격업소'), findsOneWidget);
    expect(find.text('한국소비자원 참가격'), findsOneWidget);
    final introCard = tester.getRect(
      find.byKey(const ValueKey('public-data-intro-card')),
    );
    final introIcon = tester.getRect(
      find.byKey(const ValueKey('public-data-intro-icon')),
    );
    expect(
      introIcon.top - introCard.top,
      closeTo(introCard.bottom - introIcon.bottom, 0.1),
    );
    final introText = tester.widget<RichText>(
      find.byKey(const ValueKey('public-data-intro-text')),
    );
    expect(introText.maxLines, 2);
    expect(
      introText.text.toPlainText(),
      '얼마고?는 행정안전부 착한가격업소\n'
      '공공데이터를 기반으로 안내합니다.',
    );
    final syncNotice = tester.widget<Text>(
      find.byKey(const ValueKey('public-data-sync-notice-text')),
    );
    expect(syncNotice.data, isNot(contains('\n')));
    expect(syncNotice.maxLines, 2);

    await tester.tap(find.text('문의하기'));
    await tester.pumpAndSettle();
    expect(find.text('문의 유형'), findsOneWidget);
    expect(find.text('문의 보내기'), findsOneWidget);

    const inquiryTypes = ['매장 정보 오류', '제보 검토 문의', '계정/로그인 문제', '기타'];
    final typeRects = <Rect>[];
    for (final type in inquiryTypes) {
      final button = tester.getRect(find.byKey(ValueKey('inquiry-type-$type')));
      final label = tester.getRect(find.text(type));
      expect(label.center.dx, closeTo(button.center.dx, 0.1));
      expect(label.center.dy, closeTo(button.center.dy, 0.1));
      typeRects.add(button);
    }
    expect(typeRects[0].width, closeTo(typeRects[1].width, 0.1));
    expect(typeRects[2].width, closeTo(typeRects[3].width, 0.1));

    final photoButton = tester.getRect(
      find.byKey(const ValueKey('inquiry-add-photo-button')),
    );
    final photoIcon = tester.getRect(
      find.byKey(const ValueKey('inquiry-add-photo-icon')),
    );
    final photoLabel = tester.getRect(find.text('추가'));
    expect(photoIcon.center.dx, closeTo(photoButton.center.dx, 0.1));
    expect(photoLabel.center.dx, closeTo(photoButton.center.dx, 0.1));
    expect(
      (photoIcon.top + photoLabel.bottom) / 2,
      closeTo(photoButton.center.dy, 0.1),
    );

    final inquiryFooter = tester.getRect(
      find.byKey(const ValueKey('inquiry-sticky-footer')),
    );
    final inquirySubmitButton = tester.getRect(
      find.byKey(const ValueKey('inquiry-submit-button')),
    );
    final inquiryScale = inquirySubmitButton.height / 51.9886360168457;
    expect(
      inquiryFooter.bottom - inquirySubmitButton.bottom,
      closeTo(16 * inquiryScale, 0.1),
    );

    await tester.tap(find.text('기타'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '가격 정보 확인 요청');
    await tester.enterText(fields.at(1), '표시된 가격이 현재 가격과 다른지 확인해주세요.');
    await tester.pump();
    await tester.tap(find.text('문의 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('마이'), findsAtLeastNWidgets(1));
    expect(find.text('문의가 접수되었어요.'), findsOneWidget);
  });

  testWidgets('opens policy and terms screens from account management', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.accountManagement);
    await tester.tap(find.text('개인정보 처리방침'));
    await tester.pumpAndSettle();
    expect(find.text('얼마고? 개인정보 처리방침'), findsOneWidget);
    expect(find.text('개인정보 보호 책임자'), findsOneWidget);
    final privacyHeader = tester.getRect(
      find.byKey(const ValueKey('privacy-policy-header')),
    );
    final privacyBackIcon = tester.getRect(
      find.byKey(const ValueKey('privacy-policy-back-icon')),
    );
    final privacyActionIcon = tester.getRect(
      find.byKey(const ValueKey('privacy-policy-action-icon')),
    );
    expect(
      privacyBackIcon.left - privacyHeader.left,
      closeTo(privacyHeader.right - privacyActionIcon.right, 0.1),
    );
    expect(privacyBackIcon.width, closeTo(privacyActionIcon.width, 0.1));
    expect(privacyBackIcon.height, closeTo(privacyActionIcon.height, 0.1));
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('privacy-policy-action-icon')),
          )
          .color,
      tester
          .widget<Icon>(find.byKey(const ValueKey('privacy-policy-back-icon')))
          .color,
    );
    final privacyInquiryButton = tester.getRect(
      find.byKey(const ValueKey('privacy-inquiry-button')),
    );
    final privacyInquiryIcon = tester.getRect(
      find.byKey(const ValueKey('privacy-inquiry-icon')),
    );
    final privacyInquiryLabel = tester.getRect(
      find.byKey(const ValueKey('privacy-inquiry-label')),
    );
    final privacyInquiryScale =
        privacyInquiryButton.height / 28.480112075805664;
    expect(
      privacyInquiryLabel.center.dy,
      closeTo(privacyInquiryIcon.center.dy - privacyInquiryScale, 0.1),
    );

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

  testWidgets('terms detail sheet stays inside the mobile app frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.termsOfService);
    await tester.tap(find.text('회원 가입 및 자격'));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(
      find.byKey(const ValueKey('terms-detail-bottom-sheet')),
    );
    expect(sheet.width, lessThanOrEqualTo(430));
    expect(sheet.center.dx, closeTo(600, 0.1));
    expect(sheet.left, greaterThanOrEqualTo(0));
    expect(sheet.right, lessThanOrEqualTo(1200));
    expect(sheet.bottom, lessThanOrEqualTo(650));

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  });

  testWidgets('opens the real search screen without a fabricated query', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.searchResult);

    expect(find.byType(SearchResultScreen), findsOneWidget);
    expect(find.text('주차요금'), findsNothing);
  });

  testWidgets('search filter sheet stays inside the mobile app width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.searchResult);
    await tester.tap(find.bySemanticsLabel('검색 필터 열기'));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(
      find.byKey(const ValueKey('search-filter-sheet')),
    );
    expect(sheet.width, lessThanOrEqualTo(430));
    expect(sheet.center.dx, closeTo(600, 0.1));
    expect(sheet.left, greaterThanOrEqualTo(0));
    expect(sheet.right, lessThanOrEqualTo(1200));
  });

  testWidgets('opens network error state with recovery actions', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.networkError);
    expect(find.text('연결할 수 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('오프라인 저장 기능은 아직 준비 중이에요.'), findsOneWidget);
  });

  testWidgets('opens session expired state with login actions', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.sessionExpired);
    expect(find.text('다시 로그인이 필요해요'), findsOneWidget);
    expect(find.text('로그인 없이 이용 가능'), findsOneWidget);
    expect(find.text('카카오로 다시 로그인'), findsOneWidget);
    expect(find.text('나중에 할게요'), findsOneWidget);
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

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2600));
  await tester.pumpAndSettle();
}

Widget _appWithNotificationSettingsApi() {
  return ProviderScope(
    overrides: [
      notificationSettingsApiServiceProvider.overrideWithValue(
        _FakeNotificationSettingsApiService(),
      ),
      priceAlertApiServiceProvider.overrideWithValue(
        _FakePriceAlertApiService(),
      ),
    ],
    child: const HowmuchApp(),
  );
}

Widget _appWithInquiryApi() {
  return ProviderScope(
    overrides: [
      inquiryServiceProvider.overrideWithValue(_FakeInquiryService()),
    ],
    child: const HowmuchApp(),
  );
}

class _FakeInquiryService extends InquiryService {
  @override
  Future<Map<String, dynamic>> createInquiry({
    required String title,
    required String content,
    String? category,
    List<String> imageUrls = const [],
  }) async {
    return {'success': true, 'id': 'inquiry-1'};
  }
}

class _FakeNotificationSettingsApiService
    extends NotificationSettingsApiService {
  _FakeNotificationSettingsApiService()
    : super(MockClient((_) async => http.Response('{}', 200)));

  NotificationSettings _settings = NotificationSettings.defaults;

  @override
  Future<NotificationSettings> fetchSettings() async => _settings;

  @override
  Future<NotificationSettings> saveSettings(
    NotificationSettings settings,
  ) async {
    _settings = settings;
    return _settings;
  }
}

class _FakePriceAlertApiService extends PriceAlertApiService {
  _FakePriceAlertApiService()
    : super(MockClient((_) async => http.Response('[]', 200)));

  List<PriceAlertStore> _stores = const [
    PriceAlertStore(
      storeId: 'store-1',
      storeName: '착한분식',
      menuName: '김치찌개 5,500원',
      enabled: true,
    ),
  ];

  @override
  Future<PriceAlertSettings> fetchSettings() async => PriceAlertSettings(
    all: _stores.every((store) => store.enabled),
    stores: _stores,
    notifyOnDrop: true,
    notifyOnRise: true,
    notifyOnNewMenu: false,
  );

  @override
  Future<PriceAlertStore> saveSubscription({
    required String storeId,
    required bool enabled,
    required bool notifyOnRise,
    required bool notifyOnDrop,
    required bool notifyOnNewMenu,
  }) async {
    _stores = _stores
        .map(
          (store) => store.storeId == storeId
              ? store.copyWith(enabled: enabled)
              : store,
        )
        .toList(growable: false);
    return _stores.single;
  }

  @override
  Future<PriceAlertSettings> saveSettings(PriceAlertSettings settings) async {
    _stores = settings.stores;
    return settings;
  }
}

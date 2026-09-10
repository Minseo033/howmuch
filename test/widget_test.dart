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
  });

  testWidgets('opens mypage notification and account screens', (tester) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, _appWithNotificationSettingsApi());

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
    expect(find.text('로그인 계정'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
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
    expect(find.text('로그인 정보 없음'), findsOneWidget);
    expect(find.text('현재는 카카오 로그인만 지원합니다.'), findsOneWidget);
    expect(find.text('Apple ID'), findsNothing);
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

  testWidgets('opens profile edit and saves profile visibility', (
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
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname-field')),
      'QA 닉네임',
    );
    await tester.tap(find.text('변경'));
    await tester.pumpAndSettle();
    expect(find.text('QA 닉네임'), findsOneWidget);

    await tester.tap(find.text('활동 내역 공개'));
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

    await tester.tap(find.text('문의하기'));
    await tester.pumpAndSettle();
    expect(find.text('문의 유형'), findsOneWidget);
    expect(find.text('문의 보내기'), findsOneWidget);

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

  testWidgets('opens the real search screen without a fabricated query', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await _pumpApp(tester, const ProviderScope(child: HowmuchApp()));

    await _goToRoute(tester, AppRoutes.searchResult);

    expect(find.byType(SearchResultScreen), findsOneWidget);
    expect(find.text('주차요금'), findsNothing);
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
}

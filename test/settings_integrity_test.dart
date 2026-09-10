import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_theme.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/location_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/account_management_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/withdrawal_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TestPermissions extends DevicePermissionService {
  @override
  bool get web => true;
  @override
  bool get supportsPush => false;
  @override
  Future<DeviceAccess> location() async => DeviceAccess.denied;
  @override
  Future<DeviceAccess> push() async => DeviceAccess.unsupported;
}

class TestSettingsApi extends NotificationSettingsApiService {
  TestSettingsApi() : super(MockClient((_) async => http.Response('{}', 500)));
  NotificationSettings stored = NotificationSettings.defaults;
  int saves = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<NotificationSettings> fetchSettings() async => stored;
  @override
  Future<NotificationSettings> saveSettings(
    NotificationSettings settings,
  ) async {
    saves++;
    if (pending != null) await pending!.future;
    if (fail) throw const NotificationSettingsApiException('failed');
    return stored = settings;
  }
}

class TestPriceApi extends PriceAlertApiService {
  TestPriceApi({int count = 12})
    : super(MockClient((_) async => http.Response('[]', 500))) {
    stored = PriceAlertSettings(
      all: count > 0,
      stores: List.generate(
        count,
        (i) => PriceAlertStore(
          storeId: 'store_$i',
          storeName: '검증용 매장 $i 아주 긴 이름과 지점 안내',
          menuName: '긴 메뉴 이름과 가격 7,000원',
          enabled: true,
        ),
      ),
      notifyOnDrop: true,
      notifyOnRise: true,
      notifyOnNewMenu: false,
    );
  }
  late PriceAlertSettings stored;
  int saves = 0;
  @override
  Future<PriceAlertSettings> fetchSettings() async => stored;
  @override
  Future<PriceAlertSettings> saveSettings(PriceAlertSettings value) async {
    saves++;
    return stored = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const preview = bool.fromEnvironment('HOWMUCH_SETTINGS_PREVIEW');
  setUpAll(() async {
    if (!preview) return;
    final bytes = await File(
      'assets/fonts/NotoSansKR-Variable.ttf',
    ).readAsBytes();
    for (final family in ['Noto Sans KR', 'Inter']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    TestSettingsApi? api,
    TestPriceApi? price,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: '/mypage',
          builder: (_, _) => const Scaffold(body: Text('마이페이지 도착')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devicePermissionServiceProvider.overrideWithValue(TestPermissions()),
          notificationSettingsApiServiceProvider.overrideWithValue(
            api ?? TestSettingsApi(),
          ),
          priceAlertApiServiceProvider.overrideWithValue(
            price ?? TestPriceApi(),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'notification edits stay local, guard exit, save only after acknowledgement',
    (tester) async {
      final api = TestSettingsApi();
      await pump(tester, const NotificationSettingsScreen(), api: api);
      expect(find.text('브라우저 푸시는 지원하지 않아요'), findsOneWidget);
      await reveal(tester, find.text('가격 변동 알림'));
      await tester.tap(find.text('가격 변동 알림'));
      await tester.pumpAndSettle();
      expect(api.saves, 0);
      expect(api.stored.price, isTrue);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      api.pending = Completer();
      await tester.tap(find.text('설정 저장'));
      await tester.pump();
      expect(api.saves, 1);
      expect(find.text('저장 중…'), findsOneWidget);
      expect(
        tester
            .widgetList<SettingsToggle>(find.byType(SettingsToggle))
            .every((toggle) => toggle.onChanged == null),
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '저장 중…'))
            .onPressed,
        isNull,
      );
      api.pending!.complete();
      await tester.pumpAndSettle();
      expect(api.stored.price, isFalse);
      expect(api.stored.report, isTrue);
      expect(find.text('알림 설정을 저장했어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save preserves draft and retry persists it', (
    tester,
  ) async {
    final api = TestSettingsApi()..fail = true;
    await pump(tester, const NotificationSettingsScreen(), api: api);
    await reveal(tester, find.text('가격 변동 알림'));
    await tester.tap(find.text('가격 변동 알림'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('변경 내용은 유지돼요'), findsOneWidget);
    expect(api.stored.price, isTrue);
    api.fail = false;
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(api.stored.price, isFalse);
  });

  testWidgets('quiet hours cannot silently have equal endpoints', (
    tester,
  ) async {
    final api = TestSettingsApi()
      ..stored = NotificationSettings.defaults.copyWith(
        quietStart: '08:00',
        quietEnd: '08:00',
      );
    await pump(tester, const NotificationSettingsScreen(), api: api);
    await reveal(tester, find.text('방해 금지'));
    await tester.tap(find.text('방해 금지'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(api.saves, 0);
    expect(find.textContaining('시간을 다르게 선택'), findsOneWidget);
  });

  testWidgets('price conditions persist for an account with zero stores', (
    tester,
  ) async {
    final api = TestPriceApi(count: 0);
    await pump(tester, const PriceAlertSubscriptionScreen(), price: api);
    expect(find.text('매장 찾아보기'), findsOneWidget);
    await reveal(tester, find.text('가격 인하'));
    await tester.tap(find.text('가격 인하'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(api.saves, 1);
    expect(api.stored.notifyOnDrop, isFalse);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(568, 320),
    const Size(768, 1024),
    const Size(1280, 800),
  ]) {
    testWidgets('long price list remains scrollable at $size and 2x text', (
      tester,
    ) async {
      await pump(
        tester,
        const PriceAlertSubscriptionScreen(),
        size: size,
        scale: 2,
      );
      await reveal(tester, find.byKey(const ValueKey('price-alert-store_11')));
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('신메뉴'));
      await tester.tap(find.text('신메뉴'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('설정 저장')).bottom,
        lessThanOrEqualTo(size.height),
      );
    });
  }

  testWidgets('location shows measured denial and no fixed allowed label', (
    tester,
  ) async {
    await pump(tester, const LocationSettingsScreen());
    expect(find.text('허용 필요'), findsOneWidget);
    expect(find.text('허용'), findsNothing);
    expect(find.text('위치 권한 요청'), findsOneWidget);
  });

  testWidgets(
    'withdrawal consent starts unchecked and cannot open delete dialog',
    (tester) async {
      await pump(tester, const WithdrawalScreen());
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('withdrawal-consent')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '탈퇴하기'))
            .onPressed,
        isNull,
      );
      await reveal(tester, find.byKey(const ValueKey('withdrawal-consent')));
      await tester.tap(find.byKey(const ValueKey('withdrawal-consent')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
      await tester.tap(find.text('계정 유지').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  if (preview) {
    for (final entry in <String, Widget>{
      'notifications': const NotificationSettingsScreen(),
      'price-alerts': const PriceAlertSubscriptionScreen(),
      'account': const AccountManagementScreen(),
      'location': const LocationSettingsScreen(),
      'withdrawal': const WithdrawalScreen(),
      'mypage': const MypageScreen(),
      'profile': const ProfileEditScreen(),
      'notifications-desktop': const NotificationSettingsScreen(),
      'mypage-large-text': const MypageScreen(),
    }.entries) {
      testWidgets(
        'render real ${entry.key} widgets with labeled test fixtures',
        (tester) async {
          await pump(
            tester,
            entry.value,
            size: entry.key.endsWith('desktop')
                ? const Size(1280, 800)
                : const Size(390, 844),
            scale: entry.key.endsWith('large-text') ? 2 : 1,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../build/qa/settings-${entry.key}.png'),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final entry in <String, Widget>{
    'notifications': const NotificationSettingsScreen(),
    'account': const AccountManagementScreen(),
    'location': const LocationSettingsScreen(),
    'withdrawal': const WithdrawalScreen(),
    'mypage': const MypageScreen(),
  }.entries) {
    testWidgets('${entry.key} remains usable at 320px with 2x text', (
      tester,
    ) async {
      await pump(tester, entry.value, size: const Size(320, 568), scale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('empty favorites fetch the actual saved account conditions', () async {
    final requests = <String>[];
    final api = PriceAlertApiService(
      MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(
          request.url.path.endsWith('/price-alerts')
              ? '[]'
              : '{"notifyOnRise":false,"notifyOnDrop":false,"notifyOnNewMenu":true}',
          200,
        );
      }),
    );
    final value = await api.fetchSettings();
    expect(value.stores, isEmpty);
    expect(value.notifyOnRise, isFalse);
    expect(value.notifyOnDrop, isFalse);
    expect(value.notifyOnNewMenu, isTrue);
    expect(requests, [
      '/api/notifications/price-alerts',
      '/api/notifications/settings',
    ]);
  });

  test(
    'malformed settings are not replaced with fabricated defaults',
    () async {
      final api = NotificationSettingsApiService(
        MockClient((_) async => http.Response('{}', 200)),
      );
      expect(api.fetchSettings, throwsFormatException);
    },
  );

  test(
    'price batch API sends empty stores and rejects unacknowledged success',
    () async {
      final api = PriceAlertApiService(
        MockClient((request) async {
          expect(request.url.path, '/api/notifications/price-alerts/batch');
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body)['stores'], isEmpty);
          return http.Response('{"success":false}', 200);
        }),
      );
      expect(
        () => api.saveSettings(TestPriceApi(count: 0).stored),
        throwsFormatException,
      );
    },
  );
}

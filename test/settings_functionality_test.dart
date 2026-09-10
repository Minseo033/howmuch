import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestSettingsApi extends NotificationSettingsApiService {
  _TestSettingsApi({this.initial = NotificationSettings.defaults})
    : super(MockClient((_) async => http.Response('{}', 500)));

  final NotificationSettings initial;
  int saves = 0;
  bool fail = false;
  Completer<void>? pending;

  @override
  Future<NotificationSettings> fetchSettings() async => initial;

  @override
  Future<NotificationSettings> saveSettings(
    NotificationSettings settings,
  ) async {
    saves++;
    await pending?.future;
    if (fail) throw const NotificationSettingsApiException('failed');
    return settings;
  }
}

class _TestPriceApi extends PriceAlertApiService {
  _TestPriceApi() : super(MockClient((_) async => http.Response('{}', 500)));

  @override
  Future<PriceAlertSettings> fetchSettings() async => PriceAlertSettings(
    all: true,
    stores: List.generate(
      12,
      (index) => PriceAlertStore(
        storeId: 'store-$index',
        storeName: '검증 매장 $index',
        menuName: '메뉴 ${index + 1}',
        enabled: true,
      ),
    ),
    notifyOnDrop: true,
    notifyOnRise: true,
    notifyOnNewMenu: false,
  );
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    _TestSettingsApi? settingsApi,
    _TestPriceApi? priceApi,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: AppRoutes.mypage,
          builder: (_, _) => const Scaffold(body: Text('마이페이지')),
        ),
        GoRoute(
          path: AppRoutes.notificationSettings,
          builder: (_, _) => const Scaffold(body: Text('알림 설정 도착')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (settingsApi != null)
            notificationSettingsApiServiceProvider.overrideWithValue(
              settingsApi,
            ),
          if (priceApi != null)
            priceAlertApiServiceProvider.overrideWithValue(priceApi),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('notification save cannot run twice while pending', (
    tester,
  ) async {
    final api = _TestSettingsApi()..pending = Completer<void>();
    await pumpScreen(
      tester,
      const NotificationSettingsScreen(),
      settingsApi: api,
    );

    await tester.tap(find.text('가격 변동 알림'));
    await tester.tap(find.text('설정 저장'));
    await tester.pump();

    expect(api.saves, 1);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    api.pending!.complete();
    await tester.pumpAndSettle();
    expect(api.saves, 1);
  });

  testWidgets('failed notification save keeps the edited draft', (
    tester,
  ) async {
    final api = _TestSettingsApi()..fail = true;
    await pumpScreen(
      tester,
      const NotificationSettingsScreen(),
      settingsApi: api,
    );

    await tester.tap(find.text('가격 변동 알림'));
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationSettingsScreen)),
    );
    expect(container.read(notificationSettingsProvider).value!.price, isFalse);
    expect(find.textContaining('다시 시도해 주세요'), findsOneWidget);
  });

  testWidgets('equal quiet-hour endpoints are rejected before saving', (
    tester,
  ) async {
    final api = _TestSettingsApi(
      initial: NotificationSettings.defaults.copyWith(
        quietHours: true,
        quietStart: '08:00',
        quietEnd: '08:00',
      ),
    );
    await pumpScreen(
      tester,
      const NotificationSettingsScreen(),
      settingsApi: api,
    );

    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();

    expect(api.saves, 0);
    expect(find.textContaining('시간을 다르게 선택'), findsOneWidget);
  });

  testWidgets('long price-alert store list scrolls inside the existing card', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const PriceAlertSubscriptionScreen(),
      priceApi: _TestPriceApi(),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('검증 매장 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;

const _settings = PriceAlertSettings(
  all: true,
  stores: [
    PriceAlertStore(
      storeId: 'store-1',
      storeName: '착한식당',
      menuName: '비빔밥',
      enabled: true,
    ),
  ],
  notifyOnRise: true,
  notifyOnDrop: true,
  notifyOnNewMenu: false,
);

class _ConflictApi extends PriceAlertApiService {
  _ConflictApi() : super(http.Client());

  var fetches = 0;
  var saves = 0;
  Completer<void>? firstFetch;

  @override
  Future<PriceAlertSettings> fetchSettings() async {
    fetches++;
    await firstFetch?.future;
    return _settings;
  }

  @override
  Future<PriceAlertSettings> saveSettings(PriceAlertSettings settings) async {
    saves++;
    throw const PriceAlertApiException(
      '찜 목록이 변경됐어요. 다시 불러온 뒤 저장해 주세요.',
      statusCode: 409,
    );
  }
}

Future<void> _pump(WidgetTester tester, _ConflictApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: AppRoutes.priceAlertSubscription,
    routes: [
      GoRoute(
        path: AppRoutes.priceAlertSubscription,
        builder: (_, _) => const PriceAlertSubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (_, _) => const Scaffold(body: Text('알림 설정 화면')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        priceAlertSettingsProvider.overrideWith(
          (ref) => PriceAlertSettingsNotifier(api),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('a 409 save explains itself and reloads instead of retrying', (
    tester,
  ) async {
    final api = _ConflictApi();
    await _pump(tester, api);
    await tester.pumpAndSettle();

    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();

    expect(api.saves, 1);
    expect(api.fetches, 2, reason: 'the stale list is replaced');
    expect(find.textContaining('찜 목록이 바뀌어 최신 목록을 다시 불러왔어요'), findsOneWidget);
  });

  testWidgets('loading state keeps the header and a way back', (tester) async {
    final api = _ConflictApi()..firstFetch = Completer<void>();
    await _pump(tester, api);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('가격 알림 구독'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('알림 설정 화면'), findsOneWidget);
    api.firstFetch!.complete();
  });
}

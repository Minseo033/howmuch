import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;

class _FakePriceAlertApiService extends PriceAlertApiService {
  _FakePriceAlertApiService(this.settings) : super(http.Client());

  PriceAlertSettings settings;
  bool saveCalled = false;

  @override
  Future<PriceAlertSettings> fetchSettings() async => settings;

  @override
  Future<PriceAlertSettings> saveSettings(
    PriceAlertSettings newSettings,
  ) async {
    saveCalled = true;
    settings = newSettings;
    return newSettings;
  }
}

void main() {
  group('PriceAlertSubscriptionScreen regression tests', () {
    late PriceAlertSettings initialSettings;
    late _FakePriceAlertApiService fakeApi;

    setUp(() {
      initialSettings = const PriceAlertSettings(
        all: true,
        stores: [
          PriceAlertStore(
            storeId: 'store-1',
            storeName: '착한식당 1호점',
            menuName: '비빔밥 5,000원',
            enabled: true,
          ),
          PriceAlertStore(
            storeId: 'store-2',
            storeName: '착한분식 2호점',
            menuName: '라면 3,000원',
            enabled: true,
          ),
        ],
        notifyOnRise: true,
        notifyOnDrop: true,
        notifyOnNewMenu: true,
      );
      fakeApi = _FakePriceAlertApiService(initialSettings);
    });

    Widget createTestApp() {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PriceAlertSubscriptionScreen(),
          ),
          GoRoute(
            path: '/mypage/notification-settings',
            builder: (context, state) => const Scaffold(body: Text('설정화면')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          priceAlertApiServiceProvider.overrideWithValue(fakeApi),
          priceAlertSettingsProvider.overrideWith(
            (ref) => PriceAlertSettingsNotifier(fakeApi),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets(
      'renders all sections and ensures 새 메뉴 등록 is not occluded by sticky button',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Check header and sections
        expect(find.text('가격 알림 구독'), findsOneWidget);
        expect(find.text('전체 알림'), findsOneWidget);
        expect(find.text('매장별 알림'), findsOneWidget);
        expect(find.text('착한식당 1호점'), findsOneWidget);
        expect(find.text('착한분식 2호점'), findsOneWidget);
        expect(find.text('알림 조건'), findsOneWidget);
        expect(find.text('가격 인상'), findsOneWidget);
        expect(find.text('가격 인하'), findsOneWidget);
        expect(find.text('새 메뉴 등록'), findsOneWidget);

        // Scroll to the bottom by dragging outside the nested ListView
        await tester.drag(find.text('알림 조건'), const Offset(0, -400));
        await tester.pumpAndSettle();

        // P0 regression verification: 새 메뉴 등록 must be fully above the sticky button top
        final newMenuFinder = find.text('새 메뉴 등록');
        final saveButtonFinder = find.text('설정 저장');

        expect(newMenuFinder, findsOneWidget);
        expect(saveButtonFinder, findsOneWidget);

        final newMenuBottom = tester.getBottomRight(newMenuFinder).dy;
        final saveButtonTop = tester.getTopLeft(saveButtonFinder).dy;

        expect(
          newMenuBottom,
          lessThan(saveButtonTop),
          reason:
              '새 메뉴 등록 ($newMenuBottom) must be strictly above sticky button ($saveButtonTop) without occlusion',
        );
      },
    );

    testWidgets(
      'toggling 새 메뉴 등록 switch updates local state and saves correctly',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Scroll to condition card
        await tester.drag(find.text('알림 조건'), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Tap 새 메뉴 등록 row
        await tester.tap(find.text('새 메뉴 등록'));
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.text('설정 저장'));
        await tester.pumpAndSettle();

        expect(fakeApi.saveCalled, isTrue);
        expect(fakeApi.settings.notifyOnNewMenu, isFalse);
      },
    );

    testWidgets(
      'renders without overflow on narrow 320x568 and keeps 새 메뉴 등록 accessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Scroll down using outer scrollable
        final outerScrollable = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        );
        final scrollState = tester.state<ScrollableState>(
          outerScrollable.first,
        );
        scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final newMenuBottom = tester.getBottomRight(find.text('새 메뉴 등록')).dy;
        final saveButtonTop = tester.getTopLeft(find.text('설정 저장')).dy;

        expect(
          newMenuBottom,
          lessThan(saveButtonTop),
          reason:
              '새 메뉴 등록 must remain unoccluded even on 320x568 narrow screen',
        );
      },
    );

    testWidgets(
      'renders without overflow on 568x320 landscape mode with compact sticky footer',
      (tester) async {
        tester.view.physicalSize = const Size(568, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Scroll down in landscape using outer scrollable
        final outerScrollable = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        );
        final scrollState = tester.state<ScrollableState>(
          outerScrollable.first,
        );
        scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('새 메뉴 등록'), findsOneWidget);

        final newMenuBottom = tester.getBottomRight(find.text('새 메뉴 등록')).dy;
        final saveButtonTop = tester.getTopLeft(find.text('설정 저장')).dy;

        expect(
          newMenuBottom,
          lessThan(saveButtonTop),
          reason:
              '새 메뉴 등록 must be fully above compact footer in landscape mode',
        );
      },
    );
  });
}

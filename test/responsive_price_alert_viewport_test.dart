import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/widgets/web_notification_prompt.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MockPriceApi extends PriceAlertApiService {
  _MockPriceApi() : super(MockClient((_) async => http.Response('{}', 500)));

  @override
  Future<PriceAlertSettings> fetchSettings() async => PriceAlertSettings(
    all: true,
    stores: List.generate(
      4,
      (index) => PriceAlertStore(
        storeId: 'store-$index',
        storeName: '테스트 매장 $index',
        menuName: '대표 메뉴 ${index + 1}',
        enabled: true,
      ),
    ),
    notifyOnDrop: true,
    notifyOnRise: true,
    notifyOnNewMenu: false,
  );
}

void main() {
  group('FigmaMobileCanvas responsive layout', () {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
        'renders properly at $size without miniaturization or overflow',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          late BuildContext capturedContext;
          await tester.pumpWidget(
            MaterialApp(
              home: FigmaMobileCanvas(
                child: Builder(
                  builder: (context) {
                    capturedContext = context;
                    return const SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 100, child: Text('Top Section')),
                          SizedBox(height: 400, child: Text('Middle Section')),
                          SizedBox(height: 100, child: Text('Bottom Section')),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(FigmaMobileCanvas.designScaleFor(capturedContext), 1.0);

          if (size.width <= FigmaMobileCanvas.maxWebWidth) {
            expect(
              FigmaMobileCanvas.logicalWidthOf(capturedContext),
              size.width,
            );
          } else {
            expect(
              FigmaMobileCanvas.logicalWidthOf(capturedContext),
              FigmaMobileCanvas.maxWebWidth,
            );
          }
        },
      );
    }

    testWidgets('preserves desktop max-width shell at 1280x800', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: FigmaMobileCanvas(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const Center(child: Text('Desktop Content'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        FigmaMobileCanvas.logicalWidthOf(capturedContext),
        FigmaMobileCanvas.maxWebWidth,
      );
    });
  });

  group('PriceAlertSubscriptionScreen responsive and scroll clearance', () {
    Future<void> pumpPriceAlertScreen(
      WidgetTester tester, {
      required Size viewportSize,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewportSize;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const PriceAlertSubscriptionScreen(),
          ),
          GoRoute(
            path: AppRoutes.notificationSettings,
            builder: (_, _) => const Scaffold(body: Text('알림 설정')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priceAlertApiServiceProvider.overrideWithValue(_MockPriceApi()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'at 320x568 content scrolls fully above sticky footer with touch targets >= 44',
      (tester) async {
        await pumpPriceAlertScreen(tester, viewportSize: const Size(320, 568));

        expect(find.text('가격 알림 구독'), findsOneWidget);
        expect(find.text('설정 저장'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verify back button touch target >= 44
        final backButtonFinder = find.byIcon(Icons.arrow_back_rounded);
        expect(backButtonFinder, findsOneWidget);
        final inkWellFinder = find.ancestor(
          of: backButtonFinder,
          matching: find.byType(InkWell),
        );
        expect(inkWellFinder, findsWidgets);
        final inkWellSize = tester.getSize(inkWellFinder.first);
        expect(inkWellSize.width, greaterThanOrEqualTo(44));
        expect(inkWellSize.height, greaterThanOrEqualTo(44));

        // Scroll down to the bottom
        await tester.drag(find.text('전체 알림'), const Offset(0, -600));
        await tester.pumpAndSettle();

        // '새 메뉴 등록' must be fully visible and clear of the sticky footer
        final newMenuFinder = find.text('새 메뉴 등록');
        expect(newMenuFinder, findsOneWidget);

        final newMenuBottom = tester.getBottomLeft(newMenuFinder).dy;
        final stickyButtonTop = tester.getTopLeft(find.text('설정 저장')).dy;
        expect(
          newMenuBottom,
          lessThan(stickyButtonTop),
          reason:
              "'새 메뉴 등록' must be completely above the sticky '설정 저장' button",
        );

        // Verify sticky button height >= 44
        final buttonFinder = find.ancestor(
          of: find.text('설정 저장'),
          matching: find.byType(ElevatedButton),
        );
        expect(buttonFinder, findsOneWidget);
        final buttonSize = tester.getSize(buttonFinder);
        expect(buttonSize.height, greaterThanOrEqualTo(44));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'at 568x320 landscape content scrolls fully above sticky footer',
      (tester) async {
        await pumpPriceAlertScreen(tester, viewportSize: const Size(568, 320));

        expect(find.text('가격 알림 구독'), findsOneWidget);
        expect(find.text('설정 저장'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Scroll down to the bottom
        final scrollableFinder = find.byType(Scrollable).first;
        await tester.drag(scrollableFinder, const Offset(0, -800));
        await tester.pumpAndSettle();

        final newMenuFinder = find.text('새 메뉴 등록');
        expect(newMenuFinder, findsOneWidget);

        final newMenuBottom = tester.getBottomLeft(newMenuFinder).dy;
        final stickyButtonTop = tester.getTopLeft(find.text('설정 저장')).dy;
        expect(
          newMenuBottom,
          lessThan(stickyButtonTop),
          reason:
              "In landscape 568x320, '새 메뉴 등록' must scroll above sticky footer",
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('WebNotificationPrompt banner in landscape and touch targets', () {
    testWidgets('dismisses cleanly at 568x320 with touch targets >= 44', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(568, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = _MockNotificationsNotifier([
        NotificationModel(
          id: 'alert-1',
          section: '오늘',
          type: '알림',
          tabCategory: '전체',
          iconData: Icons.notifications_none,
          iconColor: Colors.blue,
          iconBgColor: Colors.white,
          borderColor: Colors.grey,
          bgColor: Colors.white,
          categoryColor: Colors.blue,
          timeText: '',
          title: '새 가격 변동 알림',
          messageText: '테스트 알림입니다.',
          isUnread: true,
        ),
      ]);
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => const AuthState(
                isLoggedIn: true,
                provider: '카카오',
                email: 'test@example.com',
              ),
            ),
            notificationsProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: WebNotificationPrompt(
              isHome: false,
              onOpenNotifications: () {},
              navigatorKey: navigatorKey,
              child: const Scaffold(body: Center(child: Text('앱 메인 화면'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('web-notification-banner')),
        findsOneWidget,
      );

      // Verify touch target for dismiss button >= 44x44
      final dismissButtonFinder = find.bySemanticsLabel('알림 안내 닫기');
      expect(dismissButtonFinder, findsOneWidget);
      final dismissSize = tester.getSize(dismissButtonFinder);
      expect(dismissSize.width, greaterThanOrEqualTo(44));
      expect(dismissSize.height, greaterThanOrEqualTo(44));

      // Verify touch target for open button >= 44
      final openButtonFinder = find.ancestor(
        of: find.text('알림함 보기'),
        matching: find.byType(TextButton),
      );
      expect(openButtonFinder, findsOneWidget);
      final openSize = tester.getSize(openButtonFinder);
      expect(openSize.height, greaterThanOrEqualTo(44));

      // Dismiss banner
      await tester.tap(dismissButtonFinder);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('web-notification-banner-visibility')),
            )
            .transform
            .getTranslation()
            .y,
        -240,
      );
      expect(find.text('앱 메인 화면'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _MockNotificationsNotifier extends NotificationsNotifier {
  _MockNotificationsNotifier(List<NotificationModel> notifications)
    : super(
        NotificationApiService(
          MockClient((_) async => throw UnimplementedError()),
        ),
      ) {
    state = AsyncValue.data(notifications);
  }
}

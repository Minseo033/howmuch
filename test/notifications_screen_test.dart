import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/system/presentation/screens/notifications_screen.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets('notice opens a scrollable full body and closes at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final body = '공지 본문의 줄바꿈을 유지합니다.\n두 번째 문단도 읽을 수 있어야 합니다.\n' * 20;
    final notifier = _SeededNotificationsNotifier([_notice(body: body)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
      ),
    );
    await tester.tap(find.text('전체 내용 보기'));
    await tester.pumpAndSettle();
    final detail = find.byKey(const ValueKey('notification-detail'));
    expect(detail, findsOneWidget);
    final content = find.descendant(of: detail, matching: find.text(body));
    expect(content, findsOneWidget);
    expect(tester.widget<Text>(content).maxLines, isNull);
    expect(
      find.descendant(of: detail, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('알림 상세 닫기'));
    await tester.pumpAndSettle();
    expect(detail, findsNothing);
    expect(find.text('전체 내용 보기'), findsOneWidget);
  });

  testWidgets('unread notice is marked read before its detail opens', (
    tester,
  ) async {
    var readRequests = 0;
    final notifier = NotificationsNotifier(
      NotificationApiService(
        MockClient((request) async {
          readRequests++;
          return http.Response('{}', 200);
        }),
      ),
    );
    notifier.state = AsyncValue.data([_notice(body: '전체 공지 본문', unread: true)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
      ),
    );
    await tester.tap(find.text('전체 내용 보기'));
    await tester.pumpAndSettle();
    expect(readRequests, 1);
    expect(notifier.state.requireValue.single.isUnread, isFalse);
    expect(find.byKey(const ValueKey('notification-detail')), findsOneWidget);
  });

  testWidgets('routed notifications keep their existing navigation', (
    tester,
  ) async {
    final notifier = _SeededNotificationsNotifier([
      _notice(type: '문의 답변', body: '답변을 확인해 주세요.'),
    ]);
    final router = GoRouter(
      initialLocation: AppRoutes.notifications,
      routes: [
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const Scaffold(body: NotificationsScreen()),
        ),
        GoRoute(
          path: AppRoutes.inquiryHistory,
          builder: (_, _) => const Scaffold(body: Text('문의 내역 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    expect(find.text('전체 내용 보기'), findsNothing);
    await tester.tap(find.text('답변을 확인해 주세요.'));
    await tester.pumpAndSettle();
    expect(find.text('문의 내역 화면'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-detail')), findsNothing);
  });

  testWidgets(
    'bulk button disables while pending and shows partial failure count',
    (tester) async {
      final pending = Completer<http.Response>();
      final notifier = NotificationsNotifier(
        NotificationApiService(
          MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  {'id': 'a', 'isRead': false},
                  {'id': 'b', 'isRead': false},
                ]),
                200,
              );
            }
            if (request.url.path.contains('/a/')) return pending.future;
            return http.Response('{}', 200);
          }),
        ),
      );
      await notifier.loadNotifications();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationsProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
        ),
      );
      await tester.tap(find.text('모두 읽음'));
      await tester.pump();
      final pendingButton = find.widgetWithText(TextButton, '처리 중…');
      expect(tester.widget<TextButton>(pendingButton).onPressed, isNull);
      pending.complete(http.Response('{}', 500));
      await tester.pumpAndSettle();
      expect(find.text('1개 알림을 읽음으로 바꾸지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '모두 읽음'))
            .onPressed,
        isNotNull,
      );
      expect(notifier.state.requireValue.map((n) => n.isUnread), [true, false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders long notification content at 360px without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = _SeededNotificationsNotifier([
      NotificationModel(
        id: 'notification-1',
        section: '오늘',
        type: '아주 긴 알림 분류 이름이 들어오는 경우',
        tabCategory: '전체',
        iconData: Icons.notifications_none,
        iconColor: Colors.blue,
        iconBgColor: Colors.blue.shade50,
        borderColor: Colors.blue.shade100,
        bgColor: Colors.white,
        categoryColor: Colors.blue,
        timeText: '· 59분 전',
        title: '긴 제목이 여러 줄로 전달되더라도 카드 바깥으로 밀려나지 않아야 합니다 ' * 2,
        messageText: '관리자가 작성한 긴 알림 본문이 모바일 화면에 표시되는 상황을 검증합니다 ' * 5,
        isUnread: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('알림'), findsOneWidget);
    expect(find.text('모두 읽음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty notification state', (tester) async {
    final notifier = _SeededNotificationsNotifier(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('받은 알림이 없어요'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '모두 읽음'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('back button returns home when inbox has no previous route', (
    tester,
  ) async {
    final notifier = _SeededNotificationsNotifier(const []);
    final router = GoRouter(
      initialLocation: AppRoutes.notifications,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('홈 화면')),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const NotificationsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(find.text('홈 화면'), findsOneWidget);
  });

  testWidgets('system back returns home after direct notification entry', (
    tester,
  ) async {
    final notifier = _SeededNotificationsNotifier(const []);
    final router = GoRouter(
      initialLocation: AppRoutes.notifications,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('홈 화면')),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const NotificationsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(find.text('홈 화면'), findsOneWidget);
  });

  testWidgets('back button pops to the page that opened the inbox', (
    tester,
  ) async {
    final notifier = _SeededNotificationsNotifier(const []);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(AppRoutes.notifications),
              child: const Text('알림함 열기'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const NotificationsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('알림함 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(find.text('알림함 열기'), findsOneWidget);
  });
}

NotificationModel _notice({
  required String body,
  String type = '공지사항',
  bool unread = false,
}) => NotificationModel(
  id: 'notice-qa',
  section: '오늘',
  type: type,
  tabCategory: '전체',
  iconData: Icons.notifications_none,
  iconColor: Colors.blue,
  iconBgColor: Colors.white,
  borderColor: Colors.grey,
  bgColor: Colors.white,
  categoryColor: Colors.blue,
  timeText: '· 1분 전',
  title: '새로운 서비스 안내',
  messageText: body,
  isUnread: unread,
);

class _SeededNotificationsNotifier extends NotificationsNotifier {
  _SeededNotificationsNotifier(List<NotificationModel> notifications)
    : super(
        NotificationApiService(
          MockClient((_) async => throw UnimplementedError()),
        ),
      ) {
    state = AsyncValue.data(notifications);
  }
}

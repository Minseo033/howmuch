import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/howmuch_app.dart' show CustomWebScrollBehavior;
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/system/presentation/screens/notifications_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/testing.dart';

final _loggedIn = authStateProvider.overrideWith(
  (ref) => const AuthState(isLoggedIn: true, provider: '카카오', email: ''),
);

void main() {
  group('the inbox reloads when dragged down (QA 2026-10-07 #22)', () {
    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      testWidgets('with a ${kind.name} drag', (tester) async {
        var fetches = 0;
        final notifier = NotificationsNotifier(
          NotificationApiService(
            MockClient((request) async {
              fetches++;
              return http.Response(
                jsonEncode([
                  if (fetches > 1)
                    {'id': 'n2', 'title': '새 알림', 'body': '새로 온 알림'},
                  {
                    'id': 'n1',
                    'title': '기존 알림',
                    'body': '먼저 온 알림',
                    'isRead': true,
                  },
                ]),
                200,
                headers: const {
                  'content-type': 'application/json; charset=utf-8',
                },
              );
            }),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith((ref) => notifier),
              _loggedIn,
            ],
            // The web app lets a mouse drag lists (CustomWebScrollBehavior).
            child: MaterialApp(
              scrollBehavior: CustomWebScrollBehavior(),
              home: const NotificationsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fetches, 1);
        expect(find.text('새로 온 알림'), findsNothing);

        await tester.drag(
          find.text('먼저 온 알림'),
          const Offset(0, 400),
          kind: kind,
        );
        await tester.pumpAndSettle();

        expect(fetches, 2);
        expect(find.text('새로 온 알림'), findsOneWidget);
      });
    }

    testWidgets('also from the empty inbox', (tester) async {
      var fetches = 0;
      final notifier = NotificationsNotifier(
        NotificationApiService(
          MockClient((_) async {
            fetches++;
            return http.Response('[]', 200);
          }),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith((ref) => notifier),
            _loggedIn,
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('받은 알림이 없어요'), findsOneWidget);

      await tester.drag(find.text('받은 알림이 없어요'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(fetches, 2);
    });
  });

  testWidgets('notice opens a scrollable full body and closes at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final body = '공지 본문의 줄바꿈을 유지합니다.\n두 번째 문단도 읽을 수 있어야 합니다.\n' * 20;
    final notifier = _SeededNotificationsNotifier([_notice(body: body)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
            if (request.url.path.endsWith('/read-all')) {
              return http.Response('', 404);
            }
            if (request.url.path.contains('/a/')) return pending.future;
            return http.Response('{}', 200);
          }),
        ),
      );
      await notifier.loadNotifications();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith((ref) => notifier),
            _loggedIn,
          ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
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

  testWidgets('inbox tabs announce the selected tab', (tester) async {
    final semantics = tester.ensureSemantics();
    final notifier = _SeededNotificationsNotifier(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.text('전체')),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    await tester.tap(find.text('가격 변동'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('가격 변동')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('전체')),
      isSemantics(isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('guest sees a login prompt instead of an endless spinner', (
    tester,
  ) async {
    var requests = 0;
    final notifier = NotificationsNotifier(
      NotificationApiService(
        MockClient((_) async {
          requests++;
          return http.Response('[]', 200);
        }),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('로그인이 필요해요'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('signed-in first visit loads instead of waiting for polling', (
    tester,
  ) async {
    var requests = 0;
    final notifier = NotificationsNotifier(
      NotificationApiService(
        MockClient((_) async {
          requests++;
          return http.Response('[]', 200);
        }),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.text('받은 알림이 없어요'), findsOneWidget);
  });

  testWidgets('a failed read receipt does not block opening the notice', (
    tester,
  ) async {
    final notifier = NotificationsNotifier(
      NotificationApiService(MockClient((_) async => http.Response('{}', 500))),
    );
    notifier.state = AsyncValue.data([_notice(body: '공지 본문', unread: true)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
      ),
    );
    await tester.tap(find.text('전체 내용 보기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notification-detail')), findsOneWidget);
    expect(notifier.state.requireValue.single.isUnread, isTrue);
  });

  testWidgets('comment, report and price notifications open their targets', (
    tester,
  ) async {
    final notifier = _SeededNotificationsNotifier([
      _target('comment', 'FEED_COMMENT', '댓글 알림 본문', postId: 'post-1'),
      _target('report', 'REPORT_APPROVED', '제보 승인 본문', reportId: 'report-1'),
      _target('price', 'PRICE_ALERT', '가격 변동 본문', storeId: 'store-1'),
    ]);
    final api = NotificationApiService(
      MockClient((request) async {
        if (request.url.path == '/api/stores/store-1') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'storeId': 'store-1',
                'storeName': '착한분식',
                'address': '서울 마포구',
                'industry': '분식',
                'menu1': '김밥',
                'price1': '3000',
                'latitude': 37.5,
                'longitude': 126.9,
                'source': 'GOV',
              }),
            ),
            200,
          );
        }
        return http.Response('', 404);
      }),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.notifications,
      routes: [
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const Scaffold(body: NotificationsScreen()),
        ),
        GoRoute(
          path: AppRoutes.communityPostDetail,
          builder: (_, state) =>
              Scaffold(body: Text('게시글 ${state.uri.queryParameters['id']}')),
        ),
        GoRoute(
          path: AppRoutes.reportDetailV2,
          builder: (_, state) =>
              Scaffold(body: Text('제보 ${state.uri.queryParameters['id']}')),
        ),
        GoRoute(
          path: AppRoutes.storeDetail,
          builder: (_, state) =>
              Scaffold(body: Text('매장 ${(state.extra as Store).storeName}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          notificationApiServiceProvider.overrideWithValue(api),
          _loggedIn,
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    for (final (body, expected) in [
      ('댓글 알림 본문', '게시글 post-1'),
      ('제보 승인 본문', '제보 report-1'),
      ('가격 변동 본문', '매장 착한분식'),
    ]) {
      await tester.tap(find.text(body));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('mark all read sends one batch request', (tester) async {
    final posts = <String>[];
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
          posts.add(request.url.path);
          return http.Response('{"success":true,"updated":2}', 200);
        }),
      ),
    );
    await notifier.loadNotifications();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifier),
          _loggedIn,
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
      ),
    );
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();

    expect(posts, ['/api/notifications/read-all']);
    expect(notifier.state.requireValue.map((n) => n.isUnread), [false, false]);
  });
}

NotificationModel _target(
  String id,
  String serverType,
  String body, {
  String? postId,
  String? reportId,
  String? storeId,
}) => NotificationModel(
  id: id,
  section: '오늘',
  type: serverType,
  tabCategory: '전체',
  iconData: Icons.notifications_none,
  iconColor: Colors.blue,
  iconBgColor: Colors.white,
  borderColor: Colors.grey,
  bgColor: Colors.white,
  categoryColor: Colors.blue,
  timeText: '· 1분 전',
  title: body,
  messageText: body,
  isUnread: false,
  serverType: serverType,
  relatedPostId: postId,
  relatedReportId: reportId,
  storeId: storeId,
);

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

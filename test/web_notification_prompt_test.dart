import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/widgets/web_notification_prompt.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('unread signature changes when a notification is replaced', () {
    final first = notificationSignature([
      _notification(id: 'notification-a'),
      _notification(id: 'notification-b'),
    ]);
    final sameSetInDifferentOrder = notificationSignature([
      _notification(id: 'notification-b'),
      _notification(id: 'notification-a'),
    ]);
    final replacementWithSameCount = notificationSignature([
      _notification(id: 'notification-a'),
      _notification(id: 'notification-c'),
    ]);

    expect(first, sameSetInDifferentOrder);
    expect(first, isNot(replacementWithSameCount));
  });

  test('prompt positions stay below the home search and page header', () {
    expect(notificationPromptTop(isHome: true, safeTop: 0), 74);
    expect(notificationPromptTop(isHome: false, safeTop: 0), 66);
    expect(notificationPromptTop(isHome: true, safeTop: 20), 94);
  });

  testWidgets('shows the exact unread count below a standard page header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifier = _SeededNotificationsNotifier([
      _notification(id: 'notification-a'),
      _notification(id: 'notification-b'),
      _notification(id: 'notification-c'),
    ]);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => const AuthState(
              isLoggedIn: true,
              provider: '카카오',
              email: 'qa@example.com',
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
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('읽지 않은 알림 3건'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('web-notification-banner')))
          .dy,
      66,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a notice popup and hides it for the rest of today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notice = _notification(
      id: 'notice-a',
      type: '공지사항',
      title: '서비스 업데이트 안내',
      message: '새로운 기능이 추가됐어요.',
      isUnread: false,
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    Widget app() => ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => const AuthState(
            isLoggedIn: true,
            provider: '카카오',
            email: 'qa@example.com',
          ),
        ),
        notificationsProvider.overrideWith(
          (ref) => _SeededNotificationsNotifier([notice]),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.expand(),
        builder: (context, child) => WebNotificationPrompt(
          isHome: true,
          onOpenNotifications: () {},
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notice-popup')), findsOneWidget);
    expect(find.text('공지사항'), findsOneWidget);
    expect(find.text('서비스 업데이트 안내'), findsOneWidget);
    expect(find.text('새로운 기능이 추가됐어요.'), findsOneWidget);
    expect(find.text('공지사항 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('오늘 하루 보지 않기'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(noticeHiddenDateKey('notice-a')),
      noticeLocalDate(DateTime.now()),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notice-popup')), findsNothing);
  });
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('long notice remains usable at $size with enlarged text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notice = _notification(
        id: 'long-notice',
        type: '공지사항',
        title: List.filled(5, '서비스 업데이트 및 이용 안내').join(' '),
        message: [...List.filled(12, '업데이트 내용을 확인해 주세요.'), '마지막 안내'].join('\n'),
        isUnread: false,
      );
      await _pumpNotice(tester, notice, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('공지사항 닫기').hitTestable(), findsOneWidget);
      expect(find.text('공지사항 보기').hitTestable(), findsOneWidget);
      expect(find.text('오늘 하루 보지 않기').hitTestable(), findsOneWidget);
      expect(find.text('닫기').hitTestable(), findsOneWidget);

      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('notice-popup')),
        matching: find.byType(Scrollable),
      );
      final state = tester.state<ScrollableState>(scrollable);
      expect(state.position.maxScrollExtent, greaterThan(0));
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notice-popup')), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(noticeHiddenDateKey(notice.id)), isNull);
    });
  }

  testWidgets('notice action closes the popup and opens notifications once', (
    tester,
  ) async {
    var opened = 0;
    await _pumpNotice(
      tester,
      _notification(id: 'notice-link', type: '공지사항', isUnread: false),
      onOpen: () => opened++,
    );

    await tester.tap(find.text('공지사항 보기'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.byKey(const ValueKey('notice-popup')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpNotice(
  WidgetTester tester,
  NotificationModel notice, {
  double textScale = 1,
  VoidCallback? onOpen,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => const AuthState(
            isLoggedIn: true,
            provider: '카카오',
            email: 'qa@example.com',
          ),
        ),
        notificationsProvider.overrideWith(
          (ref) => _SeededNotificationsNotifier([notice]),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.expand(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: WebNotificationPrompt(
            isHome: true,
            onOpenNotifications: onOpen ?? () {},
            navigatorKey: navigatorKey,
            child: child ?? const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

NotificationModel _notification({
  required String id,
  String type = '알림',
  String title = '새 알림',
  String message = '내용',
  bool isUnread = true,
}) {
  return NotificationModel(
    id: id,
    section: '오늘',
    type: type,
    tabCategory: '전체',
    iconData: Icons.notifications_none,
    iconColor: Colors.blue,
    iconBgColor: Colors.white,
    borderColor: Colors.grey,
    bgColor: Colors.white,
    categoryColor: Colors.blue,
    timeText: '',
    title: title,
    messageText: message,
    isUnread: isUnread,
  );
}

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

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
          home: WebNotificationPrompt(
            isHome: false,
            onOpenNotifications: () {},
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
    final notice = _notification(
      id: 'notice-a',
      type: '공지사항',
      title: '서비스 업데이트 안내',
      message: '새로운 기능이 추가됐어요.',
    );

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
        home: WebNotificationPrompt(
          isHome: true,
          onOpenNotifications: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notice-popup')), findsOneWidget);
    expect(find.text('서비스 업데이트 안내'), findsOneWidget);
    expect(find.text('새로운 기능이 추가됐어요.'), findsOneWidget);

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
}

NotificationModel _notification({
  required String id,
  String type = '알림',
  String title = '새 알림',
  String message = '내용',
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
    isUnread: true,
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

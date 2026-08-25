import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/widgets/web_notification_prompt.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/testing.dart';

void main() {
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
}

NotificationModel _notification({required String id}) {
  return NotificationModel(
    id: id,
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
    title: '새 알림',
    messageText: '내용',
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

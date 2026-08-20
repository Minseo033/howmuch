import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/system/presentation/screens/notifications_screen.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/testing.dart';

void main() {
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
  });
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

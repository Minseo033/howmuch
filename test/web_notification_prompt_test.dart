import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/widgets/web_notification_prompt.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';

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

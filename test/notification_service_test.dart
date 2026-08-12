import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('NotificationApiService', () {
    test(
      'API failure is exposed instead of returning sample notifications',
      () async {
        final service = NotificationApiService(
          MockClient((_) async => http.Response('server error', 500)),
        );

        await expectLater(
          service.fetchNotifications(),
          throwsA(
            isA<NotificationApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      },
    );

    test('maps the deployed admin notification contract', () async {
      final service = NotificationApiService(
        MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'id': 'notice-1',
                'title': '서비스 점검',
                'body': '오늘 자정에 점검합니다.',
                'type': 'admin',
                'isRead': false,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final notification = (await service.fetchNotifications()).single;

      expect(notification.id, 'notice-1');
      expect(notification.type, '공지사항');
      expect(notification.tabCategory, '전체');
      expect(notification.title, '서비스 점검');
      expect(notification.messageText, '오늘 자정에 점검합니다.');
      expect(notification.isUnread, isTrue);
      expect(notification.section, '오늘');
    });
  });

  group('NotificationSettingsApiService', () {
    test(
      'saves settings with PUT and parses the normalized response',
      () async {
        late http.Request capturedRequest;
        final service = NotificationSettingsApiService(
          MockClient((request) async {
            capturedRequest = request;
            return http.Response(request.body, 200);
          }),
        );
        const settings = NotificationSettings(
          all: false,
          review: true,
          report: false,
          price: true,
          todayPick: false,
          quietHours: true,
          quietStart: '22:30',
          quietEnd: '07:15',
        );

        final saved = await service.saveSettings(settings);

        expect(capturedRequest.method, 'PUT');
        expect(capturedRequest.url.path, '/api/notifications/settings');
        expect(jsonDecode(capturedRequest.body), settings.toJson());
        expect(saved.quietStart, '22:30');
        expect(saved.report, isFalse);
      },
    );
  });
}

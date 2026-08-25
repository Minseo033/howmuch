import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('web notification polling refreshes without a page reload', () {
    expect(
      notificationRefreshInterval(isWeb: true),
      const Duration(seconds: 10),
    );
    expect(
      notificationRefreshInterval(isWeb: false),
      const Duration(minutes: 1),
    );
  });

  group('notificationRouteForType', () {
    test('maps backend and display notification types to destinations', () {
      expect(
        notificationRouteForType('INQUIRY_ANSWER'),
        AppRoutes.inquiryHistory,
      );
      expect(
        notificationRouteForType('가격 변동'),
        AppRoutes.priceAlertSubscription,
      );
      expect(notificationRouteForType('FEED_COMMENT'), AppRoutes.communityFeed);
      expect(notificationRouteForType('RECOMMENDATION'), AppRoutes.todaysPick);
      expect(notificationRouteForType('제보 반려'), AppRoutes.myReportsV2);
    });

    test('leaves generic admin notifications without a destination', () {
      expect(notificationRouteForType('admin'), isNull);
      expect(notificationRouteForType('공지사항'), isNull);
    });
  });

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

    test('maps an inquiry answer notification for the in-app inbox', () async {
      final service = NotificationApiService(
        MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'id': 'inquiry-answer-1',
                'title': '문의 답변이 도착했어요',
                'body': '등록한 문의에 답변이 등록되었습니다.',
                'type': 'INQUIRY_ANSWER',
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

      expect(notification.type, '문의 답변');
      expect(notification.tabCategory, '전체');
      expect(notification.isUnread, isTrue);
    });

    test(
      'maps price alerts and feed comments from the backend contract',
      () async {
        final service = NotificationApiService(
          MockClient(
            (_) async => http.Response(
              jsonEncode([
                {
                  'id': 'price-alert-1',
                  'title': '관심 매장 가격 변동',
                  'body': '찜하신 매장의 가격 변동 제보가 승인되었습니다!',
                  'type': 'PRICE_ALERT',
                  'isRead': false,
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
                {
                  'id': 'feed-comment-1',
                  'title': '새로운 댓글',
                  'body': '회원님의 게시글에 새로운 댓글이 달렸습니다.',
                  'type': 'FEED_COMMENT',
                  'isRead': true,
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
              ]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );

        final notifications = await service.fetchNotifications();

        expect(notifications[0].type, '가격 변동');
        expect(notifications[0].tabCategory, '가격 변동');
        expect(notifications[0].isUnread, isTrue);
        expect(notifications[1].type, '새 댓글');
        expect(notifications[1].tabCategory, '전체');
        expect(notifications[1].isUnread, isFalse);
      },
    );
  });

  test('notification refresh does not overlap an in-flight request', () async {
    final service = _BlockingNotificationApiService();
    final notifier = NotificationsNotifier(service);

    final firstLoad = notifier.loadNotifications();
    await Future<void>.delayed(Duration.zero);
    await notifier.loadNotifications(isRefresh: true);

    expect(service.fetchCount, 1);
    service.complete(const []);
    await firstLoad;
    notifier.dispose();
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

class _BlockingNotificationApiService extends NotificationApiService {
  _BlockingNotificationApiService()
    : super(MockClient((_) async => http.Response('[]', 200)));

  final Completer<List<NotificationModel>> _completer = Completer();
  int fetchCount = 0;

  @override
  Future<List<NotificationModel>> fetchNotifications() {
    fetchCount++;
    return _completer.future;
  }

  void complete(List<NotificationModel> notifications) {
    _completer.complete(notifications);
  }
}

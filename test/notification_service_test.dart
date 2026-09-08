import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'bulk read continues after a failed item and retries only unread items',
    () async {
      final requests = <String>[];
      var failB = true;
      final notifier = NotificationsNotifier(
        NotificationApiService(
          MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  for (final id in ['a', 'b', 'c']) {'id': id, 'isRead': false},
                ]),
                200,
              );
            }
            final id = request.url.pathSegments[2];
            requests.add(id);
            return http.Response('{}', id == 'b' && failB ? 500 : 200);
          }),
        ),
      );
      addTearDown(notifier.dispose);
      await notifier.loadNotifications();
      await expectLater(
        notifier.markAllRead(),
        throwsA(
          isA<NotificationBatchReadException>().having(
            (e) => e.failedCount,
            'failed count',
            1,
          ),
        ),
      );
      expect(requests, ['a', 'b', 'c']);
      expect(notifier.state.requireValue.map((n) => n.isUnread), [
        false,
        true,
        false,
      ]);
      failB = false;
      await notifier.markAllRead();
      expect(requests, ['a', 'b', 'c', 'b']);
      expect(notifier.state.requireValue.every((n) => !n.isUnread), isTrue);
    },
  );

  test(
    'bulk read stops on authorization failure and permits a later retry',
    () async {
      final requests = <String>[];
      var authorized = false;
      final notifier = NotificationsNotifier(
        NotificationApiService(
          MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  for (final id in ['a', 'b']) {'id': id, 'isRead': false},
                ]),
                200,
              );
            }
            requests.add(request.url.pathSegments[2]);
            return http.Response('{}', authorized ? 200 : 401);
          }),
        ),
      );
      addTearDown(notifier.dispose);
      await notifier.loadNotifications();
      await expectLater(
        notifier.markAllRead(),
        throwsA(isA<NotificationApiException>()),
      );
      expect(requests, ['a']);
      authorized = true;
      await notifier.markAllRead();
      expect(requests, ['a', 'a', 'b']);
    },
  );

  test(
    'duplicate bulk actions do not start another request sequence',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final requests = <String>[];
      final notifier = NotificationsNotifier(
        NotificationApiService(
          MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  for (final id in ['a', 'b']) {'id': id, 'isRead': false},
                ]),
                200,
              );
            }
            final id = request.url.pathSegments[2];
            requests.add(id);
            if (id == 'a') started.complete();
            return id == 'a' ? pending.future : http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(notifier.dispose);
      await notifier.loadNotifications();
      final first = notifier.markAllRead();
      await started.future;
      await notifier.markAllRead();
      expect(requests, ['a']);
      pending.complete(http.Response('{}', 200));
      await first;
      expect(requests, ['a', 'b']);
    },
  );

  test(
    'failed read preserves other successful reads and new notifications',
    () async {
      final failedRead = Completer<http.Response>();
      var ids = ['a', 'b'];
      final service = NotificationApiService(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode([
                for (final id in ids) {'id': id, 'isRead': false},
              ]),
              200,
            );
          }
          if (request.url.path.contains('/a/')) return failedRead.future;
          return http.Response('{}', 200);
        }),
      );
      final notifier = NotificationsNotifier(service);
      addTearDown(notifier.dispose);
      await notifier.loadNotifications();
      final readA = notifier.markRead('a');
      final failure = expectLater(
        readA,
        throwsA(isA<NotificationApiException>()),
      );
      await notifier.markRead('b');
      ids = ['a', 'b', 'c'];
      await notifier.loadNotifications(isRefresh: true);
      failedRead.complete(http.Response('failed', 500));
      await failure;
      final state = notifier.state.requireValue;
      expect(state.map((item) => item.id), ['a', 'b', 'c']);
      expect(state.map((item) => item.isUnread), [true, false, true]);
    },
  );

  test('a stale refresh cannot undo a successful read', () async {
    final refresh = Completer<http.Response>();
    var fetchCount = 0;
    final payload = jsonEncode([
      {'id': 'a', 'isRead': false},
    ]);
    final service = NotificationApiService(
      MockClient((request) async {
        if (request.method != 'GET') return http.Response('{}', 200);
        if (++fetchCount == 1) return http.Response(payload, 200);
        return refresh.future;
      }),
    );
    final notifier = NotificationsNotifier(service);
    addTearDown(notifier.dispose);
    await notifier.loadNotifications();
    final loading = notifier.loadNotifications(isRefresh: true);
    await notifier.markRead('a');
    refresh.complete(http.Response(payload, 200));
    await loading;
    expect(notifier.state.requireValue.single.isUnread, isFalse);
  });

  test('failed read after disposal does not write disposed state', () async {
    final readResponse = Completer<http.Response>();
    final service = NotificationApiService(
      MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {'id': 'a', 'isRead': false},
            ]),
            200,
          );
        }
        return readResponse.future;
      }),
    );
    final notifier = NotificationsNotifier(service);
    await notifier.loadNotifications();
    final reading = notifier.markRead('a');
    notifier.dispose();
    readResponse.complete(http.Response('failed', 500));
    await expectLater(reading, completes);
  });

  test('notification polling uses the same low-frequency interval', () {
    expect(
      notificationPollingInterval(isWeb: true),
      const Duration(minutes: 1),
    );
    expect(
      notificationPollingInterval(isWeb: false),
      const Duration(minutes: 1),
    );
  });

  test(
    'notification polling starts only while auto refresh is enabled',
    () async {
      final service = _CountingNotificationApiService();
      final notifier = NotificationsNotifier(
        service,
        refreshInterval: const Duration(milliseconds: 5),
      );

      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(service.fetchCount, 0);

      notifier.setAutoRefreshEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(service.fetchCount, greaterThanOrEqualTo(2));

      notifier.setAutoRefreshEnabled(false);
      final countAfterPause = service.fetchCount;
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(service.fetchCount, countAfterPause);
      notifier.dispose();
    },
  );

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

  test('notification refresh completion is ignored after dispose', () async {
    final service = _BlockingNotificationApiService();
    final notifier = NotificationsNotifier(service);

    final load = notifier.loadNotifications();
    await Future<void>.delayed(Duration.zero);
    notifier.dispose();
    service.complete(const []);

    await expectLater(load, completes);
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

class _CountingNotificationApiService extends NotificationApiService {
  _CountingNotificationApiService()
    : super(MockClient((_) async => http.Response('[]', 200)));

  int fetchCount = 0;

  @override
  Future<List<NotificationModel>> fetchNotifications() async {
    fetchCount++;
    return const [];
  }
}

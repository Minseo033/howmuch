import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('NotificationSettings Serialization & Persistence Tests', () {
    test(
      'NotificationSettings.toJson and fromJson handle all fields including price',
      () {
        const settings = NotificationSettings(
          all: true,
          review: false,
          report: true,
          price: true,
          todayPick: true,
          quietHours: true,
          quietStart: '22:00',
          quietEnd: '08:00',
        );

        final jsonMap = settings.toJson();
        expect(jsonMap['all'], isTrue);
        expect(jsonMap['review'], isFalse);
        expect(jsonMap['report'], isTrue);
        expect(jsonMap['price'], isTrue);
        expect(jsonMap['todayPick'], isTrue);
        expect(jsonMap['quietHours'], isTrue);
        expect(jsonMap['quietStart'], equals('22:00'));
        expect(jsonMap['quietEnd'], equals('08:00'));

        final parsed = NotificationSettings.fromJson(jsonMap);
        expect(parsed.all, isTrue);
        expect(parsed.price, isTrue);
        expect(parsed.report, isTrue);
        expect(parsed.review, isFalse);
        expect(parsed.todayPick, isTrue);
        expect(parsed.quietHours, isTrue);
        expect(parsed.quietStart, equals('22:00'));
        expect(parsed.quietEnd, equals('08:00'));
      },
    );

    test(
      'NotificationSettingsApiService fetches settings from GET /api/notifications/settings',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, endsWith('/api/notifications/settings'));
          expect(request.method, equals('GET'));
          return http.Response(
            jsonEncode({
              'all': true,
              'review': true,
              'report': false,
              'price': true,
              'todayPick': false,
              'quietHours': false,
              'quietStart': '23:00',
              'quietEnd': '07:00',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = NotificationSettingsApiService(mockClient);
        final settings = await service.fetchSettings();

        expect(settings.all, isTrue);
        expect(settings.review, isTrue);
        expect(settings.report, isFalse);
        expect(settings.price, isTrue);
        expect(settings.todayPick, isFalse);
        expect(settings.quietHours, isFalse);
      },
    );

    test(
      'NotificationSettingsApiService saves settings via PUT /api/notifications/settings',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, endsWith('/api/notifications/settings'));
          expect(request.method, equals('PUT'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['price'], isFalse);

          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = NotificationSettingsApiService(mockClient);
        const updated = NotificationSettings(
          all: false,
          review: false,
          report: false,
          price: false,
          todayPick: false,
          quietHours: false,
          quietStart: '22:00',
          quietEnd: '08:00',
        );

        final result = await service.saveSettings(updated);
        expect(result.price, isFalse);
        expect(result.all, isFalse);
      },
    );

    test(
      'PriceAlertApiService loads the user\'s real favorite stores',
      () async {
        final service = PriceAlertApiService(
          MockClient((request) async {
            expect(request.method, 'GET');
            if (request.url.path == '/api/notifications/settings') {
              return http.Response(
                jsonEncode({
                  'notifyOnRise': true,
                  'notifyOnDrop': false,
                  'notifyOnNewMenu': true,
                }),
                200,
              );
            }
            expect(request.url.path, '/api/notifications/price-alerts');
            return http.Response(
              jsonEncode([
                {
                  'storeId': 'store_abc123',
                  'storeName': 'test-store',
                  'menuName': 'kimchi',
                  'price': '7000',
                  'enabled': false,
                  'notifyOnRise': true,
                  'notifyOnDrop': false,
                  'notifyOnNewMenu': true,
                },
              ]),
              200,
            );
          }),
        );

        final settings = await service.fetchSettings();
        final stores = settings.stores;

        expect(stores, hasLength(1));
        expect(stores.single.storeId, 'store_abc123');
        expect(stores.single.storeName, 'test-store');
        expect(stores.single.menuName, 'kimchi 7000원');
        expect(stores.single.enabled, isFalse);
        expect(settings.notifyOnDrop, isFalse);
        expect(settings.notifyOnNewMenu, isTrue);
      },
    );

    test('empty favorites still load the account price conditions', () async {
      final requestedPaths = <String>[];
      final service = PriceAlertApiService(
        MockClient((request) async {
          requestedPaths.add(request.url.path);
          return http.Response(
            request.url.path.endsWith('/price-alerts')
                ? '[]'
                : jsonEncode({
                    'notifyOnRise': false,
                    'notifyOnDrop': false,
                    'notifyOnNewMenu': true,
                  }),
            200,
          );
        }),
      );

      final settings = await service.fetchSettings();

      expect(settings.stores, isEmpty);
      expect(settings.notifyOnRise, isFalse);
      expect(settings.notifyOnDrop, isFalse);
      expect(settings.notifyOnNewMenu, isTrue);
      expect(requestedPaths, [
        '/api/notifications/price-alerts',
        '/api/notifications/settings',
      ]);
    });

    test('malformed successful settings response is rejected', () async {
      final service = NotificationSettingsApiService(
        MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(service.fetchSettings(), throwsFormatException);
    });

    test('price settings use one acknowledged batch save', () async {
      var requests = 0;
      final service = PriceAlertApiService(
        MockClient((request) async {
          requests++;
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/notifications/price-alerts/batch');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['stores'], isEmpty);
          return http.Response('{"success":true}', 200);
        }),
      );
      const settings = PriceAlertSettings(
        all: false,
        stores: [],
        notifyOnDrop: true,
        notifyOnRise: false,
        notifyOnNewMenu: true,
      );

      expect(await service.saveSettings(settings), same(settings));
      expect(requests, 1);
    });

    test('price settings reject an unacknowledged batch save', () async {
      final service = PriceAlertApiService(
        MockClient((_) async => http.Response('{"success":false}', 200)),
      );

      await expectLater(
        service.saveSettings(
          const PriceAlertSettings(
            all: false,
            stores: [],
            notifyOnDrop: true,
            notifyOnRise: false,
            notifyOnNewMenu: true,
          ),
        ),
        throwsFormatException,
      );
    });

    test('PriceAlertApiService saves a store subscription', () async {
      late http.Request capturedRequest;
      final service = PriceAlertApiService(
        MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'storeId': 'store_abc123',
              'storeName': 'test-store',
              'menuName': 'kimchi',
              'enabled': true,
            }),
            200,
          );
        }),
      );

      final saved = await service.saveSubscription(
        storeId: 'store_abc123',
        enabled: true,
        notifyOnRise: false,
        notifyOnDrop: true,
        notifyOnNewMenu: false,
      );

      expect(capturedRequest.method, 'PUT');
      expect(capturedRequest.url.path, '/api/notifications/price-alerts');
      expect(jsonDecode(capturedRequest.body), {
        'storeId': 'store_abc123',
        'enabled': true,
        'notifyOnRise': false,
        'notifyOnDrop': true,
        'notifyOnNewMenu': false,
      });
      expect(saved.enabled, isTrue);
    });
  });
}

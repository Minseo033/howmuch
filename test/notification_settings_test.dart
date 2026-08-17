import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('NotificationSettings Serialization & Persistence Tests', () {
    test('NotificationSettings.toJson and fromJson handle all fields including price', () {
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
    });

    test('NotificationSettingsApiService fetches settings from GET /api/notifications/settings', () async {
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
    });

    test('NotificationSettingsApiService saves settings via PUT /api/notifications/settings', () async {
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
    });
  });
}

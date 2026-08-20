import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends coordinates and maps a valid today pick response', () async {
    late http.Request captured;
    final service = TodaysPickService(
      MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'weather': '맑음', 'picks': <Object>[]})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await service.getTodaysPick(lat: 37.5, lng: 127.0);

    expect(captured.url.path, '/api/recommendation/todays-pick');
    expect(captured.url.queryParameters, {'lat': '37.5', 'lng': '127.0'});
    expect(result['weather'], '맑음');
    expect(result['error'], isNull);
  });

  test('does not treat a non-object JSON response as success', () async {
    final service = TodaysPickService(
      MockClient((_) async => http.Response('[]', 200)),
    );

    final result = await service.getRoute();

    expect(result['error'], isTrue);
    expect(result['message'], isNot(contains('FormatException')));
  });

  test('does not expose transport exception details', () async {
    final service = TodaysPickService(
      MockClient((_) async => throw Exception('secret-internal-url')),
    );

    final result = await service.getTodaysPick();

    expect(result['error'], isTrue);
    expect(result['message'], isNot(contains('secret-internal-url')));
  });
}

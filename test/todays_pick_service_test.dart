import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';
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

  test('local fallback ranks stores by distance', () {
    final data = buildLocalTodaysPickData(
      stores: [
        _store('먼 매장', 37.58, 127.02),
        _store('가까운 매장', 37.5666, 126.9781),
      ],
      lat: 37.5665,
      lng: 126.978,
    );

    final picks = data['picks'] as List;
    expect(data['fallback'], isTrue);
    expect((picks.first as Map)['storeName'], '가까운 매장');
  });

  test(
    'local fallback never substitutes a default city for missing location',
    () {
      final data = buildLocalTodaysPickData(
        stores: [_store('테스트 식당', 37.5666, 126.9781)],
      );

      expect(data['weather'], '위치 확인 필요');
      expect(data['picks'], isEmpty);
    },
  );

  test('AI error response becomes a readable nearby-store fallback', () {
    const error = '죄송합니다. AI 응답을 가져오는 중 오류가 발생했습니다.';
    expect(isAiUnavailableResponse(error), isTrue);

    final message = buildLocalAiFallback(
      stores: [_store('테스트 식당', 37.5666, 126.9781)],
      lat: 37.5665,
      lng: 126.978,
    );
    expect(message, contains('가까운 매장'));
    expect(message, contains('테스트 식당'));
    expect(message, contains('비빔밥'));
  });
}

Store _store(String name, double lat, double lng) => Store(
  id: name,
  storeName: name,
  address: '서울',
  phoneNumber: '',
  industry: '한식',
  menu1: '비빔밥',
  price1: '7000',
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: lat,
  longitude: lng,
  source: 'GOV',
);

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_failure.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

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
    expect(captured.url.queryParameters, {
      'lat': '37.5',
      'lng': '127.0',
      'radiusMeters': '3000',
    });
    expect(result['weather'], '맑음');
    expect(result['error'], isNull);
  });

  test('waits longer than the server weather budget before giving up', () {
    expect(TodaysPickService().requestTimeout, const Duration(seconds: 20));
  });

  test(
    'sends the session token when logged in and no Content-Type on GET',
    () async {
      final captured = <http.Request>[];
      final service = TodaysPickService(
        MockClient((request) async {
          captured.add(request);
          return http.Response(jsonEncode({'picks': <Object>[]}), 200);
        }),
      );

      await service.getRoute(lat: 37.5, lng: 127.0);
      await ApiClient.setSessionToken('session-token');
      await service.getRoute(lat: 37.5, lng: 127.0);
      await service.getTodaysPick(lat: 37.5, lng: 127.0);

      expect(captured[0].headers.containsKey('Authorization'), isFalse);
      expect(captured[1].headers['Authorization'], 'Bearer session-token');
      expect(captured[2].headers['Authorization'], 'Bearer session-token');
      for (final request in captured) {
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('content-type')),
        );
      }
    },
  );

  test('classifies a timeout separately from other failures', () async {
    final never = Completer<http.Response>();
    final service = TodaysPickService(
      MockClient((_) => never.future),
      const Duration(milliseconds: 10),
    );

    final result = await service.getTodaysPick(lat: 37.5, lng: 127.0);

    expect(result['error'], isTrue);
    expect(recommendationFailureOf(result), RecommendationFailure.timeout);
  });

  test('classifies status codes and transport errors', () async {
    Future<RecommendationFailure> failureFor(
      Future<http.Response> Function() respond,
    ) async {
      final service = TodaysPickService(MockClient((_) => respond()));
      return recommendationFailureOf(
        await service.getRoute(lat: 37.5, lng: 127.0),
      );
    }

    expect(
      await failureFor(() async => http.Response('{}', 429)),
      RecommendationFailure.rateLimited,
    );
    expect(
      await failureFor(() async => http.Response('{}', 503)),
      RecommendationFailure.server,
    );
    expect(
      await failureFor(() async => http.Response('{}', 400)),
      RecommendationFailure.invalidRequest,
    );
    expect(
      await failureFor(() async => throw http.ClientException('offline')),
      RecommendationFailure.network,
    );
    expect(
      await failureFor(() async => http.Response('not json', 200)),
      RecommendationFailure.invalidResponse,
    );
    expect(
      recommendationFailureOf(await TodaysPickService().getTodaysPick()),
      RecommendationFailure.location,
    );
  });

  test('each failure has its own title on both recommendation screens', () {
    for (final route in [false, true]) {
      final titles = RecommendationFailure.values
          .map((failure) => recommendationFailureCopy(failure, route: route))
          .map((copy) => copy.title)
          .toSet();
      // invalidResponse and unknown intentionally share the generic title.
      expect(titles.length, RecommendationFailure.values.length - 1);
    }
    expect(
      recommendationFailureCopy(
        RecommendationFailure.invalidRequest,
        route: false,
        serverMessage: '올바른 위치 좌표를 입력해주세요.',
      ).message,
      '올바른 위치 좌표를 입력해주세요.',
    );
    expect(
      recommendationFailureCopy(RecommendationFailure.unknown, route: true)
          .title,
      '추천 루트를 불러오지 못했어요',
    );
    expect(
      recommendationFailureCopy(RecommendationFailure.unknown, route: false)
          .title,
      '오늘의 픽을 불러오지 못했어요',
    );
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

  test('filters malformed pick items while preserving valid stores', () async {
    final service = TodaysPickService(
      MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'weather': '맑음',
              'picks': [
                null,
                'invalid',
                <String, Object?>{},
                {'storeName': '정상 매장', 'price1': '7000'},
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    final result = await service.getTodaysPick(lat: 37.5, lng: 127.0);
    final picks = result['picks'] as List;

    expect(result['error'], isNull);
    expect(picks, hasLength(1));
    expect((picks.single as Map)['storeName'], '정상 매장');
  });

  test(
    'rejects a recommendation payload containing only malformed picks',
    () async {
      final service = TodaysPickService(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'picks': [null, 'invalid', <String, Object?>{}],
            }),
            200,
          ),
        ),
      );

      final result = await service.getRoute(lat: 37.5, lng: 127.0);

      expect(result['error'], isTrue);
      expect(result['message'], '추천 루트 응답 형식이 올바르지 않습니다.');
    },
  );

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

  test('local fallback limits picks to three and mixes in dessert', () {
    final data = buildLocalTodaysPickData(
      stores: [
        _store('식당 1', 37.5666, 126.9781),
        _store('식당 2', 37.5667, 126.9782),
        _store('식당 3', 37.5668, 126.9783),
        _store('동네 카페', 37.5669, 126.9784, industry: '기타요식업', menu: '아메리카노'),
      ],
      lat: 37.5665,
      lng: 126.978,
    );

    final picks = (data['picks'] as List).cast<Map<String, dynamic>>();
    expect(picks, hasLength(3));
    expect(picks.map((pick) => pick['storeName']), contains('동네 카페'));
    expect(picks.where((pick) => pick['industry'] == '한식'), hasLength(2));
  });

  test('local fallback does not fill empty slots with distant stores', () {
    final data = buildLocalTodaysPickData(
      stores: [
        _store('근처 식당', 37.5666, 126.9781),
        _store('먼 식당', 37.61, 126.978),
      ],
      lat: 37.5665,
      lng: 126.978,
    );

    final picks = (data['picks'] as List).cast<Map<String, dynamic>>();
    expect(picks.map((pick) => pick['storeName']), ['근처 식당']);
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

    final message = buildLocalAiFallbackResult(
      stores: [_store('테스트 식당', 37.5666, 126.9781)],
      lat: 37.5665,
      lng: 126.978,
    )?.text;
    expect(message, contains('3km 안에서'));
    expect(message, contains('테스트 식당'));
    expect(message, contains('비빔밥'));
  });

  test('missing AI configuration also activates the local fallback', () {
    const error = 'AI 기능이 현재 설정되지 않았습니다. 관리자에게 문의해주세요.';
    expect(isAiUnavailableResponse(error), isTrue);
  });

  test('client and rate-limit errors are not disguised as AI outages', () {
    expect(isAiUnavailableResponse('서버 응답 에러: 400'), isFalse);
    expect(isAiUnavailableResponse('서버 응답 에러: 429'), isFalse);
    expect(
      isAiUnavailableResponse('로그인이 필요한 기능이에요. 로그인한 뒤 다시 시도해 주세요.'),
      isFalse,
    );
  });

  test('AI request context excludes stores outside the nearby radius', () {
    final ids = buildNearbyStoreIds(
      stores: [
        _store('먼 매장', 37.58, 127.02),
        _store('가까운 매장', 37.5666, 126.9781),
      ],
      lat: 37.5665,
      lng: 126.978,
    );

    expect(ids, ['가까운 매장']);
  });
}

Store _store(
  String name,
  double lat,
  double lng, {
  String industry = '한식',
  String menu = '비빔밥',
}) => Store(
  id: name,
  storeName: name,
  address: '서울',
  phoneNumber: '',
  industry: industry,
  menu1: menu,
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

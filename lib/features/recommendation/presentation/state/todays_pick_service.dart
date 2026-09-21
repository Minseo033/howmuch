import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/store_model.dart';

final todaysPickHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final todaysPickServiceProvider = Provider(
  (ref) => TodaysPickService(ref.watch(todaysPickHttpClientProvider)),
);

const todaysPickMaxDistanceMeters = 3000.0;

class TodaysPickService {
  TodaysPickService([
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 8),
  ]) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration requestTimeout;

  /// 오늘의 픽 조회 (세션 인증 불필요 — 공개 GET)
  Future<Map<String, dynamic>> getTodaysPick({double? lat, double? lng}) async {
    if (lat == null || lng == null) {
      return const {'error': true, 'message': '현재 위치가 필요합니다.'};
    }
    final query = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
    };
    final url = ApiClient.uri('/api/recommendation/todays-pick', query);

    try {
      final response = await _client
          .get(url, headers: ApiClient.jsonHeaders())
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          return normalizeRecommendationResponse(
            Map<String, dynamic>.from(decoded),
            invalidMessage: '추천 응답 형식이 올바르지 않습니다.',
          );
        }
        return const {'error': true, 'message': '추천 응답 형식이 올바르지 않습니다.'};
      }
      return {'error': true, 'statusCode': response.statusCode};
    } catch (_) {
      return const {'error': true, 'message': '추천 정보를 불러오지 못했습니다.'};
    }
  }

  /// AI 루트 추천 조회 (세션 인증 불필요 — 공개 GET)
  Future<Map<String, dynamic>> getRoute({double? lat, double? lng}) async {
    if (lat == null || lng == null) {
      return const {'error': true, 'message': '현재 위치가 필요합니다.'};
    }
    final query = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
    };
    final url = ApiClient.uri('/api/recommendation/route', query);

    try {
      final response = await _client
          .get(url, headers: ApiClient.jsonHeaders())
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          return normalizeRecommendationResponse(
            Map<String, dynamic>.from(decoded),
            invalidMessage: '추천 루트 응답 형식이 올바르지 않습니다.',
          );
        }
        return const {'error': true, 'message': '추천 루트 응답 형식이 올바르지 않습니다.'};
      }
      return {'error': true, 'statusCode': response.statusCode};
    } catch (_) {
      return const {'error': true, 'message': '추천 루트를 불러오지 못했습니다.'};
    }
  }
}

Map<String, dynamic> normalizeRecommendationResponse(
  Map<String, dynamic> response, {
  required String invalidMessage,
}) {
  final rawPicks = response['picks'];
  if (rawPicks is! List) {
    return {'error': true, 'message': invalidMessage};
  }

  final picks = rawPicks
      .whereType<Map>()
      .map((pick) => Map<String, dynamic>.from(pick))
      .where((pick) => pick['storeName']?.toString().trim().isNotEmpty == true)
      .toList(growable: false);

  if (rawPicks.isNotEmpty && picks.isEmpty) {
    return {'error': true, 'message': invalidMessage};
  }
  return {...response, 'picks': picks};
}

Map<String, dynamic> buildLocalTodaysPickData({
  required List<Store> stores,
  double? lat,
  double? lng,
  int limit = 3,
  double maxDistanceMeters = todaysPickMaxDistanceMeters,
  bool balanceDessert = true,
}) {
  if (lat == null || lng == null) {
    return const {
      'weather': '위치 확인 필요',
      'fallback': true,
      'picks': <Map<String, dynamic>>[],
    };
  }
  final originLat = lat;
  final originLng = lng;
  final ranked =
      stores
          .where((store) => store.hasValidCoordinates && _isFoodStore(store))
          .map(
            (store) => (
              store: store,
              distance: _distanceMeters(
                originLat,
                originLng,
                store.latitude,
                store.longitude,
              ),
            ),
          )
          .where((entry) => entry.distance <= maxDistanceMeters)
          .toList()
        ..sort((a, b) => a.distance.compareTo(b.distance));

  final selected = <({Store store, double distance})>[];
  if (balanceDessert) {
    final meals = ranked.where((entry) => !_isDessertStore(entry.store));
    final desserts = ranked.where((entry) => _isDessertStore(entry.store));
    selected.addAll(meals.take(limit < 2 ? limit : 2));
    selected.addAll(desserts.take(limit - selected.length));
  }
  for (final entry in ranked) {
    if (selected.length >= limit) break;
    if (!selected.contains(entry)) selected.add(entry);
  }

  return {
    'weather': '위치 기반',
    'fallback': true,
    'picks': selected.map((entry) {
      return {
        ...entry.store.toJson(),
        'distanceMeters': entry.distance.round(),
        'matchedMenu': entry.store.menu1,
        'theme': '가까운 거리',
        'reason': 'AI 연결 대신 가까운 매장을 안내해요.',
      };
    }).toList(),
  };
}

bool _isFoodStore(Store store) {
  const foodIndustries = {
    '한식',
    '중식',
    '일식',
    '양식',
    '기타요식업',
    '카페',
    '제과점',
    '제과업',
    '휴게음식점',
  };
  return foodIndustries.contains(store.industry.trim());
}

bool _isDessertStore(Store store) {
  const keywords = [
    '카페',
    '커피',
    '아메리카노',
    '라떼',
    '에이드',
    '주스',
    '스무디',
    '녹차',
    '홍차',
    '밀크티',
    '디저트',
    '베이커리',
    '제과',
    '빵',
    '케이크',
    '쿠키',
    '도넛',
    '꽈배기',
    '크로플',
    '와플',
    '아이스크림',
    '빙수',
    '마카롱',
    '샌드위치',
  ];
  final text = [
    store.industry,
    store.storeName,
    store.menu1,
    store.menu2,
    store.menu3,
    store.menu4,
  ].join(' ').toLowerCase();
  return keywords.any(text.contains);
}

double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLng = radians(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

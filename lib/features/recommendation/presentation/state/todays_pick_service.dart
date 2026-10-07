import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_failure.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/core/utils/price_formatter.dart';

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
    this.requestTimeout = recommendationRequestTimeout,
  ]) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration requestTimeout;

  /// 오늘의 픽 조회. 공개 GET이지만 로그인 상태면 세션 토큰을 함께 보내
  /// 서버가 IP 대신 계정 기준으로 요청량을 셀 수 있게 합니다.
  Future<Map<String, dynamic>> getTodaysPick({
    double? lat,
    double? lng,
    int radiusMeters = defaultRecommendationRadiusMeters,
  }) => _getRecommendation(
    '/api/recommendation/todays-pick',
    lat: lat,
    lng: lng,
    radiusMeters: radiusMeters,
    invalidMessage: '추천 응답 형식이 올바르지 않습니다.',
  );

  /// 추천 루트 조회. 서버의 시간당 요청 제한이 같은 와이파이 사용자끼리
  /// 공유되지 않도록 로그인 상태면 세션 토큰을 보냅니다.
  Future<Map<String, dynamic>> getRoute({
    double? lat,
    double? lng,
    int radiusMeters = defaultRecommendationRadiusMeters,
  }) => _getRecommendation(
    '/api/recommendation/route',
    lat: lat,
    lng: lng,
    radiusMeters: radiusMeters,
    invalidMessage: '추천 루트 응답 형식이 올바르지 않습니다.',
  );

  Future<Map<String, dynamic>> _getRecommendation(
    String path, {
    required double? lat,
    required double? lng,
    required int radiusMeters,
    required String invalidMessage,
  }) async {
    if (!validRecommendationRadius(radiusMeters)) {
      return recommendationError(
        RecommendationFailure.invalidRequest,
        message: '추천 거리는 1~15km, 1km 단위로 선택해주세요.',
      );
    }
    if (lat == null || lng == null) {
      return recommendationError(RecommendationFailure.location);
    }
    final url = ApiClient.uri(path, {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radiusMeters': radiusMeters.toString(),
    });

    final http.Response response;
    try {
      // GET has no body: omitting Content-Type avoids a CORS preflight.
      response = await _client
          .get(url, headers: ApiClient.authHeaders(auth: true))
          .timeout(requestTimeout);
    } on TimeoutException {
      return recommendationError(RecommendationFailure.timeout);
    } catch (_) {
      return recommendationError(RecommendationFailure.network);
    }

    final statusCode = response.statusCode;
    if (statusCode == 200) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          return normalizeRecommendationResponse(
            Map<String, dynamic>.from(decoded),
            invalidMessage: invalidMessage,
          );
        }
      } catch (_) {
        // Treated as an unreadable response below.
      }
      return recommendationError(
        RecommendationFailure.invalidResponse,
        message: invalidMessage,
      );
    }
    final failure = switch (statusCode) {
      429 => RecommendationFailure.rateLimited,
      400 => RecommendationFailure.invalidRequest,
      >= 500 => RecommendationFailure.server,
      _ => RecommendationFailure.unknown,
    };
    return recommendationError(
      failure,
      message: _serverMessage(response),
      statusCode: statusCode,
    );
  }
}

String? _serverMessage(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final message = decoded is Map ? decoded['message']?.toString().trim() : null;
    return message == null || message.isEmpty ? null : message;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> normalizeRecommendationResponse(
  Map<String, dynamic> response, {
  required String invalidMessage,
}) {
  final rawPicks = response['picks'];
  if (rawPicks is! List) {
    return recommendationError(
      RecommendationFailure.invalidResponse,
      message: invalidMessage,
    );
  }

  final picks = rawPicks
      .whereType<Map>()
      .map((pick) => Map<String, dynamic>.from(pick))
      .where((pick) => pick['storeName']?.toString().trim().isNotEmpty == true)
      .toList(growable: false);

  if (rawPicks.isNotEmpty && picks.isEmpty) {
    return recommendationError(
      RecommendationFailure.invalidResponse,
      message: invalidMessage,
    );
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
  if (lat == null ||
      lng == null ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180 ||
      (lat == 0 && lng == 0) ||
      !maxDistanceMeters.isFinite ||
      maxDistanceMeters < 1000 ||
      maxDistanceMeters > 15000 ||
      maxDistanceMeters % 1000 != 0 ||
      limit <= 0) {
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
          .where(
            (store) =>
                store.hasValidCoordinates &&
                !store.isClosed &&
                _isFoodStore(store) &&
                _localPickMenuSlot(store) != null,
          )
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
      final slot = _localPickMenuSlot(entry.store)!;
      return {
        ...entry.store.toJson(),
        'distanceMeters': entry.distance.round(),
        'matchedMenu': entry.store.menuAt(slot),
        'matchedPrice': entry.store.priceAt(slot),
        'matchedFree': entry.store.freeAt(slot),
        'menuIndex': slot,
        'theme': '가까운 거리',
        // Today's pick is rule-based on the server, not AI; say what failed.
        'reason': '추천 서버에 연결하지 못해 가까운 매장을 안내해요.',
      };
    }).toList(),
  };
}

int? _localPickMenuSlot(Store store) {
  for (var slot = 1; slot <= 4; slot++) {
    if (store.menuAt(slot).trim().isNotEmpty &&
        minimumMenuPrice(store.priceAt(slot), free: store.freeAt(slot)) !=
            null) {
      return slot;
    }
  }
  return null;
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
  final text = [
    store.industry,
    store.storeName,
    store.menu1,
    store.menu2,
    store.menu3,
    store.menu4,
  ].join(' ').toLowerCase();
  return _dessertKeywords.any(text.contains);
}

/// Whether a recommended stop is a cafe or dessert place, judged the same way
/// the server splits meals from desserts when it picks the stops.
bool isDessertRecommendation(Map<String, dynamic> pick) {
  final text = [
    for (final key in const [
      'industry',
      'storeName',
      'menu1',
      'menu2',
      'menu3',
      'menu4',
    ])
      pick[key]?.toString() ?? '',
  ].join(' ').toLowerCase();
  return _dessertKeywords.any(text.contains);
}

/// Mirrors DESSERT_KEYWORDS in the server's FirebaseService.
const _dessertKeywords = [
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

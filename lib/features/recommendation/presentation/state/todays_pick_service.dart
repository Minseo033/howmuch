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
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
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
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return const {'error': true, 'message': '추천 루트 응답 형식이 올바르지 않습니다.'};
      }
      return {'error': true, 'statusCode': response.statusCode};
    } catch (_) {
      return const {'error': true, 'message': '추천 루트를 불러오지 못했습니다.'};
    }
  }
}

Map<String, dynamic> buildLocalTodaysPickData({
  required List<Store> stores,
  double? lat,
  double? lng,
  int limit = 5,
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
          .where((store) => store.hasValidCoordinates)
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
          .toList()
        ..sort((a, b) => a.distance.compareTo(b.distance));

  return {
    'weather': '위치 기반',
    'fallback': true,
    'picks': ranked.take(limit).map((entry) {
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

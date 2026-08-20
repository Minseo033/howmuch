import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';

final todaysPickHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final todaysPickServiceProvider = Provider(
  (ref) => TodaysPickService(ref.watch(todaysPickHttpClientProvider)),
);

class TodaysPickService {
  TodaysPickService([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// 오늘의 픽 조회 (세션 인증 불필요 — 공개 GET)
  Future<Map<String, dynamic>> getTodaysPick({double? lat, double? lng}) async {
    final query = <String, String>{};
    if (lat != null) query['lat'] = lat.toString();
    if (lng != null) query['lng'] = lng.toString();
    final url = ApiClient.uri('/api/recommendation/todays-pick', query);

    try {
      final response = await _client
          .get(url, headers: ApiClient.jsonHeaders())
          .timeout(ApiClient.defaultTimeout);

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
    final query = <String, String>{};
    if (lat != null) query['lat'] = lat.toString();
    if (lng != null) query['lng'] = lng.toString();
    final url = ApiClient.uri('/api/recommendation/route', query);

    try {
      final response = await _client
          .get(url, headers: ApiClient.jsonHeaders())
          .timeout(ApiClient.defaultTimeout);

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

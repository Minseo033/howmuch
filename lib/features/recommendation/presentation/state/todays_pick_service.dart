import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';

final todaysPickServiceProvider = Provider((ref) => TodaysPickService());

class TodaysPickService {
  /// 오늘의 픽 조회 (세션 인증 불필요 — 공개 GET)
  Future<Map<String, dynamic>> getTodaysPick({double? lat, double? lng}) async {
    final query = <String, String>{};
    if (lat != null) query['lat'] = lat.toString();
    if (lng != null) query['lng'] = lng.toString();
    final url = ApiClient.uri('/api/recommendation/todays-pick', query);

    try {
      final response = await http
          .get(url, headers: ApiClient.jsonHeaders())
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
        }
      debugPrint('오늘의 픽 API 에러: ${response.statusCode}');
      return {'error': true, 'statusCode': response.statusCode};
    } catch (e) {
      debugPrint('오늘의 픽 통신 에러: $e');
      return {'error': true, 'message': e.toString()};
    }
  }

  /// AI 루트 추천 조회 (세션 인증 불필요 — 공개 GET)
  Future<Map<String, dynamic>> getRoute({double? lat, double? lng}) async {
    final query = <String, String>{};
    if (lat != null) query['lat'] = lat.toString();
    if (lng != null) query['lng'] = lng.toString();
    final url = ApiClient.uri('/api/recommendation/route', query);

    try {
      final response = await http
          .get(url, headers: ApiClient.jsonHeaders())
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      debugPrint('AI 루트 API 에러: ${response.statusCode}');
      return {'error': true, 'statusCode': response.statusCode};
    } catch (e) {
      debugPrint('AI 루트 통신 에러: $e');
      return {'error': true, 'message': e.toString()};
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';

final aiChatServiceProvider = Provider((ref) => AiChatService());

class AiChatService {
  /// Gemini AI 챗봇 응답 요청 (세션 인증 필요)
  Future<String> getGeminiResponse(
    String message, {
    List<Map<String, String>>? history,
    List<String>? nearbyStoreIds,
    double? latitude,
    double? longitude,
  }) async {
    final url = ApiClient.uri('/api/ai/chat');

    try {
      final payload = <String, dynamic>{
        'message': message,
        if (history != null && history.isNotEmpty) 'history': history,
        if (nearbyStoreIds != null && nearbyStoreIds.isNotEmpty)
          'nearbyStoreIds': nearbyStoreIds,
        if (latitude != null && longitude != null) ...{
          'latitude': latitude,
          'longitude': longitude,
        },
      };

      final response = await ApiClient.post(
        url,
        headers: ApiClient.jsonHeaders(auth: true),
        body: jsonEncode(payload),
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['response'] ?? '응답을 이해하지 못했습니다.';
      } else if (response.statusCode == 401) {
        return '로그인이 필요한 기능입니다. 다시 로그인해주세요.';
      } else {
        return '서버 응답 에러: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('AI 챗봇 통신 에러: $e');
      return 'AI 연결에 실패했습니다. 네트워크를 확인해주세요.';
    }
  }
}

List<String> buildNearbyStoreIds({
  required List<Store> stores,
  double? lat,
  double? lng,
  int limit = 10,
}) {
  final data = buildLocalTodaysPickData(
    stores: stores,
    lat: lat,
    lng: lng,
    limit: limit,
  );
  final picks = (data['picks'] as List).whereType<Map>().toList();
  return picks
      .map((pick) => pick['storeId']?.toString().trim() ?? '')
      .where((storeId) => storeId.isNotEmpty)
      .toSet()
      .take(limit)
      .toList();
}

bool isAiUnavailableResponse(String response) {
  final normalized = response.trim();
  return normalized.contains('AI 응답을 가져오는 중 오류') ||
      normalized.contains('AI 응답을 가져오지 못했습니다') ||
      normalized.contains('AI 기능이 현재 설정되지 않았습니다') ||
      normalized.startsWith('AI 연결에 실패했습니다') ||
      normalized.startsWith('서버 응답 에러:');
}

String? buildLocalAiFallback({
  required List<Store> stores,
  double? lat,
  double? lng,
}) {
  final data = buildLocalTodaysPickData(
    stores: stores,
    lat: lat,
    lng: lng,
    limit: 3,
  );
  final picks = (data['picks'] as List).whereType<Map>().toList();
  if (picks.isEmpty) return null;

  final lines = <String>['AI 연결이 원활하지 않아 가까운 매장을 먼저 추천할게요.'];
  for (var i = 0; i < picks.length; i++) {
    final pick = picks[i];
    final name = pick['storeName']?.toString() ?? '매장';
    final menu = pick['menu1']?.toString() ?? '';
    final price = pick['price1']?.toString() ?? '';
    final distance = formatRecommendationDistance(
      (pick['distanceMeters'] as num?)?.toDouble(),
    );
    final detail = [
      menu,
      price,
      distance,
    ].where((value) => value.isNotEmpty).join(' · ');
    lines.add('${i + 1}. $name${detail.isEmpty ? '' : ' — $detail'}');
  }
  return lines.join('\n');
}

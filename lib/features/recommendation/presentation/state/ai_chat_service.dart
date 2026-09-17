import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';

final aiChatServiceProvider = Provider((ref) => AiChatService());

class AiChatService {
  // 서버의 전체 AI 호출 예산(최대 12초) + 인증/매장 조회/전송 여유.
  static const requestTimeout = Duration(seconds: 25);

  /// Gemini AI 챗봇 응답 요청 (세션 인증 필요)
  Future<AiChatReply> getGeminiResponse(
    String message, {
    List<Map<String, String>>? history,
    List<String>? nearbyStoreIds,
    double? latitude,
    double? longitude,
  }) async {
    final url = ApiClient.uri('/api/ai/chat');

    try {
      final safeHistory = buildAiRequestHistory(history);
      final payload = <String, dynamic>{
        'message': message,
        if (safeHistory.isNotEmpty) 'history': safeHistory,
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
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AiChatReply(
          text: data['response']?.toString() ?? '응답을 이해하지 못했습니다.',
          isFallback: data['fallback'] == true,
          recommendedStoreIds:
              (data['recommendedStoreIds'] as List?)
                  ?.map((id) => id.toString().trim())
                  .where((id) => id.isNotEmpty)
                  .toList(growable: false) ??
              const [],
        );
      } else if (response.statusCode == 401) {
        return const AiChatReply(text: '로그인이 필요한 기능입니다. 다시 로그인해주세요.');
      } else if (response.statusCode == 429) {
        return const AiChatReply(
          text: 'AI 채팅 사용 횟수를 모두 사용했어요. 잠시 후 다시 시도해주세요.',
        );
      } else if (response.statusCode >= 500) {
        return AiChatReply(
          text: 'AI 연결에 실패했습니다. 서버 응답: ${response.statusCode}',
        );
      } else {
        return AiChatReply(
          text: '요청을 처리하지 못했습니다. 입력 내용을 확인해주세요. (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('AI 챗봇 통신 에러: $e');
      return const AiChatReply(text: 'AI 연결에 실패했습니다. 네트워크를 확인해주세요.');
    }
  }
}

/// 화면의 원본 답변은 유지하고 서버 검증 규격에 맞는 최근 기록만 전송합니다.
List<Map<String, String>> buildAiRequestHistory(
  List<Map<String, String>>? history,
) {
  final valid = (history ?? const <Map<String, String>>[])
      .where(
        (turn) =>
            (turn['role'] == 'user' || turn['role'] == 'model') &&
            (turn['text']?.trim().isNotEmpty ?? false),
      )
      .toList();
  return valid
      .skip(math.max(0, valid.length - 6))
      .map((turn) {
        final text = turn['text']!.trim();
        var end = math.min(text.length, 1000);
        if (end < text.length &&
            text.codeUnitAt(end - 1) >= 0xD800 &&
            text.codeUnitAt(end - 1) <= 0xDBFF) {
          end--;
        }
        return {'role': turn['role']!, 'text': text.substring(0, end)};
      })
      .toList(growable: false);
}

class AiChatReply {
  const AiChatReply({
    required this.text,
    this.isFallback = false,
    this.recommendedStoreIds = const [],
  });

  final String text;
  final bool isFallback;
  final List<String> recommendedStoreIds;
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
      normalized.startsWith('AI 연결에 실패했습니다');
}

class LocalAiRecommendation {
  const LocalAiRecommendation({
    required this.text,
    required this.stores,
    this.matchedIntent,
    this.matchedArea,
  });

  final String text;
  final List<Store> stores;
  final String? matchedIntent;
  final String? matchedArea;
}

class AiMapRecommendationResult {
  const AiMapRecommendationResult({
    required this.storeIds,
    this.stores = const [],
    this.queryText = '',
  });

  final List<String> storeIds;
  final List<Store> stores;
  final String queryText;
}

class AiChatMessage {
  const AiChatMessage({
    required this.text,
    required this.isBot,
    this.recommendedStoreIds = const [],
    this.recommendedStores = const [],
  });

  final String text;
  final bool isBot;
  final List<String> recommendedStoreIds;
  final List<Store> recommendedStores;
}

int parseRequestedRecommendationCount(
  String query, {
  int defaultCount = 3,
  int minCount = 1,
  int maxCount = 4,
}) {
  final text = query.trim();
  if (text.isEmpty) return defaultCount.clamp(minCount, maxCount);

  // Korean count words with counters
  final koreanCounts = [
    (RegExp(r'(?:한\s*곳|한\s*군데|한\s*개|하나)'), 1),
    (RegExp(r'(?:두\s*곳|두\s*군데|두\s*개|둘)'), 2),
    (RegExp(r'(?:세\s*곳|세\s*군데|세\s*개|셋)'), 3),
    (RegExp(r'(?:네\s*곳|네\s*군데|네\s*개|넷)'), 4),
    (RegExp(r'(?:다섯\s*곳|다섯\s*군데|다섯\s*개|다섯)'), 5),
  ];

  for (final entry in koreanCounts) {
    if (entry.$1.hasMatch(text)) {
      return entry.$2.clamp(minCount, maxCount);
    }
  }

  // Arabic count words: e.g. "2곳", "3 개", "1군데"
  final counterMatch = RegExp(r'(\d+)\s*(?:곳|군데|개|점|개소|가지)').firstMatch(text);
  if (counterMatch != null) {
    final count = int.tryParse(counterMatch.group(1) ?? '');
    if (count != null && count >= 0) {
      return count.clamp(minCount, maxCount);
    }
  }

  // General small digits in recommendation context (e.g. "2개만", "최대 4곳", or "3 추천")
  final generalDigitMatch = RegExp(r'(\d+)\s*(?:추천|알려|보여)').firstMatch(text);
  if (generalDigitMatch != null) {
    final count = int.tryParse(generalDigitMatch.group(1) ?? '');
    if (count != null && count > 0 && count <= 20) {
      return count.clamp(minCount, maxCount);
    }
  }

  return defaultCount.clamp(minCount, maxCount);
}

int? parseRequestedBudgetWon(String query) {
  final normalized = query.replaceAll(',', '').replaceAll(' ', '');
  final manWon = RegExp(r'(\d+(?:\.\d+)?)만원').firstMatch(normalized);
  if (manWon != null) {
    final units = double.tryParse(manWon.group(1) ?? '');
    if (units != null && units > 0) return (units * 10000).round();
  }
  if (normalized.contains('만원')) return 10000;

  final thousandWon = RegExp(r'(\d+(?:\.\d+)?)천원').firstMatch(normalized);
  if (thousandWon != null) {
    final units = double.tryParse(thousandWon.group(1) ?? '');
    if (units != null && units > 0) return (units * 1000).round();
  }

  final won = RegExp(r'(\d{3,6})원').firstMatch(normalized);
  if (won != null) {
    final amount = int.tryParse(won.group(1) ?? '');
    if (amount != null && amount > 0) return amount;
  }
  return null;
}

List<({String menu, Object? price})> _storeMenuEntries(Store store) {
  return [
    (menu: store.menu1.trim(), price: store.price1),
    (menu: store.menu2.trim(), price: store.price2),
    (menu: store.menu3.trim(), price: store.price3),
    (menu: store.menu4.trim(), price: store.price4),
  ].where((entry) => entry.menu.isNotEmpty).toList(growable: false);
}

({String menu, Object? price})? preferredStoreMenu(
  Store store, {
  int? budgetWon,
}) {
  final entries = _storeMenuEntries(store);
  if (entries.isEmpty) return null;
  if (budgetWon == null) return entries.first;

  final eligible =
      entries
          .where((entry) {
            final price = parseRecommendationPrice(entry.price);
            return price != null && price <= budgetWon;
          })
          .toList(growable: false)
        ..sort(
          (a, b) => parseRecommendationPrice(
            a.price,
          )!.compareTo(parseRecommendationPrice(b.price)!),
        );
  return eligible.isEmpty ? null : eligible.first;
}

bool storeMatchesRequestedBudget(Store store, int? budgetWon) {
  return budgetWon == null ||
      preferredStoreMenu(store, budgetWon: budgetWon) != null;
}

String buildStructuredAiRecommendationText({
  required List<Store> stores,
  required String intro,
  int? budgetWon,
  double? lat,
  double? lng,
}) {
  final lines = <String>[intro];
  for (var index = 0; index < stores.length; index++) {
    final store = stores[index];
    final menu = preferredStoreMenu(store, budgetWon: budgetWon);
    final distance = lat != null && lng != null
        ? formatRecommendationDistance(
            _haversineDistance(lat, lng, store.latitude, store.longitude),
          )
        : '';
    final detail = [
      menu?.menu ?? store.industry,
      formatRecommendationPrice(menu?.price),
      distance,
    ].where((value) => value.isNotEmpty).join(' · ');
    lines.add('${index + 1}. ${store.storeName} — $detail');
  }
  return lines.join('\n');
}

List<Store> extractRecommendedStoresFromText({
  required String text,
  required List<Store> candidateStores,
}) {
  if (text.isEmpty || candidateStores.isEmpty) return const [];
  final matched = <Store>[];
  for (final store in candidateStores) {
    if (store.storeName.trim().length >= 2 &&
        text.contains(store.storeName.trim())) {
      matched.add(store);
    }
  }
  return matched;
}

double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
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

LocalAiRecommendation? buildLocalAiFallbackResult({
  required List<Store> stores,
  String? query,
  double? lat,
  double? lng,
}) {
  final validStores = stores.where((s) => s.hasValidCoordinates).toList();
  if (validStores.isEmpty) return null;

  final q = (query ?? '').trim().toLowerCase();
  final targetCount = parseRequestedRecommendationCount(q);
  final budgetWon = parseRequestedBudgetWon(q);

  // 1. Identify intent keywords
  final intentMap = <String, List<String>>{
    '한식': [
      '한식',
      '밥',
      '백반',
      '찌개',
      '국밥',
      '국수',
      '김치',
      '된장',
      '불고기',
      '비빔밥',
      '삼겹살',
      '고기',
      '칼국수',
      '수제비',
    ],
    '중식': ['중식', '중국집', '짜장', '자장', '짬뽕', '탕수육', '볶음밥', '마라'],
    '일식': ['일식', '돈까스', '돈가스', '초밥', '스시', '라멘', '우동', '소바', '덮밥', '회'],
    '분식': ['분식', '김밥', '떡볶이', '라면', '튀김', '순대', '만두'],
    '양식': ['양식', '파스타', '스파게티', '피자', '버거', '스테이크', '샐러드', '샌드위치'],
    '카페': ['카페', '커피', '디저트', '음료', '베이커리', '빵', '티'],
    '미용': ['미용', '헤어', '이발', '미용실', '파마', '염색', '커트'],
    '세탁': ['세탁', '빨래', '드라이'],
  };

  String? matchedIntentCategory;
  String? matchedIntentKeyword;
  for (final entry in intentMap.entries) {
    for (final kw in entry.value) {
      if (q.contains(kw)) {
        matchedIntentCategory = entry.key;
        matchedIntentKeyword = kw;
        break;
      }
    }
    if (matchedIntentCategory != null) break;
  }

  // 2. Identify area keywords (e.g. "마포", "신촌", "서대문", "강남", "종로", etc.)
  String? matchedAreaKeyword;
  final tokens = q
      .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ')
      .split(RegExp(r'\s+'))
      .where(
        (t) =>
            t.length >= 2 &&
            !t.contains(RegExp(r'추천|알려|어디|주변|근처|맛집|식당|카페|가성비|얼마')),
      )
      .toList();
  for (final token in tokens) {
    final hasAreaMatch = validStores.any(
      (s) =>
          s.address.toLowerCase().contains(token) ||
          s.storeName.toLowerCase().contains(token),
    );
    if (hasAreaMatch) {
      matchedAreaKeyword = token;
      break;
    }
  }

  // 3. Score & filter candidate stores
  final budgetEligibleStores = validStores
      .where((store) => storeMatchesRequestedBudget(store, budgetWon))
      .toList(growable: false);
  // Do not turn a backend outage into a dead-end message just because the
  // requested ceiling has no matching entry. Show real nearby candidates and
  // say clearly that they are alternatives outside the requested budget.
  final hasBudgetMatches = budgetEligibleStores.isNotEmpty;
  final recommendationStores = hasBudgetMatches
      ? budgetEligibleStores
      : validStores;

  List<({Store store, double distance, int score})> ranked =
      recommendationStores.map((s) {
        final dist = (lat != null && lng != null)
            ? _haversineDistance(lat, lng, s.latitude, s.longitude)
            : 0.0;

        int score = 0;
        // Area match bonus
        if (matchedAreaKeyword != null) {
          if (s.address.toLowerCase().contains(matchedAreaKeyword) ||
              s.storeName.toLowerCase().contains(matchedAreaKeyword)) {
            score += 100;
          }
        }

        // Intent match bonus
        if (matchedIntentKeyword != null) {
          final menus = '${s.menu1} ${s.menu2} ${s.menu3} ${s.menu4}'
              .toLowerCase();
          final storeName = s.storeName.toLowerCase();
          final industry = s.industry.toLowerCase();

          if (menus.contains(matchedIntentKeyword) ||
              storeName.contains(matchedIntentKeyword)) {
            score += 50;
          } else if (industry.contains(matchedIntentCategory!.toLowerCase())) {
            score += 30;
          }
        }

        return (store: s, distance: dist, score: score);
      }).toList();

  // If specific area or intent was requested, prioritize matching items
  final hasSpecificFilter =
      matchedAreaKeyword != null || matchedIntentKeyword != null;
  if (hasSpecificFilter) {
    final filtered = ranked.where((item) => item.score > 0).toList();
    if (filtered.isNotEmpty) {
      ranked = filtered;
    }
  }

  // Sort primarily by relevance score, then distance
  ranked.sort((a, b) {
    if (a.score != b.score) return b.score.compareTo(a.score);
    return a.distance.compareTo(b.distance);
  });

  final selected = ranked.take(targetCount).toList();
  if (selected.isEmpty) return null;

  final selectedStores = selected.map((item) => item.store).toList();

  // 4. Build friendly, properly formatted message
  String intro;
  if (!hasBudgetMatches && budgetWon != null) {
    intro =
        'AI 연결이 원활하지 않고 ${formatRecommendationPrice(budgetWon)} 이하 매장이 없어, 확인된 실제 매장 대안을 먼저 추천할게요.';
  } else if (matchedAreaKeyword != null && matchedIntentKeyword != null) {
    intro =
        "AI 연결이 원활하지 않아 '$matchedAreaKeyword' 근처 '$matchedIntentKeyword' 가까운 매장 $targetCount곳을 추천할게요.";
  } else if (matchedIntentKeyword != null) {
    intro =
        "AI 연결이 원활하지 않아 '$matchedIntentKeyword' 관련 가까운 매장 $targetCount곳을 추천할게요.";
  } else if (matchedAreaKeyword != null) {
    intro =
        "AI 연결이 원활하지 않아 '$matchedAreaKeyword' 근처 가까운 매장 $targetCount곳을 추천할게요.";
  } else {
    intro = "AI 연결이 원활하지 않아 가까운 매장 $targetCount곳을 먼저 추천할게요.";
  }

  return LocalAiRecommendation(
    text: buildStructuredAiRecommendationText(
      stores: selectedStores,
      intro: intro,
      budgetWon: hasBudgetMatches ? budgetWon : null,
      lat: lat,
      lng: lng,
    ),
    stores: selectedStores,
    matchedIntent: matchedIntentKeyword,
    matchedArea: matchedAreaKeyword,
  );
}

String? buildLocalAiFallback({
  required List<Store> stores,
  String? query,
  double? lat,
  double? lng,
}) {
  return buildLocalAiFallbackResult(
    stores: stores,
    query: query,
    lat: lat,
    lng: lng,
  )?.text;
}

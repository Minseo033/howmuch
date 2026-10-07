import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/core/utils/price_formatter.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/store/store_model.dart';

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
    int radiusMeters = defaultRecommendationRadiusMeters,
  }) async {
    if (!validRecommendationRadius(radiusMeters)) {
      return const AiChatReply(text: '추천 거리를 1~15km에서 1km 단위로 선택해주세요.');
    }
    if (!_validOrigin(latitude, longitude)) {
      return const AiChatReply(
        text: '주변 추천에는 현재 위치가 필요해요. 브라우저의 위치 권한을 허용한 뒤 다시 질문해주세요.',
      );
    }
    final url = ApiClient.uri('/api/ai/chat');

    try {
      final safeHistory = buildAiRequestHistory(history);
      final payload = <String, dynamic>{
        'message': message,
        'radiusMeters': radiusMeters,
        if (safeHistory.isNotEmpty) 'history': safeHistory,
        if (nearbyStoreIds != null && nearbyStoreIds.isNotEmpty)
          'nearbyStoreIds': nearbyStoreIds,
        'latitude': latitude!,
        'longitude': longitude!,
      };

      final response = await ApiClient.post(
        url,
        headers: ApiClient.jsonHeaders(auth: true),
        body: jsonEncode(payload),
        timeout: requestTimeout,
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AiChatReply(
          text: data['response']?.toString() ?? '응답을 이해하지 못했습니다.',
          isFallback: data['fallback'] == true,
          recommendations:
              (data['recommendations'] as List?)
                  ?.whereType<Map>()
                  .map(
                    (value) => VerifiedAiRecommendation.fromJson(
                      Map<String, dynamic>.from(value),
                    ),
                  )
                  .whereType<VerifiedAiRecommendation>()
                  .toList(growable: false) ??
              const [],
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
    this.recommendations = const [],
  });

  final String text;
  final bool isFallback;
  final List<String> recommendedStoreIds;
  final List<VerifiedAiRecommendation> recommendations;
}

class VerifiedAiRecommendation {
  const VerifiedAiRecommendation({
    required this.storeId,
    required this.storeName,
    required this.menu,
    required this.rawPrice,
    required this.free,
    required this.distanceMeters,
    required this.source,
    required this.data,
  });
  final String storeId;
  final String storeName;
  final String menu;
  final Object? rawPrice;
  final bool free;
  final double distanceMeters;
  final String source;
  final Map<String, dynamic> data;

  static VerifiedAiRecommendation? fromJson(Map<String, dynamic> data) {
    final id = data['storeId']?.toString().trim() ?? '';
    final name = data['storeName']?.toString().trim() ?? '';
    final menu = data['matchedMenu']?.toString().trim() ?? '';
    final distance = double.tryParse(data['distanceMeters']?.toString() ?? '');
    final price = data['rawPrice'];
    final free = data['free'] == true;
    if (id.isEmpty ||
        name.isEmpty ||
        menu.isEmpty ||
        distance == null ||
        !distance.isFinite ||
        distance < 0 ||
        minimumMenuPrice(price, free: free) == null) {
      return null;
    }
    return VerifiedAiRecommendation(
      storeId: id,
      storeName: name,
      menu: menu,
      rawPrice: price,
      free: free,
      distanceMeters: distance,
      source: data['source']?.toString() ?? '',
      data: data,
    );
  }

  RecommendationMenuSelection get selection => RecommendationMenuSelection(
    storeId: storeId,
    storeName: storeName,
    menu: menu,
    price: rawPrice,
    free: free,
  );

  Store? resolveStore(List<Store> catalog) {
    final fromResponse = Store.fromJson({
      ...data,
      'storeId': storeId,
      'source': source.isEmpty ? 'UNKNOWN' : source,
    });
    if (fromResponse.hasValidCoordinates) {
      return _hasVerifiedMenu(fromResponse) && !fromResponse.isClosed
          ? fromResponse
          : null;
    }
    final matches = catalog.where((store) => store.id == storeId);
    final base = matches.isEmpty
        ? Store.fromJson({
            ...data,
            'id': storeId,
            'menu1': menu,
            'price1': rawPrice?.toString() ?? '',
            'free1': free,
          })
        : matches.first;
    if (!base.hasValidCoordinates || base.isClosed || !_hasVerifiedMenu(base)) {
      return null;
    }
    return base;
  }

  bool _hasVerifiedMenu(Store store) {
    final requestedSlot = int.tryParse('${data['menuIndex']}');
    if (data.containsKey('menuIndex') &&
        (requestedSlot == null || requestedSlot < 1 || requestedSlot > 4)) {
      return false;
    }
    final slots = requestedSlot == null ? [1, 2, 3, 4] : [requestedSlot];
    final quoted = parsePriceValue(rawPrice);
    if (quoted == null) return false;
    for (final slot in slots) {
      final actual = parsePriceValue(store.priceAt(slot));
      if (store.menuAt(slot).trim() == menu &&
          store.freeAt(slot) == free &&
          actual != null &&
          actual.isRange == quoted.isRange &&
          listEquals(actual.amounts, quoted.amounts)) {
        return true;
      }
    }
    return false;
  }
}

/// Only server-provided identities and matching menu slots can become cards.
/// Rechecking coordinates protects the map from a stale or malformed distance.
///
/// The server already applied the menu intent and budget rules when it chose
/// these stores. Re-filtering them here with different rules made the answer
/// text and the "지도에서 찾기" cards disagree, so only identity, menu slot,
/// coordinates and radius are checked.
List<({Store store, RecommendationMenuSelection selection})>
resolveVerifiedAiRecommendations({
  required List<VerifiedAiRecommendation> recommendations,
  required List<Store> catalog,
  required double? latitude,
  required double? longitude,
  required int radiusMeters,
}) {
  if (!_validOrigin(latitude, longitude) ||
      !validRecommendationRadius(radiusMeters)) {
    return const [];
  }
  final seen = <String>{};
  final results = <({Store store, RecommendationMenuSelection selection})>[];
  for (final item in recommendations) {
    if (item.distanceMeters > radiusMeters || seen.contains(item.storeId)) {
      continue;
    }
    final store = item.resolveStore(catalog);
    if (store == null ||
        _haversineDistance(
              latitude!,
              longitude!,
              store.latitude,
              store.longitude,
            ) >
            radiusMeters) {
      continue;
    }
    seen.add(item.storeId);
    results.add((store: store, selection: item.selection));
  }
  return results;
}

bool _validOrigin(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    !(latitude == 0 && longitude == 0);

List<String> buildNearbyStoreIds({
  required List<Store> stores,
  double? lat,
  double? lng,
  int limit = 10,
  int radiusMeters = defaultRecommendationRadiusMeters,
}) {
  if (!_validOrigin(lat, lng) ||
      !validRecommendationRadius(radiusMeters) ||
      limit <= 0) {
    return const [];
  }
  final ranked =
      stores
          .where(
            (store) =>
                store.hasValidCoordinates &&
                !store.isClosed &&
                store.id.isNotEmpty,
          )
          .map(
            (store) => (
              store: store,
              distance: _haversineDistance(
                lat!,
                lng!,
                store.latitude,
                store.longitude,
              ),
            ),
          )
          .where((item) => item.distance <= radiusMeters)
          .toList()
        ..sort((a, b) => a.distance.compareTo(b.distance));
  return ranked.map((item) => item.store.id).toSet().take(limit).toList();
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
    this.menuSelections = const [],
  });

  final String text;
  final List<Store> stores;
  final String? matchedIntent;
  final String? matchedArea;
  final List<RecommendationMenuSelection> menuSelections;
}

enum MapResultOrigin { aiRecommendation, approvedReport }

class AiMapRecommendationResult {
  const AiMapRecommendationResult({
    required this.storeIds,
    this.stores = const [],
    this.menuSelections = const [],
    this.queryText = '',
    this.origin = MapResultOrigin.aiRecommendation,
  });

  final List<String> storeIds;
  final List<Store> stores;
  final List<RecommendationMenuSelection> menuSelections;
  final String queryText;
  final MapResultOrigin origin;

  RecommendationMenuSelection? selectionFor(Store store) {
    for (final selection in menuSelections) {
      if (selection.matches(id: store.id, name: store.storeName)) {
        return selection;
      }
    }
    return null;
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.text,
    required this.isBot,
    this.recommendedStoreIds = const [],
    this.recommendedStores = const [],
    this.menuSelections = const [],
  });

  final String text;
  final bool isBot;
  final List<String> recommendedStoreIds;
  final List<Store> recommendedStores;
  final List<RecommendationMenuSelection> menuSelections;
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

/// Mirrors GeminiService.requestedBudgetWon so the local fallback reads a
/// budget exactly like the server ("1만 5천원" is 15,000, "오만원" is 50,000).
/// Keep both in sync; test/ai_shared_rules_test.dart holds the shared table.
int? parseRequestedBudgetWon(String query) {
  final text = query.replaceAll(',', '').replaceAll(' ', '');
  if (text.contains('무료')) return 0;
  final mixed = RegExp(r'(\d+)만(\d+)천원').firstMatch(text);
  if (mixed != null) {
    final man = int.tryParse(mixed.group(1)!);
    final cheon = int.tryParse(mixed.group(2)!);
    if (man == null || cheon == null) return null;
    return _boundedBudget(man * 10000 + cheon * 1000);
  }
  final manWon = RegExp(r'(\d+(?:\.\d+)?)만원').firstMatch(text);
  if (manWon != null) {
    final units = double.tryParse(manWon.group(1)!);
    return units == null ? null : _boundedBudget((units * 10000).round());
  }
  const koreanDigits = {
    '일': 1,
    '이': 2,
    '삼': 3,
    '사': 4,
    '오': 5,
    '육': 6,
    '칠': 7,
    '팔': 8,
    '구': 9,
    '십': 10,
  };
  for (final entry in koreanDigits.entries) {
    if (text.contains('${entry.key}만원')) return entry.value * 10000;
  }
  if (text.contains('만원')) return 10000;
  final cheonWon = RegExp(r'(\d+)천원').firstMatch(text);
  if (cheonWon != null) {
    final units = int.tryParse(cheonWon.group(1)!);
    return units == null ? null : _boundedBudget(units * 1000);
  }
  if (text.contains('천원')) return 1000;
  final won = RegExp(r'(\d{1,7})원').firstMatch(text);
  if (won != null) return int.tryParse(won.group(1)!);
  return null;
}

/// Same upper bound as the server price parser (WonPrice.MAX_AMOUNT).
int? _boundedBudget(int amount) =>
    amount < 0 || amount > 10000000 ? null : amount;

List<({String menu, Object? price, bool free})> _storeMenuEntries(Store store) {
  return [
    (menu: store.menu1.trim(), price: store.price1, free: store.free1),
    (menu: store.menu2.trim(), price: store.price2, free: store.free2),
    (menu: store.menu3.trim(), price: store.price3, free: store.free3),
    (menu: store.menu4.trim(), price: store.price4, free: store.free4),
  ].where((entry) => entry.menu.isNotEmpty).toList(growable: false);
}

({String menu, Object? price, bool free})? preferredStoreMenu(
  Store store, {
  int? budgetWon,
  String query = '',
}) {
  final entries = _storeMenuEntries(store);
  if (entries.isEmpty) return null;
  final eligible =
      entries
          .where((entry) {
            final price = parsePriceValue(entry.price);
            return minimumMenuPrice(entry.price, free: entry.free) != null &&
                (budgetWon == null || price!.maximum <= budgetWon) &&
                menuMatchesRecommendationQuery(
                  entry.menu,
                  query,
                  industry: store.industry,
                );
          })
          .toList(growable: false)
        ..sort(
          (a, b) => parseRecommendationPrice(
            a.price,
            free: a.free,
          )!.compareTo(parseRecommendationPrice(b.price, free: b.free)!),
        );
  return eligible.isEmpty ? null : eligible.first;
}

/// 음식점이 아닌 업종(공공데이터 기타비요식업·미용업·이용업·세탁업·숙박업·목욕업,
/// 제보 업종 생활서비스·숙박·교통·주차). 음식을 찾는 요청에서는 메뉴와 상관없이 뺀다.
const _nonFoodIndustries = [
  '비요식',
  '미용',
  '이용업',
  '이발',
  '헤어',
  '네일',
  '세탁',
  '수선',
  '목욕',
  '사우나',
  '숙박',
  '생활서비스',
  '교통',
  '주차',
];

/// 분식으로 보는 메뉴. 순대국·쌀국수는 순대·국수가 들어 있어도 분식이 아니다.
const _bunsikMenus = [
  '분식',
  '김밥',
  '떡볶이',
  '라볶이',
  '순대',
  '튀김',
  '어묵',
  '오뎅',
  '라면',
  '쫄면',
  '우동',
  '국수',
  '수제비',
  '만두',
  '돈가스',
  '돈까스',
  '주먹밥',
  '유부초밥',
  '핫도그',
  '떡꼬치',
  '토스트',
  '컵밥',
  '오므라이스',
];
const _notBunsikMenus = ['순대국', '순댓국', '쌀국수'];

/// 분식 메뉴가 있어도 분식집으로 보지 않는 다른 음식 업종(중식당의 우동·만두 등).
const _notBunsikVenues = [
  '중식',
  '중화',
  '일식',
  '양식',
  '카페',
  '커피',
  '베이커리',
  '제과',
  '치킨',
  '패스트푸드',
  '고기',
];

/// 음식 종류를 말한 요청: (질문 단어, 그 종류로 보는 업종, 분식 메뉴로도 판단하는지).
/// '중화'만으로는 찾지 않는다(중화역·중화동 같은 지명).
const _cuisineRequests = <(List<String>, List<String>, bool)>[
  (['분식'], ['분식'], true),
  (['한식'], ['한식'], false),
  (['중식', '중국집', '중화요리'], ['중식', '중화'], false),
  (['일식'], ['일식'], false),
  (['양식'], ['양식'], false),
];

bool _matchesCuisine(
  (List<String>, List<String>, bool) cuisine,
  String item,
  String venue,
) {
  final (_, venueWords, bunsikMenus) = cuisine;
  if (venueWords.any(venue.contains)) return true;
  return bunsikMenus &&
      _bunsikMenus.any(item.contains) &&
      !_notBunsikMenus.any(item.contains) &&
      !_notBunsikVenues.any(venue.contains);
}

/// Mirrors GeminiService.menuMatchesIntent, which decides the server's AI and
/// fallback recommendations. The local fallback (server unreachable) must pick
/// stores by the same rules; test/ai_shared_rules_test.dart holds the shared
/// table. "혼밥 분식 추천" keeps 분식 menus such as 칼국수 and 김밥 but not
/// 삼겹살 or a photo studio (QA 2026-10-07 #1). Soup requests also exclude
/// 콩국수 and 탕수육 (FE-STORE-12).
bool menuMatchesRecommendationQuery(
  String menu,
  String query, {
  String industry = '',
}) {
  final q = query.toLowerCase().replaceAll(' ', '');
  final item = menu.toLowerCase().replaceAll(' ', '');
  final venue = industry.toLowerCase();
  final soup = const [
    '국물',
    '뜨끈',
    '따뜻한',
    '국밥',
    '찌개',
    '삼계탕',
    '설렁탕',
    '갈비탕',
    '짬뽕',
  ].any(q.contains);
  if (soup &&
      !const [
        '국수',
        '수제비',
        '국밥',
        '탕',
        '찌개',
        '짬뽕',
        '우동',
        '라면',
        '전골',
        '국',
      ].any(item.contains)) {
    return false;
  }
  if (soup &&
      const ['비빔', '냉', '볶음', '김밥', '콩국수', '탕수육'].any(item.contains)) {
    return false;
  }
  // Specific dishes are matched against a menu, never a common store name.
  final dishes = const [
    '칼국수',
    '수제비',
    '국밥',
    '김밥',
    '백반',
    '짜장',
    '짬뽕',
    '돈까스',
    '돈가스',
    '삼겹살',
    '냉면',
    '비빔국수',
    '아메리카노',
    '라떼',
    '우동',
    '라면',
    '탕수육',
    '삼계탕',
    '설렁탕',
    '갈비탕',
  ].where(q.contains).toList();
  if (dishes.isNotEmpty && !dishes.any(item.contains)) return false;
  final cafe = const ['카페', '커피', '디저트', '빵', '베이커리'].any(q.contains);
  if (cafe &&
      !item.endsWith('차') &&
      !const [
        '커피',
        '아메리카노',
        '라떼',
        '카푸치노',
        '음료',
        '빵',
        '케이크',
        '디저트',
      ].any(item.contains)) {
    return false;
  }
  // '분식'·'중식'처럼 음식 종류를 말하면 그 종류의 메뉴·업종만 맞는다.
  final cuisines = _cuisineRequests
      .where((cuisine) => cuisine.$1.any(q.contains))
      .toList(growable: false);
  if (cuisines.isNotEmpty &&
      !cuisines.any((cuisine) => _matchesCuisine(cuisine, item, venue))) {
    return false;
  }
  final meal =
      soup ||
      cuisines.isNotEmpty ||
      const [
        '점심',
        '저녁',
        '아침',
        '식사',
        '밥',
        '음식',
        '맛집',
        '국수',
        '분식',
      ].any(q.contains);
  // A nearby cheap drink is not a meal. A cafe's actual food menu still is.
  final drink =
      item.endsWith('차') ||
      const [
        '커피',
        '아메리카노',
        '라떼',
        '카푸치노',
        '에스프레소',
        '음료',
        '에이드',
        '주스',
        '스무디',
      ].any(item.contains);
  if (meal && !cafe && drink) return false;
  final cafeVenue = const ['카페', '커피', '베이커리'].any(venue.contains);
  final cafeFood = const [
    '샌드위치',
    '샐러드',
    '토스트',
    '파니니',
    '브런치',
    '파스타',
    '스파게티',
    '피자',
    '버거',
    '카레',
    '밥',
    '국수',
    '라면',
    '우동',
    '찌개',
    '빵',
    '베이글',
  ].any(item.contains);
  // Unknown cafe menu names can be branded drinks (e.g. 메가리카노).
  if (meal && !cafe && cafeVenue && !cafeFood) return false;
  // 음식을 찾는 요청(식사·카페·메뉴·코스)에서는 음식점이 아닌 업종을 뺀다.
  final foodRequest = meal || cafe || dishes.isNotEmpty || q.contains('코스');
  if (foodRequest && _nonFoodIndustries.any(venue.contains)) return false;
  final serviceText = '$venue $item';
  if (meal &&
      const [
        '미용',
        '헤어',
        '이발',
        '세탁',
        '수선',
        '네일',
        '목욕',
        '숙박',
      ].any(serviceText.contains)) {
    return false;
  }
  for (final service in const ['미용', '세탁', '목욕', '이발', '수선']) {
    if (q.contains(service) && !serviceText.contains(service)) return false;
  }
  return true;
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
  int radiusMeters = defaultRecommendationRadiusMeters,
}) {
  if (!_validOrigin(lat, lng) || !validRecommendationRadius(radiusMeters)) {
    return null;
  }
  final q = (query ?? '').trim().toLowerCase();
  final budgetWon = parseRequestedBudgetWon(q);
  final count = parseRequestedRecommendationCount(q);
  final ranked =
      <
        ({Store store, double distance, String menu, Object? price, bool free})
      >[];
  for (final store in stores) {
    if (!store.hasValidCoordinates || store.isClosed || store.id.isEmpty) {
      continue;
    }
    final distance = _haversineDistance(
      lat!,
      lng!,
      store.latitude,
      store.longitude,
    );
    if (distance > radiusMeters) continue;
    final menu = preferredStoreMenu(store, budgetWon: budgetWon, query: q);
    if (menu == null) continue;
    ranked.add((
      store: store,
      distance: distance,
      menu: menu.menu,
      price: menu.price,
      free: menu.free,
    ));
  }
  ranked.sort((a, b) => a.distance.compareTo(b.distance));
  final selected = ranked.take(count).toList(growable: false);
  if (selected.isEmpty) {
    return LocalAiRecommendation(
      text:
          'AI 연결이 원활하지 않아요. ${radiusMeters ~/ 1000}km 안에서 요청한 메뉴·예산에 맞는 매장을 찾지 못했어요. 추천 거리나 조건을 바꿔 다시 질문해주세요.',
      stores: const [],
    );
  }
  final lines = <String>[
    'AI 연결 대신 확인된 매장 정보를 안내해요. ${radiusMeters ~/ 1000}km 안에서 조건에 맞는 매장 ${selected.length}곳이에요.',
    if (selected.length < count) '조건에 맞는 매장이 부족해 다른 매장으로 채우지 않았어요.',
    for (var index = 0; index < selected.length; index++)
      '${index + 1}. ${selected[index].store.storeName} — ${selected[index].menu} · ${formatRecommendationPrice(selected[index].price, free: selected[index].free)} · ${formatRecommendationDistance(selected[index].distance)}',
  ];
  return LocalAiRecommendation(
    text: lines.join('\n'),
    stores: selected.map((entry) => entry.store).toList(growable: false),
    menuSelections: selected
        .map(
          (entry) => RecommendationMenuSelection(
            storeId: entry.store.id,
            storeName: entry.store.storeName,
            menu: entry.menu,
            price: entry.price,
            free: entry.free,
          ),
        )
        .toList(growable: false),
  );
}

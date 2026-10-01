import 'package:howmuch/core/utils/price_formatter.dart';

/// The menu and price the recommendation actually refers to.
///
/// A store continues to retain every menu slot. This value travels with a
/// recommendation so its selected menu never overwrites the store itself.
class RecommendationMenuSelection {
  const RecommendationMenuSelection({
    required this.storeId,
    required this.storeName,
    required this.menu,
    required this.price,
    this.free = false,
  });

  final String storeId;
  final String storeName;
  final String menu;
  final Object? price;
  final bool free;

  factory RecommendationMenuSelection.fromPick(Map<String, dynamic> pick) {
    final matchedMenu = pick['matchedMenu']?.toString().trim() ?? '';
    return RecommendationMenuSelection(
      storeId:
          pick['storeId']?.toString().trim() ??
          pick['id']?.toString().trim() ??
          '',
      storeName: pick['storeName']?.toString().trim() ?? '',
      menu: matchedMenu.isNotEmpty
          ? matchedMenu
          : pick['menu1']?.toString().trim() ?? '',
      price: recommendationMenuPrice(pick),
      free: recommendationMenuFree(pick),
    );
  }

  bool matches({required String id, required String name}) {
    if (storeId.isNotEmpty || id.isNotEmpty) {
      return storeId.isNotEmpty && id.isNotEmpty && storeId == id;
    }
    return storeName.isNotEmpty && name.isNotEmpty && storeName == name;
  }
}

Object? recommendationMenuPrice(Map<String, dynamic> pick) {
  if (pick.containsKey('rawPrice')) return pick['rawPrice'];
  if (pick.containsKey('matchedPrice')) return pick['matchedPrice'];
  final matchedMenu = pick['matchedMenu']?.toString().trim() ?? '';
  if (matchedMenu.isEmpty) return pick['price1'];
  for (var index = 1; index <= 4; index++) {
    if (pick['menu$index']?.toString().trim() == matchedMenu) {
      return pick['price$index'];
    }
  }
  return null;
}

bool recommendationMenuFree(Map<String, dynamic> pick) {
  if (pick.containsKey('matchedFree')) return pick['matchedFree'] == true;
  if (pick.containsKey('free')) return pick['free'] == true;
  final slot = int.tryParse('${pick['menuIndex']}');
  if (slot != null && slot >= 1 && slot <= 4) {
    return pick['free$slot'] == true;
  }
  final menu = pick['matchedMenu']?.toString().trim() ?? '';
  for (var index = 1; index <= 4; index++) {
    if (pick['menu$index']?.toString().trim() == menu) {
      return pick['free$index'] == true;
    }
  }
  return menu.isEmpty && pick['free1'] == true;
}

int? parseRecommendationPrice(Object? value, {bool free = false}) {
  return minimumMenuPrice(value, free: free);
}

String formatRecommendationPrice(
  Object? value, {
  String unavailable = '가격 정보 없음',
  bool free = false,
}) {
  if (parsePriceValue(value) == null) return unavailable;
  return formatMenuPrice(value, free: free);
}

/// A displayed route quote is not an actual payment. Unknown prices make the
/// total unknown; multiple values are an estimate range, never a fixed total.
String formatRecommendationTotal(Iterable<Map<String, dynamic>> picks) {
  var minimum = 0;
  var maximum = 0;
  var uncertain = false;
  var count = 0;
  for (final pick in picks) {
    count++;
    final parsed = parsePriceValue(recommendationMenuPrice(pick));
    if (parsed == null ||
        minimumMenuPrice(
              recommendationMenuPrice(pick),
              free: recommendationMenuFree(pick),
            ) ==
            null) {
      return '가격 확인 필요';
    }
    minimum += parsed.minimum;
    maximum += parsed.maximum;
    uncertain |= !parsed.isExact;
  }
  if (count == 0) return '가격 정보 없음';
  if (uncertain) return '${formatWon(minimum)} ~ ${formatWon(maximum)} (예상)';
  return '${formatWon(minimum)} (표시 가격 합계)';
}

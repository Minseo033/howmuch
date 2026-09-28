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
  });

  final String storeId;
  final String storeName;
  final String menu;
  final Object? price;

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
    );
  }

  bool matches({required String id, required String name}) {
    if (storeId.isNotEmpty && id.isNotEmpty) return storeId == id;
    return storeName.isNotEmpty && name.isNotEmpty && storeName == name;
  }
}

Object? recommendationMenuPrice(Map<String, dynamic> pick) {
  final matchedMenu = pick['matchedMenu']?.toString().trim() ?? '';
  if (matchedMenu.isEmpty) return pick['price1'];
  for (var index = 1; index <= 4; index++) {
    if (pick['menu$index']?.toString().trim() == matchedMenu) {
      return pick['price$index'];
    }
  }
  return null;
}

int? parseRecommendationPrice(Object? value) {
  if (value is num) {
    final rounded = value.round();
    return rounded >= 0 ? rounded : null;
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.startsWith('-')) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

String formatRecommendationPrice(
  Object? value, {
  String unavailable = '가격 정보 없음',
}) {
  final price = parseRecommendationPrice(value);
  if (price == null) return unavailable;
  return formatWon(price, fallback: unavailable);
}

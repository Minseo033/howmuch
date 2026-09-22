import 'package:howmuch/features/store/store_model.dart';

class SearchFilterPolicy {
  const SearchFilterPolicy._();

  static bool matchesQuery(Store store, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return [
      store.storeName,
      store.menu1,
      store.menu2,
      store.menu3,
      store.menu4,
      store.industry,
      store.address,
    ].any((value) => value.toLowerCase().contains(normalized));
  }

  static ({String name, String price, int index})? findMatchingMenu(
    Store store,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final menus = [
      (name: store.menu1.trim(), price: store.price1.trim(), index: 1),
      (name: store.menu2.trim(), price: store.price2.trim(), index: 2),
      (name: store.menu3.trim(), price: store.price3.trim(), index: 3),
      (name: store.menu4.trim(), price: store.price4.trim(), index: 4),
    ];

    for (final item in menus) {
      if (item.name.isNotEmpty &&
          item.name.toLowerCase().contains(normalized)) {
        return item;
      }
    }
    return null;
  }

  static int? parsePrice(String rawPrice) {
    final match = RegExp(r'\d{1,3}(?:,\d{3})+|\d{3,}').firstMatch(rawPrice);
    final price = int.tryParse(match?.group(0)?.replaceAll(',', '') ?? '');
    return price != null && price > 0 ? price : null;
  }

  static bool matchesMaxPrice(Store store, int maxPrice) {
    return [
      store.price1,
      store.price2,
      store.price3,
      store.price4,
    ].map(parsePrice).whereType<int>().any((price) => price <= maxPrice);
  }

  static int compareByPrice(Store a, Store b) {
    final aPrice = lowestMenuPrice(a);
    final bPrice = lowestMenuPrice(b);
    if (aPrice == null && bPrice == null) {
      return a.storeName.compareTo(b.storeName);
    }
    if (aPrice == null) return 1;
    if (bPrice == null) return -1;
    final priceComparison = aPrice.compareTo(bPrice);
    return priceComparison != 0
        ? priceComparison
        : a.storeName.compareTo(b.storeName);
  }

  static int? lowestMenuPrice(Store store) {
    final prices = [
      store.price1,
      store.price2,
      store.price3,
      store.price4,
    ].map(parsePrice).whereType<int>();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
  }
}

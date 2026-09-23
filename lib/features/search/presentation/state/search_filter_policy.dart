import 'package:howmuch/features/store/store_model.dart';

typedef SearchMenuMatch = ({String name, String price, int index});

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

  static SearchMenuMatch? findMatchingMenu(Store store, String query) {
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

  /// Returns the one menu whose price represents a store in a search result.
  ///
  /// A menu-text query uses the first matching menu (the same menu shown on
  /// the result card). For store-name, address, industry, or empty queries,
  /// use the lowest priced menu to retain the previous "any menu can qualify"
  /// price-filter behavior. If no numeric price is available, fall back to the
  /// first named menu so the card can still explain the result.
  static SearchMenuMatch? displayMenuFor(Store store, String query) {
    final matched = findMatchingMenu(store, query);
    if (matched != null) return matched;

    final menus = _menusFor(store);
    SearchMenuMatch? lowestPriced;
    var lowestPrice = 0;
    for (final menu in menus) {
      final price = parsePrice(menu.price);
      if (price == null) continue;
      if (lowestPriced == null || price < lowestPrice) {
        lowestPriced = menu;
        lowestPrice = price;
      }
    }
    if (lowestPriced != null) return lowestPriced;

    for (final menu in menus) {
      if (menu.name.isNotEmpty) return menu;
    }
    return null;
  }

  static int? parsePrice(String rawPrice) {
    final match = RegExp(r'\d{1,3}(?:,\d{3})+|\d{3,}').firstMatch(rawPrice);
    final price = int.tryParse(match?.group(0)?.replaceAll(',', '') ?? '');
    return price != null && price > 0 ? price : null;
  }

  static bool matchesMaxPrice(Store store, int maxPrice, {String query = ''}) {
    final price = parsePrice(displayMenuFor(store, query)?.price ?? '');
    return price != null && price <= maxPrice;
  }

  static int compareByPrice(Store a, Store b, {String query = ''}) {
    final aPrice = priceForResult(a, query);
    final bPrice = priceForResult(b, query);
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

  static int? priceForResult(Store store, String query) {
    return parsePrice(displayMenuFor(store, query)?.price ?? '');
  }

  static int? lowestMenuPrice(Store store) {
    return priceForResult(store, '');
  }

  static List<SearchMenuMatch> _menusFor(Store store) {
    return [
      (name: store.menu1.trim(), price: store.price1.trim(), index: 1),
      (name: store.menu2.trim(), price: store.price2.trim(), index: 2),
      (name: store.menu3.trim(), price: store.price3.trim(), index: 3),
      (name: store.menu4.trim(), price: store.price4.trim(), index: 4),
    ];
  }
}

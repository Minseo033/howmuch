import 'package:howmuch/features/store/store_model.dart';

class SearchFilterPolicy {
  const SearchFilterPolicy._();

  static int? parsePrice(String rawPrice) {
    final digits = rawPrice.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final price = int.tryParse(digits);
    return price != null && price > 0 ? price : null;
  }

  static bool matchesMaxPrice(Store store, int maxPrice) {
    final price = parsePrice(store.price1);
    return price != null && price <= maxPrice;
  }

  static int compareByPrice(Store a, Store b) {
    final aPrice = parsePrice(a.price1);
    final bPrice = parsePrice(b.price1);
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
}

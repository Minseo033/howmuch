import 'dart:convert';

import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;

const homeMapStoreCacheKey = 'howmuch.home_map_cache.v1';
const maxCachedHomeMapStores = 250;

/// QA/시연용으로 입력된 의미 없는 이름은 공개 지도에 노출하지 않는다.
bool isHomeMapStoreVisible(Store store) {
  if (!store.hasValidCoordinates) return false;
  return store.storeName.trim() != '아무거나';
}

List<Store> decodeHomeMapStoreCache(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Store.fromJson(Map<String, dynamic>.from(item)))
        .where(isHomeMapStoreVisible)
        .take(maxCachedHomeMapStores)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

String encodeHomeMapStoreCache(List<Store> stores) {
  return jsonEncode(
    stores
        .where(isHomeMapStoreVisible)
        .take(maxCachedHomeMapStores)
        .map((store) => store.toJson())
        .toList(growable: false),
  );
}

class HomeMapStoreLoadResult {
  const HomeMapStoreLoadResult({
    required this.stores,
    required this.hasFreshResponse,
  });

  final List<Store> stores;
  final bool hasFreshResponse;
}

/// An unavailable bounds endpoint must not erase stores already loaded from
/// the server. The caller applies viewport and user filters to either source.
Future<List<Store>> loadHomeMapStores({
  required Map<String, double> bounds,
  required List<Store> cachedStores,
  Future<http.Response> Function(Uri)? request,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final result = await loadHomeMapStoresWithStatus(
    bounds: bounds,
    cachedStores: cachedStores,
    request: request,
    timeout: timeout,
  );
  return result.stores;
}

Future<HomeMapStoreLoadResult> loadHomeMapStoresWithStatus({
  required Map<String, double> bounds,
  required List<Store> cachedStores,
  Future<http.Response> Function(Uri)? request,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final uri = ApiClient.uri('/api/stores/bounds', {
      for (final entry in bounds.entries) entry.key: '${entry.value}',
    });
    final response =
        await (request ??
                (uri) =>
                    ApiClient.get(uri, headers: ApiClient.jsonHeaders()))(uri)
            .timeout(timeout);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('Invalid store list');
      final stores = decoded
          .map((item) => Store.fromJson(Map<String, dynamic>.from(item as Map)))
          .where(isHomeMapStoreVisible)
          .toList();
      return HomeMapStoreLoadResult(stores: stores, hasFreshResponse: true);
    }
  } catch (_) {
    // Transport errors, timeouts, and malformed responses share the same
    // fallback as HTTP errors. A valid empty list above remains empty.
  }
  return HomeMapStoreLoadResult(
    stores: cachedStores.where(isHomeMapStoreVisible).toList(),
    hasFreshResponse: false,
  );
}

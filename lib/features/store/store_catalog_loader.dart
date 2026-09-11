import 'dart:convert';

import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// v2 retains source-checked openingHours; v1 clients discarded that field.
const storeCatalogCacheKey = 'howmuch.store_cache.v2';
const storeCatalogCachedAtKey = 'howmuch.store_cache.cached_at.v2';
const storeCatalogCacheMaxAge = Duration(hours: 6);

typedef StoreCatalogLoader = Future<List<Store>> Function();

Future<List<Store>> loadStoreCatalog({
  Future<http.Response> Function(Uri)? request,
  SharedPreferences? preferences,
  DateTime? now,
}) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  final currentTime = (now ?? DateTime.now()).toUtc();
  final cachedAtMilliseconds = prefs.getInt(storeCatalogCachedAtKey);
  if (cachedAtMilliseconds != null) {
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      cachedAtMilliseconds,
      isUtc: true,
    );
    final age = currentTime.difference(cachedAt);
    if (!age.isNegative && age <= storeCatalogCacheMaxAge) {
      final cachedStores = _decodeStoreCatalog(
        prefs.getString(storeCatalogCacheKey),
      );
      if (cachedStores.isNotEmpty) return cachedStores;
    }
  }

  final uri = ApiClient.uri('/api/stores/all');
  final response =
      await (request ??
              (uri) =>
                  ApiClient.get(uri, headers: ApiClient.jsonHeaders()))(uri)
          .timeout(const Duration(seconds: 45));
  if (response.statusCode != 200) {
    throw http.ClientException(
      'Store catalog request failed (${response.statusCode})',
      uri,
    );
  }

  final stores = _decodeStoreCatalog(utf8.decode(response.bodyBytes));
  if (stores.isEmpty) {
    throw const FormatException('Empty store catalog');
  }

  try {
    await prefs.setString(
      storeCatalogCacheKey,
      jsonEncode(stores.map((store) => store.toJson()).toList()),
    );
    await prefs.setInt(
      storeCatalogCachedAtKey,
      currentTime.millisecondsSinceEpoch,
    );
  } catch (_) {
    // Safari 및 모바일 브라우저의 LocalStorage 5MB QuotaExceededError 발생 시
    // 캐시 저장만 건너뛰고 다운로드받은 메모리 상의 매장 목록으로 검색을 정상 수행합니다.
  }
  return stores;
}

List<Store> _decodeStoreCatalog(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final stores = <Store>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      try {
        final store = Store.fromJson(Map<String, dynamic>.from(item));
        if (store.hasValidCoordinates) stores.add(store);
      } catch (_) {
        // Skip one malformed item without discarding the usable catalog.
      }
    }
    return stores;
  } catch (_) {
    return const [];
  }
}

import 'dart:convert';

import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// v2 retains source-checked openingHours; v1 clients discarded that field.
const storeCatalogCacheKey = 'howmuch.store_cache.v2';
const storeCatalogCachedAtKey = 'howmuch.store_cache.cached_at.v2';
const storeCatalogCacheMaxAge = Duration(hours: 6);
const storeCatalogStorageTimeout = Duration(seconds: 2);
const storeCatalogRequestTimeout = Duration(seconds: 45);
// Includes optional local storage, the network request, and cache persistence.
const storeCatalogLoadTimeout = Duration(seconds: 55);

typedef StoreCatalogLoader = Future<List<Store>> Function();

Future<List<Store>>? _storeCatalogInFlight;

Future<List<Store>> loadStoreCatalog({
  Future<http.Response> Function(Uri)? request,
  SharedPreferences? preferences,
  DateTime? now,
  Future<SharedPreferences> Function()? preferencesLoader,
  Duration storageTimeout = storeCatalogStorageTimeout,
  Duration requestTimeout = storeCatalogRequestTimeout,
}) async {
  SharedPreferences? prefs;
  final currentTime = (now ?? DateTime.now()).toUtc();
  try {
    prefs =
        preferences ??
        await (preferencesLoader ?? SharedPreferences.getInstance)().timeout(
          storageTimeout,
        );
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
  } catch (_) {
    // Browser storage may be blocked or contain an incompatible cache value.
    // The network catalog remains usable without local persistence.
    prefs = null;
  }

  if (preferences == null && now == null) {
    final activeRequest = _storeCatalogInFlight;
    if (activeRequest != null) return activeRequest;
    final future = _fetchAndCacheStoreCatalog(
      request: request,
      preferences: prefs,
      currentTime: currentTime,
      storageTimeout: storageTimeout,
      requestTimeout: requestTimeout,
    );
    _storeCatalogInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_storeCatalogInFlight, future)) {
        _storeCatalogInFlight = null;
      }
    }
  }

  return _fetchAndCacheStoreCatalog(
    request: request,
    preferences: prefs,
    currentTime: currentTime,
    storageTimeout: storageTimeout,
    requestTimeout: requestTimeout,
  );
}

Future<List<Store>> _fetchAndCacheStoreCatalog({
  required Future<http.Response> Function(Uri)? request,
  required SharedPreferences? preferences,
  required DateTime currentTime,
  required Duration storageTimeout,
  required Duration requestTimeout,
}) async {
  final uri = ApiClient.uri('/api/stores/all');
  final response =
      await (request ??
              (uri) => ApiClient.get(
                uri,
                headers: ApiClient.jsonHeaders(),
                timeout: requestTimeout,
              ))(uri)
          .timeout(requestTimeout);
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
    if (preferences != null) {
      await _persistStoreCatalog(
        preferences,
        stores,
        currentTime,
      ).timeout(storageTimeout);
    }
  } catch (_) {
    // Safari 및 모바일 브라우저의 LocalStorage 5MB QuotaExceededError 발생 시
    // 캐시 저장만 건너뛰고 다운로드받은 메모리 상의 매장 목록으로 검색을 정상 수행합니다.
  }
  return stores;
}

Future<void> _persistStoreCatalog(
  SharedPreferences preferences,
  List<Store> stores,
  DateTime currentTime,
) async {
  final saved = await preferences.setString(
    storeCatalogCacheKey,
    jsonEncode(stores.map((store) => store.toJson()).toList()),
  );
  // Never refresh the timestamp when the catalog itself could not be saved.
  if (saved) {
    await preferences.setInt(
      storeCatalogCachedAtKey,
      currentTime.millisecondsSinceEpoch,
    );
  }
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

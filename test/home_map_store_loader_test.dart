import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/home_map_store_loader.dart';
import 'package:howmuch/features/store/store_catalog_loader.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;

void main() {
  const bounds = {
    'minLat': 37.0,
    'maxLat': 38.0,
    'minLng': 126.0,
    'maxLng': 127.0,
  };
  final cached = Store.fromJson({
    'storeName': '기존 매장',
    'latitude': 37.5,
    'longitude': 126.8,
  });

  test(
    'fresh stores replace cached stores and viewport is sent to the API',
    () async {
      final result = await loadHomeMapStores(
        bounds: bounds,
        cachedStores: [cached],
        request: (uri) async {
          expect(uri.path, '/api/stores/bounds');
          expect(uri.queryParameters['minLat'], '37.0');
          expect(uri.queryParameters['maxLng'], '127.0');
          return http.Response(
            jsonEncode([
              {'storeName': '새 매장', 'latitude': 37.6, 'longitude': 126.9},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );
      expect(result.single.storeName, '새 매장');
    },
  );

  test('connection failure preserves cached stores', () async {
    final result = await loadHomeMapStores(
      bounds: bounds,
      cachedStores: [cached],
      request: (_) async => throw http.ClientException('offline'),
    );
    expect(result, [cached]);
  });

  test(
    'slow request falls back and a late response cannot replace the result',
    () async {
      final pending = Completer<http.Response>();
      final result = await loadHomeMapStores(
        bounds: bounds,
        cachedStores: [cached],
        timeout: const Duration(milliseconds: 1),
        request: (_) => pending.future,
      );
      expect(result, [cached]);
      pending.complete(http.Response('[]', 200));
      await Future<void>.delayed(Duration.zero);
      expect(result, [cached]);
    },
  );

  for (final response in [
    http.Response('unavailable', 503),
    http.Response('<html>error</html>', 200),
    http.Response('{"error":"unavailable"}', 200),
    http.Response('[null]', 200),
  ]) {
    test(
      'HTTP or malformed response ${response.body} uses valid cached coordinates',
      () async {
        final result = await loadHomeMapStores(
          bounds: bounds,
          cachedStores: [cached, Store.fromJson({})],
          request: (_) async => response,
        );
        expect(result, [cached]);
      },
    );
  }

  test('successful empty response does not resurrect cached stores', () async {
    final result = await loadHomeMapStores(
      bounds: bounds,
      cachedStores: [cached],
      request: (_) async => http.Response('[]', 200),
    );
    expect(result, isEmpty);
  });

  test(
    'status result distinguishes fresh data from an offline fallback',
    () async {
      final fresh = await loadHomeMapStoresWithStatus(
        bounds: bounds,
        cachedStores: [cached],
        request: (_) async => http.Response('[]', 200),
      );
      final fallback = await loadHomeMapStoresWithStatus(
        bounds: bounds,
        cachedStores: [cached],
        request: (_) async => throw http.ClientException('offline'),
      );

      expect(fresh.hasFreshResponse, isTrue);
      expect(fresh.stores, isEmpty);
      expect(fallback.hasFreshResponse, isFalse);
      expect(fallback.stores, [cached]);
    },
  );

  test(
    'home map cache is capped and remains separate from the full catalog',
    () {
      final stores = List.generate(
        maxCachedHomeMapStores + 25,
        (index) => Store.fromJson({
          'storeName': '매장 $index',
          'latitude': 37.0 + index / 10000,
          'longitude': 127.0,
        }),
      );

      final encoded = encodeHomeMapStoreCache(stores);
      final restored = decodeHomeMapStoreCache(encoded);

      expect(homeMapStoreCacheKey, isNot(storeCatalogCacheKey));
      expect(restored, hasLength(maxCachedHomeMapStores));
      expect(restored.first.storeName, '매장 0');
      expect(restored.last.storeName, '매장 249');
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/store_catalog_loader.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'invalid browser cache metadata does not block the network catalog',
    () async {
      SharedPreferences.setMockInitialValues({
        storeCatalogCachedAtKey: 'broken',
      });
      final stores = await loadStoreCatalog(
        request: (_) async => http.Response(
          '[{"storeName":"recovered","latitude":37.5,"longitude":127.0}]',
          200,
        ),
      );
      expect(stores.single.storeName, 'recovered');
    },
  );
  test('loads and caches the full catalog only on demand', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var requestCount = 0;

    final stores = await loadStoreCatalog(
      preferences: prefs,
      request: (uri) async {
        requestCount++;
        expect(uri.path, '/api/stores/all');
        return http.Response(
          jsonEncode([
            {
              'storeId': 'store-1',
              'storeName': '실제 식당',
              'latitude': 37.5665,
              'longitude': 126.9780,
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      },
    );

    expect(requestCount, 1);
    expect(stores.single.storeName, '실제 식당');
    expect(prefs.getString(storeCatalogCacheKey), isNotEmpty);
    expect(prefs.getInt(storeCatalogCachedAtKey), isNotNull);
  });

  test(
    'reuses a fresh catalog cache without another network request',
    () async {
      final now = DateTime.utc(2026, 9, 11, 10);
      SharedPreferences.setMockInitialValues({
        storeCatalogCacheKey: jsonEncode([
          {
            'storeId': 'cached-1',
            'storeName': '캐시 식당',
            'latitude': 37.5665,
            'longitude': 126.9780,
          },
        ]),
        storeCatalogCachedAtKey: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });

      final stores = await loadStoreCatalog(
        now: now,
        request: (_) async => fail('신선한 캐시가 있으면 네트워크를 요청하지 않아야 합니다.'),
      );

      expect(stores.single.storeName, '캐시 식당');
    },
  );

  test('refreshes a stale catalog cache', () async {
    final now = DateTime.utc(2026, 9, 11, 10);
    SharedPreferences.setMockInitialValues({
      storeCatalogCacheKey: jsonEncode([
        {'storeName': '오래된 식당', 'latitude': 37.5, 'longitude': 126.9},
      ]),
      storeCatalogCachedAtKey: now
          .subtract(const Duration(hours: 7))
          .millisecondsSinceEpoch,
    });
    var requestCount = 0;

    final stores = await loadStoreCatalog(
      now: now,
      request: (_) async {
        requestCount++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'storeName': '새 식당', 'latitude': 37.6, 'longitude': 126.95},
            ]),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      },
    );

    expect(requestCount, 1);
    expect(stores.single.storeName, '새 식당');
  });

  test(
    'rejects an unusable catalog instead of caching fabricated data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await expectLater(
        loadStoreCatalog(
          preferences: prefs,
          request: (_) async => http.Response('[null]', 200),
        ),
        throwsFormatException,
      );
      expect(prefs.getString(storeCatalogCacheKey), isNull);
    },
  );
}

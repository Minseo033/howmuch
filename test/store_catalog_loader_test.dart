import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/store_catalog_loader.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stalled preferences initialization falls back to network', () async {
    final pendingPreferences = Completer<SharedPreferences>();
    final stores = await loadStoreCatalog(
      preferencesLoader: () => pendingPreferences.future,
      storageTimeout: const Duration(milliseconds: 10),
      request: (_) async => http.Response(
        '[{"storeName":"network","latitude":37.5,"longitude":127.0}]',
        200,
      ),
    );
    expect(stores.single.storeName, 'network');
  });

  test('stalled cache write cannot block downloaded results', () async {
    final preferences = _WriteControlledPreferences(Completer<bool>().future);
    final stores = await loadStoreCatalog(
      preferences: preferences,
      storageTimeout: const Duration(milliseconds: 10),
      request: (_) async => http.Response(
        '[{"storeName":"downloaded","latitude":37.5,"longitude":127.0}]',
        200,
      ),
    );
    expect(stores.single.storeName, 'downloaded');
    expect(preferences.timestampWrites, 0);
  });

  test('unsuccessful cache write does not mark the cache fresh', () async {
    final preferences = _WriteControlledPreferences(Future.value(false));
    final stores = await loadStoreCatalog(
      preferences: preferences,
      request: (_) async => http.Response(
        '[{"storeName":"downloaded","latitude":37.5,"longitude":127.0}]',
        200,
      ),
    );
    expect(stores, hasLength(1));
    expect(preferences.timestampWrites, 0);
  });

  test('timed out shared network request can be retried', () async {
    SharedPreferences.setMockInitialValues({});
    await expectLater(
      loadStoreCatalog(
        request: (_) => Completer<http.Response>().future,
        requestTimeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
    final recovered = await loadStoreCatalog(
      request: (_) async => http.Response(
        '[{"storeName":"retry","latitude":37.5,"longitude":127.0}]',
        200,
      ),
    );
    expect(recovered.single.storeName, 'retry');
  });

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

  test('shares an in-flight default catalog request across callers', () async {
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<http.Response>();
    var requestCount = 0;

    Future<http.Response> request(Uri uri) {
      requestCount++;
      expect(uri.path, '/api/stores/all');
      return pending.future;
    }

    final first = loadStoreCatalog(request: request);
    final second = loadStoreCatalog(request: request);

    await Future<void>.delayed(Duration.zero);
    pending.complete(
      http.Response.bytes(
        utf8.encode(
          jsonEncode([
            {'storeName': '동시 요청 식당', 'latitude': 37.5, 'longitude': 127.0},
          ]),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final results = await Future.wait([first, second]);
    expect(requestCount, 1);
    expect(results.first.single.storeName, '동시 요청 식당');
    expect(results.last.single.storeName, '동시 요청 식당');
  });

  test(
    'starts a new catalog request after the shared request settles',
    () async {
      SharedPreferences.setMockInitialValues({});
      var requestCount = 0;

      Future<http.Response> request(Uri uri) async {
        requestCount++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'storeName': '주입 요청 $requestCount',
                'latitude': 37.5,
                'longitude': 127.0,
              },
            ]),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      final first = await loadStoreCatalog(request: request);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storeCatalogCacheKey);
      await prefs.remove(storeCatalogCachedAtKey);
      final second = await loadStoreCatalog(request: request);

      expect(requestCount, 2);
      expect(first.single.storeName, '주입 요청 1');
      expect(second.single.storeName, '주입 요청 2');
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

class _WriteControlledPreferences implements SharedPreferences {
  _WriteControlledPreferences(this.writeResult);

  final Future<bool> writeResult;
  int timestampWrites = 0;

  @override
  int? getInt(String key) => null;

  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) => writeResult;

  @override
  Future<bool> setInt(String key, int value) async {
    timestampWrites++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

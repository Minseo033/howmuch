import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('account-a');
  });
  tearDown(() => ApiClient.setSessionToken(null));
  final uri = ApiClient.uri('/api/savings/stats', {'period': 'this_month'});
  Future<http.Response> read() => ApiClient.get(
    uri,
    headers: ApiClient.jsonHeaders(auth: true),
    cacheMaxAge: const Duration(seconds: 30),
  );

  test('parallel reads and a fresh return share one HTTP request', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(
      () async {
        final first = read();
        final second = read();
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        pending.complete(http.Response('{"amount":12000}', 200));
        expect((await first).body, (await second).body);
        expect((await read()).body, '{"amount":12000}');
        expect(calls, 1);
      },
      () => MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
  });

  test(
    'logout and another login never reuse an earlier account response',
    () async {
      final old = Completer<http.Response>();
      var calls = 0;
      await http.runWithClient(
        () async {
          final first = read();
          await Future<void>.delayed(Duration.zero);
          await ApiClient.setSessionToken('account-b');
          expect((await read()).body, 'account-b');
          old.complete(http.Response('account-a', 200));
          await first;
          expect((await read()).body, 'account-b');
          expect(calls, 2);
        },
        () => MockClient((request) {
          calls++;
          return request.headers['authorization'] == 'Bearer account-a'
              ? old.future
              : Future.value(http.Response('account-b', 200));
        }),
      );
    },
  );

  test(
    'a successful visit mutation detaches an older in-flight stats read',
    () async {
      final old = Completer<http.Response>();
      var reads = 0;
      await http.runWithClient(
        () async {
          final first = read();
          await Future<void>.delayed(Duration.zero);
          final revision = ApiClient.readCacheRevision;
          await ApiClient.delete(
            ApiClient.uri('/api/visits/visit-1'),
            headers: ApiClient.authHeaders(auth: true),
          );
          expect(ApiClient.readCacheRevision, greaterThan(revision));
          expect((await read()).body, 'after-delete');
          old.complete(http.Response('before-delete', 200));
          await first;
          expect((await read()).body, 'after-delete');
          expect(reads, 2);
        },
        () => MockClient((request) {
          if (request.method != 'GET') {
            return Future.value(http.Response('{}', 200));
          }
          reads++;
          return reads == 1
              ? old.future
              : Future.value(http.Response('after-delete', 200));
        }),
      );
    },
  );

  test(
    'an unsuccessful read is retried and a failed mutation preserves cache',
    () async {
      var reads = 0;
      await http.runWithClient(
        () async {
          expect((await read()).statusCode, 503);
          expect((await read()).body, 'recovered');
          final revision = ApiClient.readCacheRevision;
          await ApiClient.delete(
            ApiClient.uri('/api/visits/missing'),
            headers: ApiClient.authHeaders(auth: true),
          );
          expect(ApiClient.readCacheRevision, revision);
          expect((await read()).body, 'recovered');
          expect(reads, 2);
        },
        () => MockClient((request) async {
          if (request.method != 'GET') return http.Response('{}', 404);
          reads++;
          return reads == 1
              ? http.Response('', 503)
              : http.Response('recovered', 200);
        }),
      );
    },
  );

  test('a network exception is not cached', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        await expectLater(read(), throwsA(isA<http.ClientException>()));
        expect((await read()).body, 'recovered');
        expect(calls, 2);
      },
      () => MockClient((_) async {
        if (++calls == 1) throw http.ClientException('temporary failure');
        return http.Response('recovered', 200);
      }),
    );
  });

  test('an explicit refresh cannot leave the old cached read behind', () async {
    var calls = 0;
    await http.runWithClient(() async {
      expect((await read()).body, '1');
      expect(
        (await ApiClient.get(
          uri,
          headers: ApiClient.jsonHeaders(auth: true),
          cacheMaxAge: Duration.zero,
        )).body,
        '2',
      );
      expect((await read()).body, '3');
      expect((await read()).body, '3');
    }, () => MockClient((_) async => http.Response('${++calls}', 200)));
  });
}

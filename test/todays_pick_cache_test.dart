import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response() => http.Response.bytes(
  utf8.encode(jsonEncode({'weather': '맑음', 'picks': <Object>[]})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('repeat entry reuses a successful result for one minute', () async {
    var requests = 0;
    var now = DateTime(2026, 10, 13, 12);
    final service = TodaysPickService(
      MockClient((_) async {
        requests++;
        return response();
      }),
      const Duration(seconds: 20),
      () => now,
    );
    await service.getTodaysPick(lat: 37.5, lng: 127);
    now = now.add(const Duration(seconds: 59));
    await service.getTodaysPick(lat: 37.5, lng: 127);
    expect(requests, 1);
    now = now.add(const Duration(seconds: 1));
    await service.getTodaysPick(lat: 37.5, lng: 127);
    expect(requests, 2);
  });

  test('simultaneous callers share one pending request', () async {
    var requests = 0;
    final pending = Completer<http.Response>();
    final service = TodaysPickService(
      MockClient((_) {
        requests++;
        return pending.future;
      }),
    );
    final first = service.getTodaysPick(lat: 37.5, lng: 127);
    final second = service.getTodaysPick(lat: 37.5, lng: 127);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    pending.complete(response());
    expect(await first, await second);
  });

  test(
    'changed coordinates and radius fetch their own recommendations',
    () async {
      var requests = 0;
      final service = TodaysPickService(
        MockClient((_) async {
          requests++;
          return response();
        }),
      );
      await service.getTodaysPick(lat: 37.5, lng: 127);
      await service.getTodaysPick(lat: 37.500001, lng: 127);
      await service.getTodaysPick(lat: 37.5, lng: 127, radiusMeters: 1000);
      expect(requests, 3);
    },
  );

  test(
    'explicit retry fetches fresh data and failures are not cached',
    () async {
      var requests = 0;
      final service = TodaysPickService(
        MockClient((_) async {
          requests++;
          return requests == 2 ? http.Response('{}', 503) : response();
        }),
      );
      await service.getTodaysPick(lat: 37.5, lng: 127);
      final failed = await service.getTodaysPick(
        lat: 37.5,
        lng: 127,
        forceRefresh: true,
      );
      expect(failed['error'], true);
      final recovered = await service.getTodaysPick(lat: 37.5, lng: 127);
      expect(recovered['error'], isNull);
      expect(requests, 3);
    },
  );

  test('new calendar day invalidates even a recent recommendation', () async {
    var requests = 0;
    var now = DateTime(2026, 10, 13, 23, 59, 59);
    final service = TodaysPickService(
      MockClient((_) async {
        requests++;
        return response();
      }),
      const Duration(seconds: 20),
      () => now,
    );
    await service.getTodaysPick(lat: 37.5, lng: 127);
    now = now.add(const Duration(seconds: 2));
    await service.getTodaysPick(lat: 37.5, lng: 127);
    expect(requests, 2);
  });

  test('cache is bounded and does not cache AI route requests', () async {
    var requests = 0;
    final service = TodaysPickService(
      MockClient((_) async {
        requests++;
        return response();
      }),
    );
    for (var i = 0; i < 9; i++) {
      await service.getTodaysPick(lat: 37.5 + i * .001, lng: 127);
    }
    await service.getTodaysPick(lat: 37.5, lng: 127);
    expect(requests, 10);
    await service.getRoute(lat: 37.5, lng: 127);
    await service.getRoute(lat: 37.5, lng: 127);
    expect(requests, 12);
  });
}

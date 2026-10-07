import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

// 이전 서버의 절약 내역 응답처럼 storeSource 없이 정부 인증 여부(isGov)만 있습니다.
final _history = [
  {
    'id': 'visit-gov',
    'storeId': 'store-gov',
    'storeName': '흥부순대국',
    'category': '한식',
    'date': '2026-10-05T12:00:00+09:00',
    'menu': '순대국',
    'price': 8000,
    'savedAmount': 1500,
    'isGov': true,
  },
  {
    'id': 'visit-user',
    'storeId': 'store-hak',
    'storeName': '동양미래대학교 학식당',
    'category': '한식',
    'date': '2026-10-06T12:00:00+09:00',
    'menu': '라면',
    'price': 4000,
    'savedAmount': 2000,
    'isGov': false,
  },
  {
    'id': 'visit-missing',
    'storeId': 'store-gone',
    'storeName': '없어진 매장',
    'category': '한식',
    'date': '2026-10-04T12:00:00+09:00',
    'menu': '백반',
    'price': 7000,
    'savedAmount': 1000,
    'isGov': false,
  },
  {
    'id': 'visit-old',
    'storeId': 'store-old',
    'storeName': '작년 매장',
    'category': '한식',
    'date': '2025-12-31T12:00:00+09:00',
    'menu': '국수',
    'price': 5000,
    'savedAmount': 1000,
    'isGov': false,
  },
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('savings-session');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('savings details show the store source used by the map and '
      'detail instead of a blanket 출처 확인 필요 (QA #41)', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storeRequests = <String>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: SavingsDetailScreen(
              startDate: '2026-01-01',
              endDateExclusive: '2027-01-01',
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/savings/history') return _json(_history);
        if (path.startsWith('/api/stores/')) {
          final id = Uri.decodeComponent(path.substring('/api/stores/'.length));
          storeRequests.add(id);
          if (id == 'store-hak') {
            return _json({
              'storeId': 'store-hak',
              'storeName': '동양미래대학교 학식당',
              'source': 'USER',
            });
          }
          return http.Response('', 404);
        }
        return http.Response('', 404);
      }),
    );

    // 정부 인증 기록과 기간 밖 기록은 매장 정보를 다시 묻지 않습니다.
    expect(storeRequests.toSet(), {'store-hak', 'store-gone'});
    expect(find.text('동양미래대학교 학식당'), findsOneWidget);
    expect(find.text('정부 인증'), findsOneWidget);
    expect(find.text('사용자 제보'), findsOneWidget);
    // 매장 정보를 확인하지 못한 기록은 출처를 추측하지 않습니다.
    expect(find.text('출처 확인 필요'), findsOneWidget);
    expect(find.text('작년 매장'), findsNothing);
  });

  testWidgets('savings details use the storeSource sent with the history '
      'instead of asking for each store (QA #41)', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storeRequests = <String>[];
    // 서버는 출처를 함께 보내고, 매장 목록에서 찾지 못한 매장만 비워 둡니다.
    final history = [
      {..._history[0], 'storeSource': 'GOV'},
      {..._history[1], 'storeSource': 'USER'},
      {..._history[2], 'storeSource': null},
    ];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: SavingsDetailScreen(
              startDate: '2026-01-01',
              endDateExclusive: '2027-01-01',
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/savings/history') return _json(history);
        if (path.startsWith('/api/stores/')) {
          storeRequests.add(
            Uri.decodeComponent(path.substring('/api/stores/'.length)),
          );
        }
        return http.Response('', 404);
      }),
    );

    // 출처를 받은 기록은 매장을 다시 묻지 않고, 비어 있는 기록만 지금처럼 확인합니다.
    expect(storeRequests, ['store-gone']);
    expect(find.text('정부 인증'), findsOneWidget);
    expect(find.text('사용자 제보'), findsOneWidget);
    expect(find.text('출처 확인 필요'), findsOneWidget);
  });
}

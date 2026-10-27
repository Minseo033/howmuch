import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/presentation/screens/price_history_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _store = Store(
  id: 'history-store',
  storeName: '이력 식당',
  address: '서울',
  phoneNumber: '',
  industry: '한식',
  menu1: '보리밥',
  price1: '3000',
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: 37.5,
  longitude: 127,
  source: 'GOV',
);

void main() {
  testWidgets('retry clears the error view and shows the loaded history', (
    tester,
  ) async {
    final pending = <Completer<http.Response>>[];
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(home: PriceHistoryScreen(store: _store)),
        );
        pending.single.complete(http.Response('{}', 503));
        await tester.pumpAndSettle();
        expect(
          find.text('가격 이력을 불러오지 못했어요. 잠시 후 다시 시도해주세요.'),
          findsOneWidget,
        );

        await tester.tap(find.text('다시 시도'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text('가격 이력을 불러오지 못했어요. 잠시 후 다시 시도해주세요.'),
          findsNothing,
        );

        pending.last.complete(
          http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'storeName': '이력 식당',
                'menuName': '보리밥',
                'currentPrice': '3000',
                'history': [
                  {
                    'price': '0',
                    'free': true,
                    'source': 'USER',
                    'description': '승인된 가격 변동 반영',
                    'date': '2026-10-01T03:00:00Z',
                  },
                ],
              }),
            ),
            200,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('가격 이력을 불러오지 못했어요. 잠시 후 다시 시도해주세요.'),
          findsNothing,
        );
        expect(find.text('승인된 가격 변동 반영'), findsOneWidget);
        expect(find.text('무료'), findsOneWidget);
        expect(find.text('0원'), findsNothing);
      },
      () => MockClient((request) {
        requests.add(request);
        final response = Completer<http.Response>();
        pending.add(response);
        return response.future;
      }),
    );

    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('content-type')),
      );
    }
  });

  test('a free history entry is labelled 무료, a paid one keeps its price', () {
    expect(formatPriceHistoryPrice('0', free: true), '무료');
    expect(formatPriceHistoryPrice('4500'), '4,500원');
    expect(formatPriceHistoryPrice(null), '가격 정보 없음');
    expect(formatPriceHistoryDate('not a date'), '날짜 정보 없음');
  });
}

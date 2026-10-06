import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/visit_history_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('formats location and receipt verification methods', () {
    expect(formatVisitVerification('LOCATION', 49.6), '위치 인증 · 50m');
    expect(formatVisitVerification('RECEIPT_OCR', null), '영수증 OCR 인증');
    expect(formatVisitVerification('UNKNOWN', null), isNull);
  });

  test('visit dates use the Korean calendar day', () {
    // 16:30 UTC is already the next morning in Korea.
    expect(formatVisitDateKst('2026-10-06T16:30:00Z'), '2026.10.07');
    expect(formatVisitDateKst('2026-10-06T14:59:00Z'), '2026.10.06');
    expect(formatVisitDateKst(null), '최근 방문');
  });

  test('a recorded 0원 visit is free, a missing price is unknown', () {
    expect(isFreeVisit({'price': 0}), isTrue);
    expect(isFreeVisit({'price': 7000, 'isFree': true}), isTrue);
    expect(isFreeVisit({'price': 7000}), isFalse);
    expect(isFreeVisit({'price': null}), isFalse);
  });

  testWidgets('a late failure after leaving the screen is ignored', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: VisitHistoryScreen()));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      response.completeError(http.ClientException('offline'));
      await tester.pumpAndSettle();
    }, () => MockClient((_) => response.future));

    expect(tester.takeException(), isNull);
  });
}

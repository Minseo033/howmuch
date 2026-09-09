import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_report_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('chart items keep a dynamic map type for summary reduction', () {
    final items = parseSavingsChartItems([
      <String, dynamic>{'label': '1주', 'amount': 1200, 'isMax': false},
      <String, dynamic>{'label': '2주', 'amount': 3400, 'isMax': true},
    ]);

    final maxItem = items.reduce((a, b) {
      return (a['amount'] as int) >= (b['amount'] as int) ? a : b;
    });

    expect(items, isA<List<Map<String, dynamic>>>());
    expect(maxItem['label'], '2주');
    expect(maxItem['amount'], 3400);
  });

  testWidgets('does not render a failed period as zero savings', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: SavingsReportDashboardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('절약 데이터를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    }, () => MockClient(_dashboardResponseWithCurrentPeriodFailure));
  });

  testWidgets('marks a failed auxiliary count as unavailable', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: SavingsReportDashboardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('찜한 매장'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    }, () => MockClient(_dashboardResponseWithFavoritesFailure));
  });
}

Future<http.Response> _dashboardResponseWithCurrentPeriodFailure(
  http.Request request,
) async {
  if (request.url.path.endsWith('/api/savings/stats')) {
    if (request.url.queryParameters['period'] == 'this_month') {
      return http.Response('{}', 500);
    }
    return _statsResponse();
  }
  return _auxiliaryResponse(request);
}

Future<http.Response> _dashboardResponseWithFavoritesFailure(
  http.Request request,
) async {
  if (request.url.path.endsWith('/api/savings/stats')) {
    return _statsResponse();
  }
  if (request.url.path.endsWith('/api/favorites')) {
    return http.Response('{}', 500);
  }
  return _auxiliaryResponse(request);
}

http.Response _statsResponse() => _jsonResponse({
  'totalSavedAmount': 12000,
  'totalVisits': 3,
  'chartTitle': '절약 금액',
  'chartItems': <Object>[],
});

http.Response _auxiliaryResponse(http.Request request) {
  if (request.url.path.endsWith('/api/savings/goal')) {
    return _jsonResponse({'goalAmount': 50000});
  }
  if (request.url.path.endsWith('/api/favorites')) {
    return _jsonResponse([1, 2]);
  }
  if (request.url.path.endsWith('/api/report/my')) {
    return _jsonResponse([1, 2, 3, 4, 5]);
  }
  return http.Response('{}', 404);
}

http.Response _jsonResponse(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

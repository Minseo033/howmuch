import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_report_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('formats monthly chart amounts without overflowing narrow cells', () {
    expect(formatSavingsChartAmount(0), '0');
    expect(formatSavingsChartAmount(950), '950');
    expect(formatSavingsChartAmount(1000), '1천');
    expect(formatSavingsChartAmount(1500), '1.5천');
    expect(formatSavingsChartAmount(10000), '1만');
    expect(formatSavingsChartAmount(17000), '1.7만');
  });

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

  for (final size in [const Size(320, 568), const Size(430, 844)]) {
    testWidgets('yearly monthly chart stays inside the card at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: SavingsReportDashboardScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('올해'));
        await tester.pump();

        final chartRect = tester.getRect(
          find.byKey(const ValueKey('savings-yearly-line-chart')),
        );
        expect(chartRect.left, greaterThanOrEqualTo(0));
        expect(chartRect.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
      }, () => MockClient(_dashboardResponseWithYearlyChart));
    });
  }

  testWidgets(
    'renders smooth line chart across all tabs with unified yearly line chart',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: SavingsReportDashboardScreen()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('savings-weekly-line-chart')),
          findsOneWidget,
        );
        expect(find.text('이번 달 절약 금액'), findsOneWidget);

        await tester.tap(find.text('지난 달'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('savings-weekly-line-chart')),
          findsOneWidget,
        );
        expect(find.text('지난 달 절약 금액'), findsOneWidget);

        await tester.tap(find.text('올해'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('savings-yearly-line-chart')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('savings-weekly-line-chart')),
          findsNothing,
        );
      }, () => MockClient(_dashboardResponseWithWeeklyAndYearlyChart));
    },
  );
}

Future<http.Response> _dashboardResponseWithYearlyChart(
  http.Request request,
) async {
  if (request.url.path.endsWith('/api/savings/stats')) {
    final yearly = request.url.queryParameters['period'] == 'this_year';
    return _statsResponse(
      chartTitle: yearly ? '월별 절약 금액' : '절약 금액',
      chartItems: yearly
          ? List.generate(12, (index) {
              final month = index + 1;
              final amount = month == 8
                  ? 17000
                  : month == 9
                  ? 1500
                  : 0;
              return {
                'label': '$month월',
                'amount': amount,
                'isMax': month == 8,
              };
            })
          : const [],
    );
  }
  return _auxiliaryResponse(request);
}

Future<http.Response> _dashboardResponseWithWeeklyAndYearlyChart(
  http.Request request,
) async {
  if (request.url.path.endsWith('/api/savings/stats')) {
    final period = request.url.queryParameters['period'];
    if (period == 'this_year') {
      return _statsResponse(
        chartTitle: '월별 절약 금액',
        chartItems: List.generate(12, (i) => {
          'label': '${i + 1}월',
          'amount': 1000,
          'isMax': i == 7,
        }),
      );
    }
    return _statsResponse(
      chartTitle: '주차별 절약 금액',
      chartItems: List.generate(5, (i) => {
        'label': '${i + 1}주',
        'amount': (i + 1) * 2000,
        'isMax': i == 4,
      }),
    );
  }
  return _auxiliaryResponse(request);
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

http.Response _statsResponse({
  String chartTitle = '절약 금액',
  List<Object> chartItems = const [],
}) => _jsonResponse({
  'totalSavedAmount': 12000,
  'totalVisits': 3,
  'chartTitle': chartTitle,
  'chartItems': chartItems,
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

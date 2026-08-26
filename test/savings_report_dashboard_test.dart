import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_report_dashboard_screen.dart';

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
}

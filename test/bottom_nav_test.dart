import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

void main() {
  testWidgets('highlights the savings report navigation item in blue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 80,
              child: HowmuchBottomNav(
                safeBottom: 8,
                activeTab: HowmuchBottomTab.savings,
              ),
            ),
          ),
        ),
      ),
    );

    final reportIcon = tester.widget<Icon>(
      find.byIcon(Icons.bar_chart_rounded),
    );
    final reportLabel = tester.widget<Text>(find.text('리포트'));

    expect(reportIcon.color, HowmuchBottomNav.blue);
    expect(reportLabel.style?.color, HowmuchBottomNav.blue);
    final reportSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '리포트 탭',
      ),
    );
    expect(reportSemantics.properties.button, isTrue);
    expect(reportSemantics.properties.selected, isTrue);
  });
}

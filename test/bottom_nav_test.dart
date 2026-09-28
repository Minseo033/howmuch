import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

void main() {
  testWidgets(
    'highlights the savings report navigation item with the brand palette',
    (tester) async {
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
      final exploreIcon = tester.widget<Icon>(
        find.byIcon(Icons.explore_outlined),
      );
      final exploreLabel = tester.widget<Text>(find.text('탐색'));

      expect(reportIcon.color, AppColors.primary);
      expect(reportLabel.style?.color, HowmuchBottomNav.blue);
      expect(exploreIcon.color, AppColors.textMuted);
      expect(exploreLabel.style?.color, AppColors.textMuted);
      expect(exploreLabel.style?.fontWeight, FontWeight.w600);
      final reportSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '리포트 탭',
        ),
      );
      expect(reportSemantics.properties.button, isTrue);
      expect(reportSemantics.properties.selected, isTrue);

      final navigationSurface = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).borderRadius ==
                  BorderRadius.circular(28),
        ),
      );
      final decoration = navigationSurface.decoration as BoxDecoration;

      expect(decoration.color, AppColors.white.withValues(alpha: .95));
    },
  );
}

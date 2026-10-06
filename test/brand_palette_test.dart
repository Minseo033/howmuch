import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/status_badge.dart';

void main() {
  test('keeps the original HowMuch brand palette', () {
    expect(AppColors.primary, const Color(0xFF2563EB));
    expect(AppColors.primaryPressed, const Color(0xFF1D4ED8));
    expect(AppColors.primaryLight, const Color(0xFFEFF4FF));
    expect(AppColors.orangeTheme, const Color(0xFFF27E22));
    expect(AppColors.success, const Color(0xFF047857));
    expect(AppColors.error, const Color(0xFFEF4444));
    expect(AppColors.ink, const Color(0xFF0F172A));
    expect(AppColors.surface, const Color(0xFFF4F6FA));
    expect(AppColors.white, Colors.white);
  });
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('red text and destructive fills meet AA (FE-MY-20)', () {
    expect(contrast(AppColors.error, AppColors.white), lessThan(4.5));
    expect(contrast(AppColors.errorText, AppColors.white), greaterThan(4.5));
    expect(
      contrast(AppColors.errorText, AppColors.errorLight),
      greaterThan(4.5),
    );
  });

  testWidgets('status badges use AA text colors', (tester) async {
    for (final type in BadgeType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: StatusBadge(type: type)),
        ),
      );
      final badge = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(StatusBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      final background = (badge.decoration! as BoxDecoration).color!;
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(StatusBadge),
          matching: find.byType(Text),
        ),
      );
      expect(
        contrast(label.style!.color!, background),
        greaterThan(4.5),
        reason: '${label.data} badge text',
      );
    }
  });
}

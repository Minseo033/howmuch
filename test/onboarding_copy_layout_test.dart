import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';

const _copy = [
  ('내 주변 착한가격업소를 한눈에', '공공데이터 기반으로 인증된 저렴한 매장을 지도에서 쉽게 찾아보세요.'),
  ('오늘 아낀 금액이 쌓여요', '공공 가격 데이터와 비교해 얼마나 절약했는지 월별 리포트로 확인할 수 있어요.'),
  ('좋은 가격은 함께 나눠요', '지도에 없는 동네 가성비 매장을 제보하고, 더 정확한 가격 정보를 만들어보세요.'),
];

Future<void> _pumpSlide(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required int step,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: OnboardingNearbyScreen(key: ValueKey(step), initialStep: step),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lays the paragraph out again to read its visual lines.
List<LineMetrics> _lines(RenderParagraph paragraph) {
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  final lines = painter.computeLineMetrics();
  painter.dispose();
  return lines;
}

void main() {
  for (final size in const [Size(320, 568), Size(375, 812), Size(430, 932)]) {
    for (final textScale in const [1.0, 1.3]) {
      final name =
          '${size.width.toInt()}x${size.height.toInt()} text x$textScale';
      testWidgets(
        'onboarding copy is centered and breaks between words at $name',
        (tester) async {
          for (var step = 0; step < _copy.length; step++) {
            await _pumpSlide(
              tester,
              size: size,
              textScale: textScale,
              step: step,
            );
            expect(tester.takeException(), isNull);

            final (title, description) = _copy[step];
            for (final label in [title, description]) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: find.bySemanticsLabel(label),
                  matching: find.byType(RichText),
                ),
              );
              final shown = paragraph.text.toPlainText();
              // Line breaks replace spaces only, so no word is split.
              expect(shown.replaceAll('\n', ' '), label);
              // Each visual line is one of those lines; nothing wrapped again.
              final lines = _lines(paragraph);
              expect(lines, hasLength('\n'.allMatches(shown).length + 1));

              final left = paragraph.localToGlobal(Offset.zero).dx;
              for (final line in lines) {
                expect(
                  left + line.left + line.width / 2,
                  moreOrLessEquals(size.width / 2, epsilon: 1),
                  reason: '"$label" line ${line.lineNumber} is off center',
                );
              }
            }
          }
        },
      );
    }
  }

  // QA 10/6 FE-MY-22: the copy had a fixed 180px slot and overflowed it.
  for (final size in const [Size(320, 568), Size(375, 812)]) {
    testWidgets(
      'onboarding copy grows with 2x system text at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        for (var step = 0; step < _copy.length; step++) {
          await _pumpSlide(tester, size: size, textScale: 2, step: step);
          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel(_copy[step].$1), findsOneWidget);
        }
      },
    );
  }
}

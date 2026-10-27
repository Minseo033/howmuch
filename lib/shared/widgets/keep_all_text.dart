import 'package:flutter/widgets.dart';

/// Text that wraps only between words, like CSS `word-break: keep-all`.
///
/// Flutter can wrap Korean between any two syllables, splitting words such as
/// '찾아보세요' across lines. Whole words are packed into lines that fit the
/// width instead; a single word wider than the line still wraps on its own.
class KeepAllText extends StatelessWidget {
  const KeepAllText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    // Measure with the same style, text size and bold text setting that the
    // Text below resolves.
    var measuredStyle = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      measuredStyle = measuredStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          textDirection: textDirection,
          textScaler: textScaler,
          locale: locale,
        );
        // The 1px margin keeps rounding from wrapping a line measured to fit.
        bool fits(String line) {
          painter
            ..text = TextSpan(text: line, style: measuredStyle)
            ..layout();
          return painter.width <= constraints.maxWidth - 1;
        }

        final lines = <String>[];
        for (final hardLine in text.split('\n')) {
          var line = '';
          for (final word in hardLine.split(' ')) {
            if (line.isEmpty || fits('$line $word')) {
              line = line.isEmpty ? word : '$line $word';
            } else {
              lines.add(line);
              line = word;
            }
          }
          lines.add(line);
        }
        painter.dispose();

        return Text(
          lines.join('\n'),
          semanticsLabel: text.replaceAll('\n', ' '),
          textAlign: textAlign,
          style: style,
        );
      },
    );
  }
}

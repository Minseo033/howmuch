import 'package:flutter/material.dart';

/// A small, safe Markdown subset for AI answer display.
///
/// It only handles emphasis and unordered lists; links, HTML, images and
/// actions from a model response remain ordinary text.
@immutable
class AiChatTextSegment {
  const AiChatTextSegment(this.text, {this.isBold = false});

  final String text;
  final bool isBold;
}

@visibleForTesting
List<AiChatTextSegment> parseAiChatDisplayText(String text) {
  final segments = <AiChatTextSegment>[];
  final lines = text.split('\n');

  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    var line = lines[lineIndex];
    final bullet = RegExp(r'^\s*[-*]\s+').firstMatch(line);
    if (bullet != null) {
      segments.add(const AiChatTextSegment('• '));
      line = line.substring(bullet.end);
    }

    final emphasis = RegExp(r'\*\*([^*\n]+)\*\*|\*([^*\n]+)\*');
    var cursor = 0;
    for (final match in emphasis.allMatches(line)) {
      if (match.start > cursor) {
        segments.add(AiChatTextSegment(line.substring(cursor, match.start)));
      }
      final strong = match.group(1);
      segments.add(
        AiChatTextSegment(
          strong ?? match.group(2) ?? '',
          isBold: strong != null,
        ),
      );
      cursor = match.end;
    }
    if (cursor < line.length) {
      segments.add(AiChatTextSegment(line.substring(cursor)));
    }
    if (lineIndex < lines.length - 1) {
      segments.add(const AiChatTextSegment('\n'));
    }
  }
  return segments;
}

TextSpan buildAiChatDisplayTextSpan(String text, TextStyle style) {
  return TextSpan(
    children: [
      for (final segment in parseAiChatDisplayText(text))
        TextSpan(
          text: segment.text,
          style: segment.isBold
              ? style.copyWith(fontWeight: FontWeight.w800)
              : style,
        ),
    ],
  );
}

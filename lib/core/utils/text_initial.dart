import 'package:flutter/widgets.dart' show StringCharacters;

/// First user-perceived character of [text], for avatar initials.
///
/// `text[0]` returns one UTF-16 code unit. For an emoji or another
/// surrogate pair that is half a character, and the text engine throws
/// "not well-formed UTF-16" when it is rendered.
String displayInitial(String? text, {String fallback = '?'}) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed.characters.first;
}

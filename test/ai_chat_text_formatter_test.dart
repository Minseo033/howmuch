import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_text_formatter.dart';

void main() {
  test('renders common recommendation Markdown without raw asterisks', () {
    final segments = parseAiChatDisplayText('* **서교밥집** — *돈까스* · 7,000원');

    expect(
      segments.map((segment) => segment.text).join(),
      '• 서교밥집 — 돈까스 · 7,000원',
    );
    expect(
      segments.singleWhere((segment) => segment.text == '서교밥집').isBold,
      isTrue,
    );
    expect(
      segments.singleWhere((segment) => segment.text == '돈까스').isBold,
      isFalse,
    );
  });

  test('keeps separate list lines readable', () {
    final segments = parseAiChatDisplayText('* 첫 번째\n- **두 번째**');
    expect(segments.map((segment) => segment.text).join(), '• 첫 번째\n• 두 번째');
  });
}

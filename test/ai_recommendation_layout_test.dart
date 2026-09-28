import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';

void main() {
  test('numbered recommendations split into intro and store rows', () {
    final result = splitAiRecommendationText(
      '1만원 이하 세 곳이에요.\n'
      '1. 아주 긴 이름의 동네 식당 — 김치찌개 · 9,000원 · 1.2km\n'
      '2. 두 번째 식당 — 비빔국수 · 4,000원 · 850m',
    );
    expect(result, isNotNull);
    expect(result!.$1, '1만원 이하 세 곳이에요.');
    expect(result.$2.length, 2);
    expect(result.$2.first.$1, '아주 긴 이름의 동네 식당');
    expect(result.$2.first.$2, '김치찌개 · 9,000원 · 1.2km');
  });

  test('ordinary AI prose is left untouched', () {
    expect(splitAiRecommendationText('근처 매장을 찾지 못했어요.'), isNull);
  });

  test('store cards do not expose markdown emphasis symbols', () {
    final result = splitAiRecommendationText(
      '추천 매장\n1. **첫 식당** — *김치찌개* · 9,000원\n'
      '2. **둘째 식당** — 칼국수 · 8,000원',
    );
    expect(result!.$2.first.$1, '첫 식당');
    expect(result.$2.first.$2, '김치찌개 · 9,000원');
  });
}

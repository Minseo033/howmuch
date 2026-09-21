import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/utils/price_formatter.dart';

void main() {
  test('formats numeric prices with comma separators and won suffix', () {
    expect(formatWon(6500), '6,500원');
    expect(formatWon('24000'), '24,000원');
    expect(formatWon('24,000원'), '24,000원');
  });

  test('preserves non-numeric labels and handles empty values', () {
    expect(formatWon('가격 변동'), '가격 변동');
    expect(formatWon(null, fallback: '가격 정보 없음'), '가격 정보 없음');
    expect(formatWonAmount(18920), '18,920');
  });
}

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

  test('does not concatenate alternatives or range endpoints', () {
    expect(formatWon('3,000 / 3,500'), '3,000 / 3,500원');
    expect(formatWon('3000~3500원'), '3,000 ~ 3,500원');
    expect(parsePriceValue('3,000 / 3,500')!.minimum, 3000);
    expect(parsePriceValue('3,000 / 3,500')!.maximum, 3500);
    expect(parsePriceValue('가격 3000 문의 3500'), isNull);
    expect(parsePriceValue('-1000'), isNull);
    expect(parsePriceValue('10,000,001'), isNull);
  });

  test('only explicitly free menu prices can be zero', () {
    expect(minimumMenuPrice('0'), isNull);
    expect(minimumMenuPrice('0', free: true), 0);
    expect(formatMenuPrice('0'), '가격 확인 필요');
    expect(formatMenuPrice('0', free: true), '무료');
    expect(minimumMenuPrice('0 / 0', free: true), isNull);
    expect(formatMenuPrice('0 / 0', free: true), '가격 확인 필요');
    expect(formatMenuPrice('5000', free: true), '가격 확인 필요');
    expect(formatMenuPrice(null, free: true), '가격 확인 필요');
  });
}

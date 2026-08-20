import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';

void main() {
  test('parses numeric and decorated recommendation prices', () {
    expect(parseRecommendationPrice(5000), 5000);
    expect(parseRecommendationPrice('5,000'), 5000);
    expect(parseRecommendationPrice('2,000원'), 2000);
  });

  test('formats one won suffix and thousands separators', () {
    expect(formatRecommendationPrice('5000'), '5,000원');
    expect(formatRecommendationPrice('2,000원'), '2,000원');
  });

  test('returns the requested empty state for invalid prices', () {
    expect(formatRecommendationPrice(null), '가격 정보 없음');
    expect(formatRecommendationPrice('문의', unavailable: ''), isEmpty);
    expect(parseRecommendationPrice('-1000'), isNull);
  });
}

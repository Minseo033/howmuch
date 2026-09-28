import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';

void main() {
  test('price follows the recommended menu rather than the first menu', () {
    expect(
      recommendationMenuPrice({
        'menu1': '백반',
        'price1': '6500',
        'menu2': '냉면',
        'price2': '8000',
        'matchedMenu': '냉면',
      }),
      '8000',
    );
    expect(
      recommendationMenuPrice({
        'menu1': '백반',
        'price1': '6500',
        'matchedMenu': '냉면',
      }),
      isNull,
    );
    expect(recommendationMenuPrice({'menu1': '백반', 'price1': '6500'}), '6500');
  });

  test('selection keeps the store identity and the non-primary menu price', () {
    final selection = RecommendationMenuSelection.fromPick({
      'storeId': 'store-1',
      'storeName': '천이오겹살',
      'menu1': '삼겹살',
      'price1': '10000',
      'menu2': '비빔국수',
      'price2': '4000',
      'matchedMenu': '비빔국수',
    });

    expect(selection.storeId, 'store-1');
    expect(selection.menu, '비빔국수');
    expect(selection.price, '4000');
    expect(selection.matches(id: 'store-1', name: '다른 이름'), isTrue);
  });
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

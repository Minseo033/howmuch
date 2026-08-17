import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';

void main() {
  test('formats sub-kilometer recommendation distances as meters', () {
    expect(formatRecommendationDistance(799), '799m');
  });

  test('formats long recommendation distances as kilometers', () {
    expect(formatRecommendationDistance(15771), '15.8km');
  });

  test('rejects missing and invalid distances', () {
    expect(formatRecommendationDistance(null), '거리 정보 없음');
    expect(formatRecommendationDistance(double.nan), '거리 정보 없음');
    expect(formatRecommendationDistance(-1), '거리 정보 없음');
  });
}

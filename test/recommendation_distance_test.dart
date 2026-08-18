import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_weather.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';

void main() {
  test('formats the forecast slot beside the temperature', () {
    expect(formatForecastTime('202608182200'), '22시 기준');
    expect(formatForecastTime('2026-08-18T22:00:00'), '22시 기준');
  });

  test('hides an invalid forecast slot', () {
    expect(formatForecastTime(null), isEmpty);
    expect(formatForecastTime('202608189900'), isEmpty);
    expect(formatForecastTime('unknown'), isEmpty);
  });

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

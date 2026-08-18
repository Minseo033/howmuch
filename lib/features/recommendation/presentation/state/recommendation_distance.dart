String formatRecommendationDistance(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) {
    return '거리 정보 없음';
  }
  if (meters < 1000) {
    return '${meters.round()}m';
  }

  final kilometers = meters / 1000;
  return '${kilometers.toStringAsFixed(1)}km';
}

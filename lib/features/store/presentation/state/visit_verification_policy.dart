class VisitVerificationPolicy {
  const VisitVerificationPolicy._();

  static const maxDistanceMeters = 50.0;

  static bool hasValidStoreCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude != 0 &&
        longitude != 0 &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180;
  }

  static bool isWithinVerificationRadius(double distanceMeters) {
    return distanceMeters.isFinite &&
        distanceMeters >= 0 &&
        distanceMeters <= maxDistanceMeters;
  }

  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) return '${distanceMeters.round()}m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }
}

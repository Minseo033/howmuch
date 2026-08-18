class RouteMapPoint {
  final int order;
  final String name;
  final double latitude;
  final double longitude;

  const RouteMapPoint({
    required this.order,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'order': order,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };
}

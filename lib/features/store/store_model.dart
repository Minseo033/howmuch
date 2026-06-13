class Store {
  final String storeName;
  final String address;
  final String phoneNumber;
  final String industry;
  final String menu1;
  final String price1;
  final double latitude;
  final double longitude;
  final String source; // 💡 GOV 또는 USER

  Store({
    required this.storeName,
    required this.address,
    required this.phoneNumber,
    required this.industry,
    required this.menu1,
    required this.price1,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeName: json['storeName'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      industry: json['industry'] ?? '기타',
      menu1: json['menu1'] ?? '',
      price1: json['price1'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] ?? 'GOV',
    );
  }
}

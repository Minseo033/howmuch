class Store {
  final String storeName;
  final String address;
  final String phoneNumber;
  final String industry;
  final String menu1;
  final String price1;
  final double latitude;
  final double longitude;

  Store({
    required this.storeName,
    required this.address,
    required this.phoneNumber,
    required this.industry,
    required this.menu1,
    required this.price1,
    required this.latitude,
    required this.longitude,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeName: json['storeName'] ?? '이름 없음',
      address: json['address'] ?? '주소 정보 없음',
      phoneNumber: json['phoneNumber'] ?? '전화번호 없음',
      industry: json['industry'] ?? '기타',
      menu1: json['menu1'] ?? '',
      price1: json['price1'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

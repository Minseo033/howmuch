class Store {
  final String storeName;
  final String address;
  final String phoneNumber;
  final String industry;
  final String menu1;
  final String price1;
  final String menu2;
  final String price2;
  final String menu3;
  final String price3;
  final String menu4;
  final String price4;
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
    required this.menu2,
    required this.price2,
    required this.menu3,
    required this.price3,
    required this.menu4,
    required this.price4,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeName: json['storeName']?.toString() ?? '이름 없음',
      address: json['address']?.toString() ?? '주소 정보 없음',
      phoneNumber: json['phoneNumber']?.toString() ?? '전화번호 없음',
      industry: json['industry']?.toString() ?? '기타',
      menu1: json['menu1']?.toString() ?? '',
      price1: json['price1']?.toString() ?? '',
      menu2: json['menu2']?.toString() ?? '',
      price2: json['price2']?.toString() ?? '',
      menu3: json['menu3']?.toString() ?? '',
      price3: json['price3']?.toString() ?? '',
      menu4: json['menu4']?.toString() ?? '',
      price4: json['price4']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] ?? 'GOV',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeName': storeName,
      'address': address,
      'phoneNumber': phoneNumber,
      'industry': industry,
      'menu1': menu1,
      'price1': price1,
      'menu2': menu2,
      'price2': price2,
      'menu3': menu3,
      'price3': price3,
      'menu4': menu4,
      'price4': price4,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
    };
  }
}

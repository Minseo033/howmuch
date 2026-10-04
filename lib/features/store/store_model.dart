import 'package:howmuch/features/store/store_hours.dart';

class Store {
  final String id;
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
  final bool free1;
  final bool free2;
  final bool free3;
  final bool free4;
  final bool isClosed;
  final int correctionRevision;
  final double latitude;
  final double longitude;
  final String source; // 💡 GOV 또는 USER
  final StoreHours? openingHours;

  bool get isUserReported => source.trim().toUpperCase() == 'USER';

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude != 0 &&
      longitude != 0 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  Store({
    this.id = '',
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
    this.free1 = false,
    this.free2 = false,
    this.free3 = false,
    this.free4 = false,
    this.isClosed = false,
    this.correctionRevision = 0,
    this.openingHours,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['storeId']?.toString() ?? json['id']?.toString() ?? '',
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
      free1: json['free1'] == true,
      free2: json['free2'] == true,
      free3: json['free3'] == true,
      free4: json['free4'] == true,
      isClosed: json['isClosed'] == true,
      correctionRevision: int.tryParse('${json['correctionRevision']}') ?? 0,
      latitude: _coordinate(json['latitude']),
      longitude: _coordinate(json['longitude']),
      source: _source(json['source']),
      openingHours: StoreHours.tryParse(json['openingHours']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': id,
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
      'free1': free1,
      'free2': free2,
      'free3': free3,
      'free4': free4,
      'isClosed': isClosed,
      'correctionRevision': correctionRevision,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
      if (openingHours != null) 'openingHours': openingHours!.toJson(),
    };
  }

  String menuAt(int slot) => [menu1, menu2, menu3, menu4][slot - 1];
  String priceAt(int slot) => [price1, price2, price3, price4][slot - 1];
  bool freeAt(int slot) => [free1, free2, free3, free4][slot - 1];

  static double _coordinate(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static String _source(Object? value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    return normalized.isEmpty ? 'GOV' : normalized;
  }
}

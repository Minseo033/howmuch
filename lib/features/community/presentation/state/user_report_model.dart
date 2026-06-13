class UserReport {
  final String cityProvince;
  final String cityDistrict;
  final String industry;
  final String storeName;
  final String phoneNumber;
  final String address;
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
  final List<String> imageUrls;
  final String reporterId;
  final bool visitedRecently;
  final bool checkedMenuPrice;

  UserReport({
    this.cityProvince = '',
    this.cityDistrict = '',
    required this.industry,
    required this.storeName,
    this.phoneNumber = '',
    required this.address,
    this.menu1 = '',
    this.price1 = '',
    this.menu2 = '',
    this.price2 = '',
    this.menu3 = '',
    this.price3 = '',
    this.menu4 = '',
    this.price4 = '',
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.reporterId,
    required this.visitedRecently,
    required this.checkedMenuPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'cityProvince': cityProvince,
      'cityDistrict': cityDistrict,
      'industry': industry,
      'storeName': storeName,
      'phoneNumber': phoneNumber,
      'address': address,
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
      'imageUrls': imageUrls,
      'reporterId': reporterId,
      'visitedRecently': visitedRecently,
      'checkedMenuPrice': checkedMenuPrice,
    };
  }
}

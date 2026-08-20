import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  test('parses numeric coordinate strings from API responses', () {
    final store = Store.fromJson({
      'storeName': '좌표 매장',
      'latitude': '37.5665',
      'longitude': '126.9780',
    });

    expect(store.latitude, 37.5665);
    expect(store.longitude, 126.9780);
    expect(store.hasValidCoordinates, isTrue);
  });

  test('rejects zero, non-finite, and out-of-range map coordinates', () {
    expect(_store(latitude: 0, longitude: 127).hasValidCoordinates, isFalse);
    expect(_store(latitude: 37, longitude: 181).hasValidCoordinates, isFalse);
    expect(
      _store(latitude: double.nan, longitude: 127).hasValidCoordinates,
      isFalse,
    );
    expect(_store(latitude: 37, longitude: 127).hasValidCoordinates, isTrue);
  });
}

Store _store({required double latitude, required double longitude}) {
  return Store(
    storeName: '매장',
    address: '',
    phoneNumber: '',
    industry: '',
    menu1: '',
    price1: '',
    menu2: '',
    price2: '',
    menu3: '',
    price3: '',
    menu4: '',
    price4: '',
    latitude: latitude,
    longitude: longitude,
    source: 'GOV',
  );
}

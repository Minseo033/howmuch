import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/search/presentation/state/search_filter_policy.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  Store store(String name, String price) => Store.fromJson({
    'storeName': name,
    'price1': price,
    'latitude': 37.5,
    'longitude': 127.0,
  });

  test('가격 상한 필터는 가격 정보가 없는 매장을 제외한다', () {
    expect(
      SearchFilterPolicy.matchesMaxPrice(store('저가', '4,900원'), 5000),
      isTrue,
    );
    expect(
      SearchFilterPolicy.matchesMaxPrice(store('고가', '5,100원'), 5000),
      isFalse,
    );
    expect(
      SearchFilterPolicy.matchesMaxPrice(store('미상', '가격정보 없음'), 5000),
      isFalse,
    );
  });

  test('저렴한순 정렬은 유효 가격을 앞에 두고 가격 미상은 마지막에 둔다', () {
    final stores = [
      store('미상', ''),
      store('비쌈', '12,000원'),
      store('저렴', '3,000원'),
    ]..sort(SearchFilterPolicy.compareByPrice);

    expect(stores.map((item) => item.storeName), ['저렴', '비쌈', '미상']);
  });

  test('여러 가격이 들어온 공공데이터는 첫 대표 가격만 사용한다', () {
    expect(SearchFilterPolicy.parsePrice('일반: 10,000원 / 노인: 8,000원'), 10000);
  });

  test('메뉴 검색 가격 필터는 검색된 보조 메뉴 가격으로 판단한다', () {
    final store = Store.fromJson({
      'storeName': '도널드분식',
      'menu1': '김밥',
      'price1': '2,000원',
      'menu2': '김치찌개',
      'price2': '6,500원',
      'latitude': 37.5,
      'longitude': 127.0,
    });

    expect(
      SearchFilterPolicy.matchesMaxPrice(store, 5000, query: '김치찌개'),
      isFalse,
    );
    expect(SearchFilterPolicy.matchesMaxPrice(store, 5000), isTrue);
    expect(SearchFilterPolicy.displayMenuFor(store, '김치찌개'), (
      name: '김치찌개',
      price: '6,500원',
      index: 2,
    ));
  });

  test('저렴한순은 검색된 메뉴 가격으로 정렬한다', () {
    final secondaryMenuMatch = Store.fromJson({
      'storeName': '첫 가격만 저렴한 매장',
      'menu1': '김밥',
      'price1': '2,000원',
      'menu2': '김치찌개',
      'price2': '6,500원',
      'latitude': 37.5,
      'longitude': 127.0,
    });
    final affordableMatch = Store.fromJson({
      'storeName': '실제 저렴한 매장',
      'menu1': '김치찌개',
      'price1': '4,000원',
      'latitude': 37.5,
      'longitude': 127.0,
    });

    final stores = [secondaryMenuMatch, affordableMatch]
      ..sort((a, b) => SearchFilterPolicy.compareByPrice(a, b, query: '김치찌개'));

    expect(stores.map((item) => item.storeName), ['실제 저렴한 매장', '첫 가격만 저렴한 매장']);
  });

  test('여러 메뉴가 검색되면 카드와 필터는 첫 검색 일치 메뉴를 함께 쓴다', () {
    final store = Store.fromJson({
      'storeName': '두 김치 식당',
      'menu1': '김치찌개',
      'price1': '9,000원',
      'menu2': '김치볶음밥',
      'price2': '4,000원',
      'latitude': 37.5,
      'longitude': 127.0,
    });

    expect(SearchFilterPolicy.displayMenuFor(store, '김치'), (
      name: '김치찌개',
      price: '9,000원',
      index: 1,
    ));
    expect(
      SearchFilterPolicy.matchesMaxPrice(store, 5000, query: '김치'),
      isFalse,
    );
  });

  test('가게명·빈 검색은 기존처럼 최저 유효 메뉴 가격을 쓴다', () {
    final store = Store.fromJson({
      'storeName': '가격 식당',
      'menu1': '대표 메뉴',
      'price1': '12,000원',
      'menu2': '저렴한 메뉴',
      'price2': '5,000원',
      'latitude': 37.5,
      'longitude': 127.0,
    });

    expect(SearchFilterPolicy.displayMenuFor(store, '가격 식당'), (
      name: '저렴한 메뉴',
      price: '5,000원',
      index: 2,
    ));
    expect(SearchFilterPolicy.displayMenuFor(store, ''), (
      name: '저렴한 메뉴',
      price: '5,000원',
      index: 2,
    ));
    expect(
      SearchFilterPolicy.matchesMaxPrice(store, 5000, query: '가격 식당'),
      isTrue,
    );
  });
}

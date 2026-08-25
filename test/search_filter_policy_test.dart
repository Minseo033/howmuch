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
}

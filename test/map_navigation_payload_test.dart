import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_approved_tab.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';

void main() {
  test('검색 지도 이동은 기존 viewport와 무관한 실제 결과·필터와 위치 없는 결과도 보존한다', () {
    final stores = [
      Store.fromJson({
        'storeId': 'search-1',
        'storeName': '검색 매장',
        'latitude': 37.51,
        'longitude': 127.1,
      }),
      Store.fromJson({'storeId': 'search-2', 'storeName': '위치 없는 매장'}),
    ];
    const filter = SearchFilter(maxPrice: 5000);
    final result = buildSearchMapResult(
      query: '검색',
      filter: filter,
      stores: stores,
    );
    expect(result['storeIds'], ['search-1', 'search-2']);
    expect(result['query'], '검색');
    expect(result['filter'], same(filter));
    stores.clear();
    expect((result['stores'] as List<Store>).length, 2);
    final cleared = buildSearchMapResult(
      query: '검색',
      filter: filter,
      stores: const [],
      clear: true,
    );
    expect(cleared['stores'], isNull);
    expect(cleared['query'], '');
  });
  test('승인 제보의 좌표와 매장 ID를 지도 이동 데이터로 전달한다', () {
    final report = UserReportStatus.fromJson({
      'id': 'report-1',
      'storeId': 'store-1',
      'storeName': '동양미래대학교 학식당',
      'address': '서울 구로구',
      'industry': '한식',
      'menu1': '한식',
      'price1': '6500',
      'latitude': 37.5001,
      'longitude': 126.8672,
      'status': 'APPROVED',
    });

    final result = buildApprovedReportMapResult(report);

    expect(result.storeIds, ['store-1']);
    expect(result.stores.single.storeName, '동양미래대학교 학식당');
    expect(result.stores.single.latitude, 37.5001);
    expect(result.stores.single.hasValidCoordinates, isTrue);
  });

  test('오늘의 픽은 좌표가 유효한 매장만 지도에 전달한다', () {
    final validStore = Store.fromJson({
      'storeId': 'store-2',
      'storeName': '착한식당',
      'latitude': 37.51,
      'longitude': 126.88,
    });
    final invalidStore = Store.fromJson({
      'storeId': 'store-3',
      'storeName': '좌표 없는 매장',
    });
    TodaysPickItem item(Store store) => TodaysPickItem(
      id: store.id,
      storeName: store.storeName,
      menuName: '비빔국수',
      price: '4,000원',
      priceValue: 4000,
      tipText: '',
      distance: '100m',
      badgeText: '착한가격업소',
      badgeColor: Colors.blue,
      badgeBg: Colors.blueAccent,
      tags: const [],
      store: store,
    );

    final result = buildTodaysPickMapResult([
      item(validStore),
      item(invalidStore),
    ]);

    expect(result.storeIds, ['store-2']);
    expect(result.stores, [validStore]);
    expect(result.selectionFor(validStore)!.menu, '비빔국수');
    expect(result.selectionFor(validStore)!.price, '4,000원');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  tearDown(() {
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.setMapStores(const []);
  });

  test('favorite detail resolves to the richer loaded store model', () {
    final catalogStore = Store(
      id: 'store-1',
      storeName: '시장국수',
      address: '서울시 중구 1',
      phoneNumber: '02-1234-5678',
      industry: '한식',
      menu1: '잔치국수',
      price1: '5000',
      menu2: '',
      price2: '',
      menu3: '',
      price3: '',
      menu4: '',
      price4: '',
      latitude: 37.56,
      longitude: 126.98,
      source: 'GOV',
    );
    HomeMapScreen.setSearchCatalog([catalogStore]);

    final favorite = FavoriteStoreModel.fromJson({
      'storeId': 'store-1',
      'storeName': '시장국수',
    });

    final resolved = resolveFavoriteStore(favorite);
    expect(resolved, same(catalogStore));
    expect(resolved.hasValidCoordinates, isTrue);
    expect(resolved.phoneNumber, '02-1234-5678');
  });

  test(
    'favorite detail fallback remains navigable without fake coordinates',
    () {
      final favorite = FavoriteStoreModel.fromJson({
        'storeId': 'legacy-1',
        'storeName': '동네식당',
        'address': '주소 없음',
      });

      final resolved = resolveFavoriteStore(favorite);
      expect(resolved.storeName, '동네식당');
      expect(resolved.address, '주소 없음');
      expect(resolved.hasValidCoordinates, isFalse);
      expect(resolved.source, 'UNKNOWN');
    },
  );

  test(
    'favorite detail uses API-enriched coordinates without home catalog',
    () {
      final favorite = FavoriteStoreModel.fromJson({
        'storeId': 'user-store-1',
        'storeName': '우리 동네 제보 카페',
        'industry': '카페·디저트',
        'address': '인천시 구로구 1',
        'phoneNumber': '02-555-1234',
        'menu1': '아메리카노',
        'price1': '2500',
        'menu2': '카페라떼',
        'price2': '3500',
        'latitude': 37.5665,
        'longitude': 126.9780,
        'source': 'USER',
      });

      final resolved = resolveFavoriteStore(favorite);

      expect(resolved.hasValidCoordinates, isTrue);
      expect(resolved.phoneNumber, '02-555-1234');
      expect(resolved.menu2, '카페라떼');
      expect(resolved.price2, '3500');
      expect(resolved.source, 'USER');
    },
  );

  test('legacy favorite never borrows a different branch location', () {
    HomeMapScreen.setSearchCatalog([
      for (final id in ['first', 'second'])
        Store.fromJson({
          'storeId': id,
          'storeName': '동명 식당',
          'address': '서로 다른 주소 $id',
          'latitude': 37.5,
          'longitude': 127.0,
        }),
    ]);
    final favorite = FavoriteStoreModel.fromJson({
      'storeId': 'legacy-id',
      'storeName': '동명 식당',
    });

    expect(resolveFavoriteStore(favorite).hasValidCoordinates, isFalse);
  });

  test('community gallery keeps all usable image URLs for paging', () {
    expect(
      communityPostImageUrls([
        'https://example.test/one.jpg',
        ' ',
        null,
        'https://example.test/two.jpg',
      ]),
      ['https://example.test/one.jpg', 'https://example.test/two.jpg'],
    );
    expect(communityPostImageUrls(null), isEmpty);
  });
}

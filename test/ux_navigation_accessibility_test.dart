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
    },
  );

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

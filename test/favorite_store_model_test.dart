import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

void main() {
  group('FavoriteStoreModel', () {
    FavoriteStoreModel parse(Map<String, dynamic> extra) =>
        FavoriteStoreModel.fromJson({
          'storeId': 'gov-1',
          'storeName': '착한분식',
          'industry': '분식',
          'menu1': '김밥',
          ...extra,
        });

    test('keeps multi-price and range prices instead of gluing digits', () {
      expect(parse({'price1': '3,000 / 3,500'}).price, '3,000 / 3,500원');
      expect(parse({'price1': '3.5~4만원'}).price, '3.5~4만원');
      expect(parse({'price1': '5000'}).price, '5,000원');
    });

    test('shows free menus as free and leaves missing prices blank', () {
      expect(parse({'price1': '0', 'free1': true}).price, '무료');
      expect(parse({}).price, isEmpty);
    });

    test('detail fallback keeps free, closed and revision facts', () {
      final store = parse({
        'price1': '0',
        'free1': true,
        'free3': true,
        'isClosed': true,
        'correctionRevision': 4,
      }).copyWith(isFavorite: false).toStore();

      expect(store.free1, isTrue);
      expect(store.free2, isFalse);
      expect(store.free3, isTrue);
      expect(store.isClosed, isTrue);
      expect(store.correctionRevision, 4);
    });
  });
}

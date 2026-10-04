import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/store/review_model.dart';

void main() {
  test('legacy stores never infer explicit free from zero', () {
    final store = Store.fromJson({'storeId': 'gov-1', 'price1': '0'});
    expect(store.free1, isFalse);
    expect(store.isClosed, isFalse);
    expect(store.correctionRevision, 0);
  });

  test('canonical fields survive navigation serialization', () {
    final store = Store.fromJson({
      'storeId': 'gov-1',
      'source': 'GOV',
      'menu1': '무료 서비스',
      'price1': '0',
      'free1': true,
      'isClosed': true,
      'correctionRevision': 3,
    });
    final copy = Store.fromJson(store.toJson());
    expect(copy.freeAt(1), isTrue);
    expect(copy.priceAt(1), '0');
    expect(copy.isClosed, isTrue);
    expect(copy.source, 'GOV');
    expect(copy.correctionRevision, 3);
  });

  test('my reviews preserve real source or unknown, not inferred USER', () {
    expect(Review.fromJson({'storeSource': 'GOV'}).storeSource, 'GOV');
    expect(Review.fromJson({}).storeSource, 'UNKNOWN');
    expect(Review.fromJson({'price': '3000 / 3500'}).price, isNull);
    expect(Review.fromJson({'price': '3,000원'}).price, 3000);
  });
}

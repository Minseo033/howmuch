import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/store_hours.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  final hours = {
    'status': 'SOURCE_VERIFIED',
    'text': '18:00~익일 02:00\n월요일 휴무',
    'sourceName': '행정안전부 착한가격업소',
    'sourceUrl': 'https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=104',
    'checkedAt': '2026-09-11',
    'parkingYn': false,
    'packingYn': false,
  };

  test('hours and evidence survive the store catalog cache round trip', () {
    final store = Store.fromJson({'openingHours': hours});
    final restored = Store.fromJson(store.toJson());
    expect(restored.openingHours?.text, '18:00~익일 02:00\n월요일 휴무');
    expect(restored.openingHours?.sourceLabel, contains('2026.09.11 자료 조회'));
    expect(restored.openingHours?.toJson(), hours);
    expect(Store.fromJson({}).openingHours, isNull);
  });

  test(
    'unreviewed or malformed hours do not break an otherwise valid store',
    () {
      for (final invalid in [
        '09:00~21:00',
        {...hours, 'status': 'SOURCE_MATCHED'},
        {...hours, 'text': ''},
        {...hours, 'sourceUrl': 'javascript:alert(1)'},
        {...hours, 'checkedAt': '2026-02-30'},
      ]) {
        expect(
          Store.fromJson({
            'openingHours': invalid,
            'storeName': '정상 매장',
          }).openingHours,
          isNull,
        );
      }
    },
  );

  test('old source checks are flagged after 90 Korean calendar days', () {
    final parsed = StoreHours.tryParse(hours)!;
    expect(parsed.isStale(DateTime.utc(2026, 12, 10, 14)), isFalse);
    expect(parsed.isStale(DateTime.utc(2026, 12, 10, 15)), isTrue);
  });
}

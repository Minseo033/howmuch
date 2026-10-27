import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_detail_screen.dart';

void main() {
  group('찜한 매장 정렬', () {
    test('최근 추가순은 최신 항목을 먼저 배치한다', () {
      final stores = [
        _favorite('오래된 매장', DateTime(2026, 8, 1)),
        _favorite('새 매장', DateTime(2026, 9, 1)),
      ];

      sortFavoriteStores(stores, FavoriteStoreSort.recent);

      expect(stores.map((store) => store.storeName), ['새 매장', '오래된 매장']);
    });

    test('매장 이름순은 한글 이름 기준 오름차순으로 배치한다', () {
      final stores = [
        _favorite('하늘식당', DateTime(2026, 8, 1)),
        _favorite('가온카페', DateTime(2026, 9, 1)),
      ];

      sortFavoriteStores(stores, FavoriteStoreSort.name);

      expect(stores.map((store) => store.storeName), ['가온카페', '하늘식당']);
    });
  });

  group('절약 내역 카테고리 정규화', () {
    test('운영 업종명을 화면 필터 카테고리로 변환한다', () {
      expect(normalizeSavingsCategory('한식 일반음식점'), '음식점');
      expect(normalizeSavingsCategory('커피전문점/카페'), '카페');
      expect(normalizeSavingsCategory('미용업'), '미용');
      expect(normalizeSavingsCategory('세탁업'), '기타');
      expect(normalizeSavingsCategory(null), '기타');
    });

    test('공공데이터의 모든 업종이 의도한 카테고리로 묶인다', () {
      // stores-snapshot.json의 업종 11가지 (기타요식업 921곳, 일식 202곳 포함)
      const expected = {
        '한식': '음식점',
        '중식': '음식점',
        '양식': '음식점',
        '일식': '음식점',
        '기타요식업': '음식점',
        '미용업': '미용',
        '이용업': '미용',
        '세탁업': '기타',
        '숙박업': '기타',
        '목욕업': '기타',
        '기타비요식업': '기타',
      };
      for (final entry in expected.entries) {
        expect(
          normalizeSavingsCategory(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
      expect(normalizeSavingsCategory('제과점'), '카페');
    });
  });
}

FavoriteStoreModel _favorite(String name, DateTime createdAt) {
  return FavoriteStoreModel.fromJson({
    'storeId': name,
    'storeName': name,
    'createdAt': createdAt.toIso8601String(),
  });
}

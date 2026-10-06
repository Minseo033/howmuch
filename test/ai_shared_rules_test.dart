import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';

/// Shared table with GeminiService.requestedBudgetWon / menuMatchesIntent.
/// When a server rule changes, update the Dart mirror and this table together.
void main() {
  test('budget expressions are read exactly like the server', () {
    const table = <String, int?>{
      '무료 메뉴 있는 곳': 0,
      '1만 5천원 이하': 15000,
      '1만원 이하로 추천해줘': 10000,
      '1.5만원 안쪽': 15000,
      '오만원으로 둘이': 50000,
      '이만원 넘지 않게': 20000,
      '만원 이하 점심': 10000,
      '8천원 안쪽 두 곳': 8000,
      '천원짜리 간식': 1000,
      '가격은 12,000원까지': 12000,
      '10,000원 이하 점심': 10000,
      '500원 커피': 500,
      '예산 상관없어': null,
    };
    for (final entry in table.entries) {
      expect(parseRequestedBudgetWon(entry.key), entry.value, reason: entry.key);
    }
  });

  test('menu intent follows the server rules', () {
    const table = <(String, String, String), bool>{
      // The default quick prompt keeps noodle soups and stews, like the server.
      ('칼국수', '혼밥 분식 추천', '한식'): true,
      ('김치찌개', '혼밥 분식 추천', '한식'): true,
      ('바지락칼국수', '비 오는 날 국물', '한식'): true,
      ('김밥', '비 오는 날 국물', '분식'): false,
      ('비빔국수', '비 오는 날 국물', '한식'): false,
      ('짜장면', '칼국수 추천', '중식'): false,
      ('아메리카노', '점심 후 커피', '카페'): true,
      ('칼국수', '점심 후 커피', '한식'): false,
      ('유자차', '점심 추천', '카페'): false,
      ('메가리카노', '저녁 식사', '음식점 · 카페'): false,
      ('샌드위치', '점심 추천', '카페'): true,
      ('커트', '점심 추천', '미용'): false,
      ('커트', '미용실 추천', '미용'): true,
      ('드라이클리닝', '미용 추천', '세탁'): false,
    };
    for (final entry in table.entries) {
      final (menu, query, industry) = entry.key;
      expect(
        menuMatchesRecommendationQuery(menu, query, industry: industry),
        entry.value,
        reason: '$query → $menu',
      );
    }
  });

  test('soup requests exclude cold bean noodles and sweet-and-sour pork', () {
    // FE-STORE-12: GeminiService.menuMatchesIntent needs the same exclusions.
    expect(menuMatchesRecommendationQuery('콩국수', '비 오는 날 국물'), isFalse);
    expect(menuMatchesRecommendationQuery('탕수육', '뜨끈한 국물'), isFalse);
    expect(menuMatchesRecommendationQuery('갈비탕', '뜨끈한 국물'), isTrue);
  });

  group('server-verified chat recommendations', () {
    final noodleShop = Store(
      id: 'noodle',
      storeName: '손칼국수',
      address: '서울 중구',
      phoneNumber: '',
      industry: '한식',
      menu1: '칼국수',
      price1: '12000',
      menu2: '',
      price2: '',
      menu3: '',
      price3: '',
      menu4: '',
      price4: '',
      latitude: 37.5665,
      longitude: 126.978,
      source: 'GOV',
    );

    VerifiedAiRecommendation verified({
      String price = '12000',
      double distance = 120,
    }) => VerifiedAiRecommendation.fromJson({
      'storeId': 'noodle',
      'storeName': '손칼국수',
      'matchedMenu': '칼국수',
      'menuIndex': 1,
      'rawPrice': price,
      'distanceMeters': distance,
      'source': 'GOV',
    })!;

    test('are not filtered again by the app\'s own intent or budget', () {
      // The server accepted 칼국수 for "혼밥 분식 추천" with a 15,000원 budget;
      // the old app rules dropped it (분식 category, budget read as 5,000원).
      final cards = resolveVerifiedAiRecommendations(
        recommendations: [verified()],
        catalog: [noodleShop],
        latitude: 37.5665,
        longitude: 126.978,
        radiusMeters: 3000,
      );

      expect(cards.map((card) => card.store.id), ['noodle']);
      expect(cards.single.selection.menu, '칼국수');
    });

    test('still require the menu slot, coordinates and radius to match', () {
      expect(
        resolveVerifiedAiRecommendations(
          recommendations: [verified(price: '9000')],
          catalog: [noodleShop],
          latitude: 37.5665,
          longitude: 126.978,
          radiusMeters: 3000,
        ),
        isEmpty,
      );
      expect(
        resolveVerifiedAiRecommendations(
          recommendations: [verified(distance: 4200)],
          catalog: [noodleShop],
          latitude: 37.5665,
          longitude: 126.978,
          radiusMeters: 3000,
        ),
        isEmpty,
      );
      expect(
        resolveVerifiedAiRecommendations(
          recommendations: [verified()],
          catalog: [noodleShop],
          latitude: 37.62,
          longitude: 126.978,
          radiusMeters: 3000,
        ),
        isEmpty,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';

Store store(
  String id,
  String menu,
  String price,
  double latitude, {
  bool free = false,
}) => Store(
  id: id,
  storeName: id,
  address: '테스트 주소',
  phoneNumber: '',
  industry: '한식',
  menu1: menu,
  price1: price,
  free1: free,
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: latitude,
  longitude: 127,
  source: 'GOV',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('radius validates integer km boundaries', () {
    for (final value in [1000, 3000, 15000]) {
      expect(validRecommendationRadius(value), isTrue);
    }
    for (final value in [0, 999, 1500, 16000]) {
      expect(validRecommendationRadius(value), isFalse);
    }
  });
  test('saved radius is isolated by account and survives re-entry', () async {
    SharedPreferences.setMockInitialValues({});
    final a = RecommendationRadiusNotifier('a');
    await a.ready;
    expect(a.radiusMeters, 3000);
    expect(await a.setRadius(15000), isTrue);
    final b = RecommendationRadiusNotifier('b');
    await b.ready;
    expect(b.radiusMeters, 3000);
    final restored = RecommendationRadiusNotifier('a');
    await restored.ready;
    expect(restored.radiusMeters, 15000);
    a.dispose();
    b.dispose();
    restored.dispose();
  });
  test(
    'local fallback never fills soup recommendations with kimbap or far stores',
    () {
      final result = buildLocalAiFallbackResult(
        stores: [
          store('가까운 김밥', '김밥', '3000', 37.001),
          store('가까운 국수', '칼국수', '5000', 37.002),
          store('먼 국수', '칼국수', '4000', 37.10),
        ],
        query: '비 오는 날 국물 3곳',
        lat: 37,
        lng: 127,
      );
      expect(result!.stores.map((item) => item.id), ['가까운 국수']);
      expect(result.menuSelections.single.menu, '칼국수');
      expect(result.text, contains('부족해 먼 매장으로 채우지 않았어요'));
    },
  );
  test('radius 1, 3 and 15 km is respected by local recommendations', () {
    final samples = [
      store('near', '백반', '5000', 37.005),
      store('middle', '백반', '5000', 37.02),
      store('far', '백반', '5000', 37.1),
      store('outside', '백반', '5000', 37.2),
    ];
    for (final (radius, expected) in [
      (1000, ['near']),
      (3000, ['near', 'middle']),
      (15000, ['near', 'middle', 'far']),
    ]) {
      final result = buildLocalAiFallbackResult(
        stores: samples,
        query: '4곳',
        lat: 37,
        lng: 127,
        radiusMeters: radius,
      );
      expect(result!.stores.map((item) => item.id), expected);
    }
  });
  test('meal fallback excludes drinks while explicit coffee still works', () {
    for (final query in ['10,000원 이하 점심', '저녁 식사', '아침 추천']) {
      final result = buildLocalAiFallbackResult(
        stores: [
          store('drink', '아메리카노(HOT)', '1500', 37.001),
          store('latte', '카페라떼', '2000', 37.002),
          store('food', '샌드위치', '5000', 37.003),
        ],
        query: query,
        lat: 37,
        lng: 127,
      );
      expect(result!.stores.map((item) => item.id), ['food']);
    }
    expect(menuMatchesRecommendationQuery('아메리카노', '점심 후 커피'), isTrue);
    expect(menuMatchesRecommendationQuery('칼국수', '점심 후 커피'), isFalse);
    expect(menuMatchesRecommendationQuery('유자차', '점심 추천'), isFalse);
    expect(
      menuMatchesRecommendationQuery('커트', '점심 추천', industry: '미용'),
      isFalse,
    );
    expect(
      menuMatchesRecommendationQuery('샌드위치', '점심 추천', industry: '카페'),
      isTrue,
    );
  });
  test('ambiguous prices do not imply a fixed route total', () {
    expect(
      formatRecommendationTotal([
        {'menu1': '음식', 'price1': '3,000 / 3,500'},
      ]),
      '3,000원 ~ 3,500원 (예상)',
    );
    expect(
      formatRecommendationTotal([
        {'menu1': '음식', 'price1': '5000'},
        {'menu1': '음식', 'price1': ''},
      ]),
      '가격 확인 필요',
    );
    expect(
      formatRecommendationTotal([
        {'matchedMenu': '무료', 'matchedPrice': '0', 'matchedFree': true},
      ]),
      '0원 (표시 가격 합계)',
    );
    expect(formatRecommendationPrice('0'), '가격 확인 필요');
    expect(formatRecommendationPrice('0', free: true), '무료');
  });
  test(
    'unverified text and incomplete structured records cannot become map cards',
    () {
      expect(
        VerifiedAiRecommendation.fromJson({
          'storeName': '맛집',
          'matchedMenu': '김밥',
          'rawPrice': '3000',
          'distanceMeters': 100,
        }),
        isNull,
      );
      expect(
        VerifiedAiRecommendation.fromJson({
          'storeId': 'id',
          'storeName': '맛집',
          'matchedMenu': '김밥',
          'rawPrice': '0',
          'distanceMeters': 100,
        }),
        isNull,
      );
      final verified = VerifiedAiRecommendation.fromJson({
        'storeId': 'id',
        'storeName': '맛집',
        'matchedMenu': '칼국수',
        'rawPrice': '3,000 / 3,500',
        'distanceMeters': 100,
        'source': 'GOV',
      });
      expect(verified!.selection.price, '3,000 / 3,500');
      expect(
        verified.resolveStore([store('another-id', '김밥', '3000', 37)]),
        isNull,
      );
    },
  );
}

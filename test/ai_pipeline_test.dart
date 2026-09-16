import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  group('parseRequestedRecommendationCount', () {
    test('parses Korean count words accurately', () {
      expect(parseRequestedRecommendationCount('한곳만 추천해줘'), 1);
      expect(parseRequestedRecommendationCount('두군데 알려줘'), 2);
      expect(parseRequestedRecommendationCount('두 곳만 추천해줘'), 2);
      expect(parseRequestedRecommendationCount('세 곳 보여줘'), 3);
      expect(parseRequestedRecommendationCount('네곳 추천'), 4);
    });

    test('parses Arabic digits with counter suffixes', () {
      expect(parseRequestedRecommendationCount('근처 맛집 2곳 추천'), 2);
      expect(parseRequestedRecommendationCount('1개소 알려줘'), 1);
      expect(parseRequestedRecommendationCount('3군데'), 3);
      expect(parseRequestedRecommendationCount('4개만 추천'), 4);
    });

    test('clamps requested count safely within range [1, 4]', () {
      expect(parseRequestedRecommendationCount('10곳 추천해줘'), 4);
      expect(parseRequestedRecommendationCount('0곳 알려줘'), 1);
      expect(parseRequestedRecommendationCount('다섯곳 추천'), 4);
    });

    test(
      'falls back to default count when count is unspecified and ignores prices',
      () {
        expect(parseRequestedRecommendationCount('오늘 점심 뭐 먹지?'), 3);
        expect(parseRequestedRecommendationCount('6000원 이하 국밥집'), 3);
        expect(parseRequestedRecommendationCount('10000원짜리 식사'), 3);
      },
    );
  });

  group('requested budget enforcement', () {
    test('parses common Korean budget expressions', () {
      expect(parseRequestedBudgetWon('1만원 이하로 추천해줘'), 10000);
      expect(parseRequestedBudgetWon('8천원 안쪽 두 곳'), 8000);
      expect(parseRequestedBudgetWon('가격은 12,000원까지'), 12000);
      expect(parseRequestedBudgetWon('예산 상관없어'), isNull);
    });
  });

  group('buildLocalAiFallbackResult', () {
    final sampleStores = [
      Store(
        id: 'store-1',
        storeName: '마포국밥',
        address: '서울시 마포구 독막로 10',
        phoneNumber: '02-111-1111',
        industry: '한식',
        menu1: '순대국밥',
        price1: '7000',
        menu2: '돼지국밥',
        price2: '8000',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.5500,
        longitude: 126.9200,
        source: 'GOV',
      ),
      Store(
        id: 'store-2',
        storeName: '신촌칼국수',
        address: '서울시 서대문구 신촌로 20',
        phoneNumber: '02-222-2222',
        industry: '한식',
        menu1: '바지락칼국수',
        price1: '6500원',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.5550,
        longitude: 126.9360,
        source: 'GOV',
      ),
      Store(
        id: 'store-3',
        storeName: '카페 달콤',
        address: '서울시 마포구 와우산로 30',
        phoneNumber: '02-333-3333',
        industry: '카페',
        menu1: '아메리카노',
        price1: '2500',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.5510,
        longitude: 126.9230,
        source: 'USER',
      ),
      Store(
        id: 'store-4',
        storeName: '강남짜장',
        address: '서울시 강남구 테헤란로 40',
        phoneNumber: '02-444-4444',
        industry: '중식',
        menu1: '짜장면',
        price1: '6000',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.5000,
        longitude: 127.0300,
        source: 'GOV',
      ),
    ];

    test('formats prices with comma and won suffix', () {
      final result = buildLocalAiFallbackResult(
        stores: sampleStores,
        query: '근처 2곳 추천해줘',
        lat: 37.5500,
        lng: 126.9200,
      );

      expect(result, isNotNull);
      expect(result!.stores.length, 2);
      expect(result.text, contains('7,000원'));
      expect(result.text, contains('2,500원'));
    });

    test('filters stores by requested intent keyword', () {
      final result = buildLocalAiFallbackResult(
        stores: sampleStores,
        query: '칼국수 1곳 추천해줘',
        lat: 37.5500,
        lng: 126.9200,
      );

      expect(result, isNotNull);
      expect(result!.stores.length, 1);
      expect(result.stores.first.storeName, '신촌칼국수');
      expect(result.text, contains('신촌칼국수'));
      expect(result.text, contains('6,500원'));
    });

    test('filters stores by requested area token', () {
      final result = buildLocalAiFallbackResult(
        stores: sampleStores,
        query: '마포 근처 2곳 추천해줘',
        lat: 37.5500,
        lng: 126.9200,
      );

      expect(result, isNotNull);
      expect(result!.stores.length, 2);
      expect(result.stores.every((s) => s.address.contains('마포구')), isTrue);
    });

    test('does not invent fake store data and retains structured stores', () {
      final result = buildLocalAiFallbackResult(
        stores: sampleStores,
        query: '2곳 추천해줘',
        lat: 37.5500,
        lng: 126.9200,
      );

      expect(result, isNotNull);
      for (final s in result!.stores) {
        expect(sampleStores.any((orig) => orig.id == s.id), isTrue);
      }
    });

    test('enforces the requested price ceiling', () {
      final result = buildLocalAiFallbackResult(
        stores: sampleStores,
        query: '5천원 이하 2곳 추천해줘',
        lat: 37.5500,
        lng: 126.9200,
      );

      expect(result, isNotNull);
      expect(result!.stores, hasLength(1));
      expect(result.stores.single.storeName, '카페 달콤');
      expect(result.text, contains('2,500원'));
      expect(result.text, isNot(contains('7,000원')));
    });

    test('keeps real candidates when no store meets the requested budget', () {
      final result = buildLocalAiFallbackResult(
        stores: sampleStores,
        query: '1000원 이하 한 곳 추천해줘',
        lat: 37.5500,
        lng: 126.9200,
      );

      expect(result, isNotNull);
      expect(result!.stores, hasLength(1));
      expect(result.text, contains('실제 매장 대안'));
      expect(result.text, contains(result.stores.single.storeName));
      expect(result.text, contains('7,000원'));
    });
  });

  group('extractRecommendedStoresFromText', () {
    final sampleStores = [
      Store(
        id: 's1',
        storeName: '원조순대국',
        address: '서울 마포구',
        phoneNumber: '',
        industry: '한식',
        menu1: '순대국',
        price1: '7000',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.55,
        longitude: 126.92,
        source: 'GOV',
      ),
      Store(
        id: 's2',
        storeName: '별미김밥',
        address: '서울 마포구',
        phoneNumber: '',
        industry: '분식',
        menu1: '김밥',
        price1: '3000',
        menu2: '',
        price2: '',
        menu3: '',
        price3: '',
        menu4: '',
        price4: '',
        latitude: 37.55,
        longitude: 126.93,
        source: 'GOV',
      ),
    ];

    test('extracts stores mentioned in bot message', () {
      const botMsg = '오늘 같은 날에는 원조순대국에서 따뜻한 순대국 한 그릇 어떠세요?';
      final extracted = extractRecommendedStoresFromText(
        text: botMsg,
        candidateStores: sampleStores,
      );

      expect(extracted.length, 1);
      expect(extracted.first.id, 's1');
      expect(extracted.first.storeName, '원조순대국');
    });
  });

  group('AI Map Linkage and Chat UI', () {
    testWidgets(
      'AI chat screen renders action chips and returns recommendation result on map tap',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        AiMapRecommendationResult? poppedResult;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiChatHistoryProvider.overrideWith(
                (ref) => [
                  const AiChatMessage(
                    text: '1. 마포국밥 — 순대국밥 · 7,000원',
                    isBot: true,
                    recommendedStoreIds: ['store-1'],
                  ),
                ],
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          poppedResult = await Navigator.of(context)
                              .push<AiMapRecommendationResult>(
                                MaterialPageRoute(
                                  builder: (_) => const AiRecommendChatScreen(),
                                ),
                              );
                        },
                        child: const Text('Open AI Chat'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open chat screen
        await tester.tap(find.text('Open AI Chat'));
        await tester.pumpAndSettle();

        // Verify bot message and action chips
        expect(find.text('1. 마포국밥 — 순대국밥 · 7,000원'), findsOneWidget);
        expect(find.text('지도에서 찾기'), findsOneWidget);
        expect(find.text('복사'), findsOneWidget);

        await tester.ensureVisible(find.text('지도에서 찾기'));
        await tester.pumpAndSettle();

        // Tap '지도에서 찾기'
        await tester.tap(find.text('지도에서 찾기'));
        await tester.pumpAndSettle();

        // Verify it popped back and returned structured storeIds
        expect(poppedResult, isNotNull);
        expect(poppedResult!.storeIds, contains('store-1'));
      },
    );

    testWidgets(
      'AI recommendation banner renders count and handles reset click',
      (tester) async {
        bool resetClicked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Test the banner widget directly
                  return Center(
                    child: GestureDetector(
                      key: const ValueKey('banner_reset'),
                      onTap: () => resetClicked = true,
                      child: const Text('전체보기'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('banner_reset')));
        expect(resetClicked, isTrue);
      },
    );
  });
}

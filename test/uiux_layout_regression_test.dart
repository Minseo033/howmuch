import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/utils/price_formatter.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/search/presentation/screens/search_filter_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Store sampleStore(String price, {bool free = false}) => Store.fromJson({
  'id': 'layout-store',
  'storeName': '구백년짜장',
  'address': '서울시 중구',
  'industry': '중식',
  'menu1': '소고기 샤브 칼국수',
  'price1': price,
  'free1': free,
  'latitude': 37.56,
  'longitude': 126.98,
});

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

RenderParagraph paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 393.0]) {
    for (final price in ['5000', '3,000 / 3,500', '3000~5000', '0']) {
      testWidgets('search keeps full price $price at $width', (tester) async {
        viewport(tester, Size(width, 852));
        final store = sampleStore(price, free: price == '0');
        HomeMapScreen.setSearchCatalog([store]);
        addTearDown(() => HomeMapScreen.setSearchCatalog([]));
        await tester.pumpWidget(
          const MaterialApp(home: SearchResultScreen(initialQuery: '칼국수')),
        );
        await tester.pumpAndSettle();
        final text =
            '${formatMenuPrice(price, free: price == '0')}${parsePriceValue(price)?.isExact == false ? ' (최저가격 기준)' : ''}';
        final finder = find.text(text);
        expect(finder, findsOneWidget);
        expect(paragraph(tester, finder).didExceedMaxLines, isFalse);
        expect(
          tester.widget<Text>(finder).overflow,
          isNot(TextOverflow.ellipsis),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('map summary reserves full name and selected price at $width', (
      tester,
    ) async {
      viewport(tester, Size(width, 568));
      final store = sampleStore('10000');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width * .88,
                height: 158,
                child: HomeMapStoreSummaryCard(
                  store: store,
                  selection: const RecommendationMenuSelection(
                    storeId: 'layout-store',
                    storeName: '구백년짜장',
                    menu: '짜장면',
                    price: '3,000 / 3,500',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(paragraph(tester, find.text('구백년짜장')).didExceedMaxLines, isFalse);
      expect(find.text('짜장면'), findsOneWidget);
      expect(find.text(formatMenuPrice('3,000 / 3,500')), findsOneWidget);
      expect(find.text('10,000원'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('favorite saved state does not intersect removal at $width', (
      tester,
    ) async {
      viewport(tester, Size(width, 852));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteApiServiceProvider.overrideWithValue(_FavoriteApi()),
          ],
          child: const MaterialApp(home: FavoriteStoresScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final saved = tester.getRect(find.text('저장됨'));
      final remove = tester.getRect(find.widgetWithText(TextButton, '찜 해제'));
      expect(saved.overlaps(remove), isFalse);
      expect(remove.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filter reset label remains one line at 320', (tester) async {
    viewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SearchFilterSheet(current: SearchFilter())),
      ),
    );
    await tester.pumpAndSettle();
    final label = paragraph(tester, find.text('초기화'));
    expect(label.didExceedMaxLines, isFalse);
    expect(label.size.height, lessThan(30));
    await tester.tap(find.text('초기화'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI narrow heading and prompt use balanced full width', (
    tester,
  ) async {
    viewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AiRecommendChatScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('오늘은 뭘\n드시고 싶으세요?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('10,000원 이하 점심'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    final label = paragraph(tester, find.text('10,000원 이하 점심'));
    expect(label.didExceedMaxLines, isFalse);
    expect(label.size.height, lessThan(30));
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10,000원 이하 점심'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '10,000원 이하 점심',
    );
    expect(tester.takeException(), isNull);
  });
}

class _FavoriteApi extends FavoriteApiService {
  @override
  Future<List<FavoriteStoreModel>> fetchFavorites() async => [
    FavoriteStoreModel.fromJson({
      'storeId': 'layout-store',
      'storeName': '무한칼국수 송담점',
      'source': 'GOV',
      'menu1': '칼국수',
      'price1': '5000',
    }),
  ];
}

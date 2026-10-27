import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/store/store_model.dart';

const _longName = '청년밥상문간 이화여자대학교점';
const _shortName = '미락칼국수';

Store _store(String name) => Store.fromJson({
  'id': 'card-store',
  'storeName': name,
  'address': '서울특별시 서대문구 이화여대길 52',
  'industry': '한식',
  'menu1': '김치찌개',
  'price1': '3000',
  'latitude': 37.56,
  'longitude': 126.94,
});

Future<void> _pumpCard(
  WidgetTester tester,
  String name, {
  required double width,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 158,
                child: HomeMapStoreSummaryCard(store: _store(name)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

RenderParagraph _name(WidgetTester tester, String name) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(name), matching: find.byType(RichText)),
    );

void main() {
  // Card widths in the carousel on 375, 390 and 430 wide screens, and the
  // single card on a 400 wide screen.
  for (final width in [318.0, 331.0, 360.0, 366.0]) {
    testWidgets('a long store name shows its branch on a $width card', (
      tester,
    ) async {
      await _pumpCard(tester, _longName, width: width);
      final name = _name(tester, _longName);
      expect(name.didExceedMaxLines, isFalse, reason: 'no "이화여…" cut');
      expect(name.maxLines, 2);
      expect(find.text('3,000원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short store name keeps the one large line at $width', (
      tester,
    ) async {
      await _pumpCard(tester, _shortName, width: width);
      final name = _name(tester, _shortName);
      expect(name.maxLines, 1);
      expect(name.text.style?.fontSize, 18);
      expect(tester.takeException(), isNull);
    });

    testWidgets('slightly larger text keeps the card height at $width', (
      tester,
    ) async {
      // Two lines only when they fit; larger text keeps the single line.
      // (At 1.3 the price column already overflowed before this change.)
      await _pumpCard(tester, _longName, width: width, textScale: 1.1);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testStore = Store(
    id: 'store-korean',
    storeName: '어머니 손맛 식당',
    address: '서울특별시 서초구 서초대로 50',
    phoneNumber: '02-555-6666',
    industry: '한식',
    menu1: '순두부찌개',
    price1: '6000',
    menu2: '제육볶음',
    price2: '8000',
    menu3: '김치찌개',
    price3: '6500',
    menu4: '',
    price4: '',
    latitude: 37.49,
    longitude: 127.01,
    source: 'GOV',
  );

  testWidgets(
    'derives default menu from store registered menus and never uses generic 아메리카노',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PriceChangeReportScreen(
              store: testStore,
              storeName: testStore.storeName,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must NEVER display generic 아메리카노
      expect(find.text('아메리카노'), findsNothing);

      // Must initialize with the store's actual primary menu
      expect(find.text('순두부찌개'), findsWidgets);
      expect(find.text('대표 메뉴: 순두부찌개'), findsOneWidget);

      // Registered menu chips exist
      expect(
        find.byKey(const ValueKey('price-report-menu-chip-순두부찌개')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('price-report-menu-chip-제육볶음')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('price-report-menu-chip-김치찌개')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('price-report-manual-menu-chip')),
        findsOneWidget,
      );

      // Selecting a registered menu shows the old price but never copies it as the new price.
      await tester.tap(
        find.byKey(const ValueKey('price-report-menu-chip-제육볶음')),
      );
      await tester.pumpAndSettle();
      expect(find.text('기존 가격 8,000원'), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[1].controller!.text, isEmpty);

      // Tapping 직접 입력 clears the fields for safe manual input
      await tester.ensureVisible(
        find.byKey(const ValueKey('price-report-manual-menu-chip')),
      );
      await tester.tap(
        find.byKey(const ValueKey('price-report-manual-menu-chip')),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '순두부찌개'), findsNothing);
      expect(find.widgetWithText(TextField, '제육볶음'), findsNothing);

      // User can type custom menu manually
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '뚝배기 불고기');
      await tester.pumpAndSettle();
      expect(find.text('뚝배기 불고기'), findsOneWidget);
    },
  );

  testWidgets('switching to 신규 메뉴 clears default menu for blank manual path', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PriceChangeReportScreen(
            store: testStore,
            storeName: testStore.storeName,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially defaulted to 순두부찌개
    expect(find.widgetWithText(TextField, '순두부찌개'), findsOneWidget);

    // Tap 신규 메뉴
    await tester.tap(find.text('신규 메뉴'));
    await tester.pumpAndSettle();

    // The menu field is cleared so user can enter the new menu name safely
    expect(find.widgetWithText(TextField, '순두부찌개'), findsNothing);
    expect(find.text('아메리카노'), findsNothing);
  });

  test('price direction validation rejects unchanged and inverse values', () {
    final menus = [(menu: '김치찌개', price: '3,000원')];
    String? check(String type, String price) => validatePriceChange(
      changeType: type,
      menu: '김치찌개',
      price: price,
      registeredMenus: menus,
    );
    expect(check('rise', '3000'), contains('같아요'));
    expect(check('rise', '2500'), contains('가격 인하'));
    expect(check('drop', '3500'), contains('가격 인상'));
    expect(check('rise', '3500'), isNull);
    expect(check('drop', '2500'), isNull);
    expect(check('delete', ''), isNull);
    expect(
      validatePriceChange(
        changeType: 'new',
        menu: '새 메뉴',
        price: '4000',
        registeredMenus: menus,
      ),
      isNull,
    );
    expect(
      validatePriceChange(
        changeType: 'new',
        menu: '김치찌개',
        price: '4000',
        registeredMenus: menus,
      ),
      isNotNull,
    );
  });

  testWidgets('safely defaults to blank when store has no registered menus', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PriceChangeReportScreen(storeName: '메뉴 없는 식당'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아메리카노'), findsNothing);
    expect(find.text('메뉴 이름 직접 입력'), findsOneWidget);

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, '직접 입력 메뉴');
    await tester.pumpAndSettle();
    expect(find.text('직접 입력 메뉴'), findsOneWidget);
  });
}

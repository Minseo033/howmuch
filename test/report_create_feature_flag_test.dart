import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';

void main() {
  testWidgets(
    'shows report image upload in the default release configuration',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ReportCreateScreen())),
      );

      expect(find.text('사진 및 확인'), findsOneWidget);
      expect(find.text('메뉴판 사진 첨부'), findsOneWidget);
    },
  );

  testWidgets('searches and selects a report address', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReportCreateScreen(
            addressSearch: (query) async => [
              if (query == '테헤란로') '서울 강남구 테헤란로 123',
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('주소 검색'));
    await tester.pumpAndSettle();

    expect(find.text('두 글자 이상 입력하면 주소를 찾아드려요.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('report-address-search-input')),
      '테헤란로',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('서울 강남구 테헤란로 123'));
    await tester.pumpAndSettle();

    expect(find.text('서울 강남구 테헤란로 123'), findsOneWidget);
  });
}

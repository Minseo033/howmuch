import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';

void main() {
  testWidgets(
    'shows report image upload in the default release configuration',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ReportCreateScreen())),
      );

      expect(find.text('사진 및 확인'), findsOneWidget);
      expect(find.text('메뉴판 사진 첨부'), findsOneWidget);
      expect(find.text('매장명 *'), findsOneWidget);
      expect(find.text('업종 *'), findsOneWidget);
      expect(find.text('주소 *'), findsOneWidget);
      expect(find.text('대표 메뉴 *'), findsOneWidget);
      expect(find.text('가격 *'), findsOneWidget);
      final storeLabel = tester.widget<Text>(find.text('매장명 *'));
      final labelSpan = storeLabel.textSpan! as TextSpan;
      final requiredSpan = labelSpan.children!.last as TextSpan;
      expect(requiredSpan.style?.color, const Color(0xFFF97316));
    },
  );

  testWidgets('searches and selects a report address', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReportCreateScreen(
            locationLookup: () async => (latitude: 37.5, longitude: 127.0),
            placeSearch: (query, latitude, longitude) async => [
              if (query == '롯데리아')
                const ReportPlaceSuggestion(
                  name: '롯데리아 역삼점',
                  address: '서울 강남구 테헤란로 123',
                  distanceMeters: 418,
                ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('주소 검색'));
    await tester.pumpAndSettle();

    expect(find.text('현재 위치에서 가까운 순으로 보여드려요.'), findsOneWidget);
    expect(find.text('두 글자 이상 입력하면 매장과 주소를 찾아드려요.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('report-address-search-input')),
      '롯데리아',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('418m'), findsOneWidget);
    await tester.tap(find.text('롯데리아 역삼점'));
    await tester.pumpAndSettle();

    expect(find.text('롯데리아 역삼점'), findsOneWidget);
    expect(find.text('서울 강남구 테헤란로 123'), findsOneWidget);
  });
}

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
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('대표 메뉴, 필수 입력'), findsOneWidget);
      expect(find.bySemanticsLabel('가격, 필수 입력'), findsOneWidget);
      semantics.dispose();
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
                  category: '음식점 > 패스트푸드 > 햄버거',
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
    expect(find.text('음식점 · 패스트푸드'), findsOneWidget);
  });

  testWidgets('keeps the place category hidden in search results', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReportCreateScreen(
            locationLookup: () async => null,
            placeSearch: (query, latitude, longitude) async => const [
              ReportPlaceSuggestion(
                name: '동네 카페',
                address: '서울 구로구 중앙로 1',
                category: '음식점 > 카페 > 커피전문점',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('매장 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('report-address-search-input')),
      '동네 카페',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final resultTitle = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('동네 카페'),
    );
    expect(resultTitle, findsOneWidget);
    expect(find.text('서울 구로구 중앙로 1'), findsOneWidget);
    expect(find.text('음식점 > 카페 > 커피전문점'), findsNothing);

    await tester.tap(resultTitle);
    await tester.pumpAndSettle();
    expect(find.text('카페·디저트 · 카페·커피'), findsOneWidget);
  });

  testWidgets('offers and selects detailed report industries', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportCreateScreen())),
    );
    await tester.tap(find.byTooltip('업종 선택'));
    await tester.pumpAndSettle();

    expect(find.text('음식점 · 한식'), findsOneWidget);
    final categoryList = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('카페·디저트 · 카페·커피'),
      180,
      scrollable: categoryList,
    );
    expect(find.text('카페·디저트 · 카페·커피'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('숙박 · 호텔·모텔'),
      220,
      scrollable: categoryList,
    );
    await tester.tap(find.text('숙박 · 호텔·모텔'));
    await tester.pumpAndSettle();

    expect(find.text('숙박 · 호텔·모텔'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('normalizes detailed Kakao and operating industries', () {
    expect(normalizeReportIndustry('음식점 > 한식 > 육류, 고기요리'), '음식점 · 고기·구이');
    expect(normalizeReportIndustry('음식점 > 카페 > 제과,베이커리'), '카페·디저트 · 베이커리');
    expect(normalizeReportIndustry('미용업'), '생활서비스 · 미용실');
    expect(normalizeReportIndustry('세탁업'), '생활서비스 · 세탁소');
    expect(
      normalizeReportIndustry('교통시설 > 주차장', placeName: '동양미래대학 주차장'),
      '교통·주차 · 주차장',
    );
    expect(normalizeReportIndustry('대중교통 > 택시'), '교통·주차 · 교통서비스');
    expect(normalizeReportIndustry(''), isNull);
  });
}

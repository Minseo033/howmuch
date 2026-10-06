import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/search/presentation/screens/search_filter_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_approved_tab.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_v2_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

void main() {
  test('menu count guard rejects overflow instead of truncating', () {
    expect(validateReportMenuCount(0), isNotNull);
    for (var count = 1; count <= 4; count++) {
      expect(validateReportMenuCount(count), isNull);
    }
    expect(validateReportMenuCount(5), contains('최대 4개'));
  });

  final noChange = UserReportStatus.fromJson({
    'id': 'qa-info',
    'storeId': 'original',
    'storeName': '기존 매장',
    'status': 'APPROVED',
    'reportType': 'STORE_INFO',
    'changeType': 'other',
    'description': '수정 요청 없음',
    'resolution': 'NO_CHANGE',
    'latitude': 37.5,
    'longitude': 127.0,
    'menu1': '국수',
    'price1': '5000',
    'menu2': '음료',
    'price2': '0',
    'free2': true,
  });

  test('approved map payload preserves secondary menus and free flag', () {
    final result = buildApprovedReportMapResult(noChange);
    expect(result.stores.single.menu2, '음료');
    expect(result.stores.single.free2, isTrue);
    expect(result.stores.single.source, 'UNKNOWN');
  });

  testWidgets(
    'NO_CHANGE does not claim map application or allow approved editing',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReportDetailV2Screen(initialReport: noChange),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('수정 요청 없음'), findsOneWidget);
      expect(find.text('검토 완료 · 수정 없음'), findsWidgets);
      expect(find.text('지도 반영'), findsNothing);
      expect(find.text('현재 가격과 위치 정보를 확인하고 있어요.'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('approved list also labels NO_CHANGE without claiming a new store', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userReportsProvider.notifier).setReports([noChange]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: Scaffold(body: MyReportsApprovedTab()))));
    await tester.pumpAndSettle();
    expect(find.text('검토 완료 · 수정 없음'), findsOneWidget);
    expect(find.text('지도에 사용자 제보 매장으로 표시 중'), findsNothing);
  });

  for (final size in [
    const Size(568, 320),
    const Size(852, 393),
    const Size(320, 568),
  ]) {
    testWidgets('real filter modal fits $size with reachable footer', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<SearchFilter>(
                  context: context,
                  isScrollControlled: true,
                  constraints: const BoxConstraints(maxWidth: 430),
                  builder: (_) =>
                      const SearchFilterSheet(current: SearchFilter()),
                ),
                child: const Text('필터 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('필터 열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final apply = find.widgetWithText(ElevatedButton, '필터 적용');
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(size.height));
      await tester.scrollUntilVisible(
        find.text('사용자 제보 매장 포함'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('초기화'));
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(find.byType(SearchFilterSheet), findsNothing);
    });
  }
}

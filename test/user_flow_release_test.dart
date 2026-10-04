import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/features/savings/presentation/state/savings_period.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

UserReportStatus report(
  String id,
  String name,
  String status, {
  String description = '',
}) => UserReportStatus.fromJson({
  'id': id,
  'storeName': name,
  'status': status,
  'address': '서울 중구',
  'menu1': '칼국수',
  'price1': '5000',
  'menu2': '음료',
  'price2': '0',
  'free2': true,
  'description': description,
  'reportType': 'STORE_INFO',
  'changeType': 'other',
});

class FakeReports extends ReportService {
  FakeReports(this.reports)
    : super(MockClient((_) async => http.Response('', 500)));
  final List<UserReportStatus>? reports;
  @override
  Future<List<UserReportStatus>?> fetchMyReports() async => reports;
}

class WebPermissions extends DevicePermissionService {
  @override
  bool get web => true;
  @override
  Future<DeviceAccess> location() async => DeviceAccess.allowed;
}

void main() {
  test('report query searches original description, all menus and address', () {
    final value = report('1', '식당', 'APPROVED', description: '가격표 오류');
    expect(matchesMyReportQuery(value, ' 가격표 '), isTrue);
    expect(matchesMyReportQuery(value, '음료'), isTrue);
    expect(matchesMyReportQuery(value, '중구'), isTrue);
    expect(matchesMyReportQuery(value, '없는 내용'), isFalse);
    expect(value.copyWith(status: '반려').description, '가격표 오류');
    expect(value.menuPrices.last.free, isTrue);
    expect(value.menuPrices.last.displayText, '음료 무료');
    expect(
      const UserReportMenuPrice(menu: '음료', price: '0').displayText,
      '음료 가격 확인 필요',
    );
  });

  test(
    'KST ranges handle year, leap day, invalid rollover and UTC midnight',
    () {
      final january = SavingsPeriod.currentMonth(
        DateTime.parse('2025-12-31T15:00:00Z'),
      );
      expect(january.startDate, '2026-01-01');
      expect(january.endDateExclusive, '2026-02-01');
      expect(january.title, '2026년 1월');
      expect(
        january.contains(SavingsPeriod.koreanDate('2025-12-31T15:00:00Z')!),
        isTrue,
      );
      expect(
        january.contains(SavingsPeriod.koreanDate('2026-01-31T15:00:00Z')!),
        isFalse,
      );
      expect(
        SavingsPeriod.fromDates(
          '2024-02-01',
          '2024-03-01',
        )!.contains(SavingsPeriod.koreanDate('2024-02-29')!),
        isTrue,
      );
      expect(SavingsPeriod.fromDates('2026-02-29', '2026-03-01'), isNull);
      expect(SavingsPeriod.fromDates('2026-10-01', '2026-09-01'), isNull);
      expect(
        SavingsPeriod.fromDates('2026-01-01', '2027-01-01')!.title,
        '2026년',
      );
      expect(SavingsPeriod.koreanDate('2026-09-30T23:30:00')!.day, 30);
    },
  );

  testWidgets('my report search combines with status tabs and clears', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final items = [
      report('1', '승인 식당', 'APPROVED', description: '가격표 오류'),
      report('2', '검토 식당', 'PENDING', description: '위치 오류'),
    ];
    final container = ProviderContainer(
      overrides: [reportServiceProvider.overrideWithValue(FakeReports(items))],
    );
    addTearDown(container.dispose);
    container.read(userReportsProvider.notifier).setReports(items);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: MyReportsV2Screen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 제보 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가격표');
    await tester.pumpAndSettle();
    expect(find.text('승인 식당'), findsOneWidget);
    expect(find.text('검토 식당'), findsNothing);
    await tester.tap(find.text('검토 중').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('검색 결과가 없어요'), findsOneWidget);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('검토 식당'), findsOneWidget);
  });

  testWidgets('allowed web location still opens actionable settings guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devicePermissionServiceProvider.overrideWithValue(WebPermissions()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => manageLocationPermission(
                  context,
                  ref,
                  DeviceAccess.allowed,
                ),
                child: const Text('위치 관리'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('위치 관리'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 관리'), findsOneWidget);
    expect(find.textContaining('Chrome: 주소창'), findsOneWidget);
    await tester.tap(find.text('권한 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'shared confirmation exposes title and consequence and initially focuses cancel',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => HowmuchDialog(
                    title: '구독을 해제할까요?',
                    description: '가격 변동 알림이 꺼져요.',
                    confirmLabel: '구독 해제',
                    onConfirm: () {},
                  ),
                ),
                child: const Text('관리'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('관리'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('구독을 해제할까요?. 가격 변동 알림이 꺼져요.'), findsWidgets);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
            .autofocus,
        isTrue,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(HowmuchDialog), findsNothing);
      handle.dispose();
    },
  );
}

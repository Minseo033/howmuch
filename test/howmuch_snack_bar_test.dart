import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_theme.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';

void main() {
  Widget buildHarness(SnackBar snackBar) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).showSnackBar(snackBar),
              child: const Text('알림 표시'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('성공 피드백은 제목, 메시지, 상태 아이콘을 함께 표시한다', (tester) async {
    await tester.pumpWidget(
      buildHarness(HowmuchSnackBar.success(content: const Text('프로필을 저장했어요.'))),
    );

    await tester.tap(find.text('알림 표시'));
    await tester.pumpAndSettle();

    expect(find.text('완료했어요'), findsOneWidget);
    expect(find.text('프로필을 저장했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byTooltip('알림 닫기'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('오류 피드백은 긴 메시지와 닫기 동작을 지원한다', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        HowmuchSnackBar.error(
          content: const Text('네트워크 연결을 확인한 뒤 잠시 후 다시 시도해주세요.'),
        ),
      ),
    );

    await tester.tap(find.text('알림 표시'));
    await tester.pumpAndSettle();

    expect(find.text('처리하지 못했어요'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);

    await tester.tap(find.byTooltip('알림 닫기'));
    await tester.pumpAndSettle();

    expect(find.text('처리하지 못했어요'), findsNothing);
  });

  testWidgets('하단 내비게이션 화면에서는 충분한 아래 여백을 둔다', (tester) async {
    final snackBar = HowmuchSnackBar(
      content: const Text('지도 정보를 확인해주세요.'),
      aboveNavigation: true,
    );

    expect(snackBar.margin, const EdgeInsets.fromLTRB(12, 0, 12, 112));
  });

  testWidgets('좁은 화면에서도 단일 표면이 좌우 안전 여백 안에 표시된다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snackBar = HowmuchSnackBar(
      content: const Text('브라우저 푸시는 지원하지 않아요. 앱의 알림함을 이용해 주세요.'),
    );
    expect(snackBar.showCloseIcon, isFalse);

    await tester.pumpWidget(buildHarness(snackBar));
    await tester.tap(find.text('알림 표시'));
    await tester.pumpAndSettle();

    final surface = tester.getRect(
      find.byKey(const ValueKey('howmuch-snack-bar-surface')),
    );
    expect(surface.left, greaterThanOrEqualTo(12));
    expect(surface.right, lessThanOrEqualTo(308));
    expect(find.byTooltip('알림 닫기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('마이그레이션된 기존 메시지는 문구에 맞는 상태를 선택한다', () {
    expect(
      HowmuchSnackBar(content: const Text('문의가 접수되었어요.')).tone,
      HowmuchSnackBarTone.success,
    );
    expect(
      HowmuchSnackBar(content: const Text('목표 금액을 입력해주세요.')).tone,
      HowmuchSnackBarTone.warning,
    );
    expect(
      HowmuchSnackBar(content: const Text('네트워크 오류가 발생했습니다.')).tone,
      HowmuchSnackBarTone.error,
    );
  });
}

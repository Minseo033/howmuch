import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/howmuch_app.dart';

void main() {
  testWidgets('starts at the first onboarding screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    expect(find.text('1-1'), findsOneWidget);
    expect(find.text('온보딩 · 주변 착한가격업소'), findsOneWidget);
  });

  testWidgets('moves through onboarding, login, permission, and home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('온보딩 · 절약 리포트'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('온보딩 · 매장 제보'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('1-4 로그인'), findsOneWidget);

    await tester.tap(find.text('이메일로 로그인'));
    await tester.pumpAndSettle();
    expect(find.text('1-5 권한 설정'), findsOneWidget);

    await tester.tap(find.text('홈으로 이동').first);
    await tester.pumpAndSettle();
    expect(find.text('2-1 홈 / 메인 지도'), findsOneWidget);
  });

  testWidgets('opens mypage and owned sub screens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToHome(tester);
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    expect(find.text('5-1 마이페이지'), findsOneWidget);

    await tester.tap(find.text('알림 설정'));
    await tester.pumpAndSettle();
    expect(find.text('5-A 알림 설정'), findsOneWidget);
  });

  testWidgets('renders admin and state screens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HowmuchApp()));
    await tester.pumpAndSettle();

    await _goToHome(tester);
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('관리자 화면'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('관리자 화면'));
    await tester.pumpAndSettle();
    expect(find.text('6-1 관리자 제보 검토'), findsOneWidget);
    expect(find.textContaining('성산동 김밥집'), findsOneWidget);

    await tester.tap(find.text('문의 검토'));
    await tester.pumpAndSettle();
    expect(find.text('6-2 관리자 문의 검토'), findsOneWidget);
    expect(find.textContaining('가격 정보 수정 요청'), findsOneWidget);
  });
}

Future<void> _goToHome(WidgetTester tester) async {
  await tester.tap(find.text('건너뛰기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('이메일로 로그인'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('홈으로 이동').first);
  await tester.pumpAndSettle();
}

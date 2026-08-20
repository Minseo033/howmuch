import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_inquiries_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';

void main() {
  testWidgets('renders long inquiry and answer without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final inquiry = Inquiry(
      id: 'inquiry-1',
      title: '매우 긴 문의 제목이 두 줄을 넘어가더라도 카드의 상태 표시와 겹치지 않아야 합니다',
      content: List.filled(8, '문의 본문이 길어져도 전체 내용을 확인할 수 있어야 합니다.').join(' '),
      category: '매장 정보 오류',
      status: 'ANSWERED',
      createdAt: '2026-08-19T01:00:00Z',
      answer: List.filled(8, '관리자 답변이 길어져도 잘리지 않고 표시되어야 합니다.').join(' '),
      answeredAt: '2026-08-19T02:00:00Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myInquiriesProvider.overrideWith((ref) async => [inquiry]),
        ],
        child: const MaterialApp(home: MyInquiriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('답변 완료'), findsOneWidget);
    expect(find.textContaining('관리자 답변이 길어져도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a useful empty state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [myInquiriesProvider.overrideWith((ref) async => const [])],
        child: const MaterialApp(home: MyInquiriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('등록한 문의가 없어요'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}

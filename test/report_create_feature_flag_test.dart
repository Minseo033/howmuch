import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';

void main() {
  testWidgets('hides report image upload while the release flag is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportCreateScreen())),
    );

    expect(find.text('방문 확인'), findsOneWidget);
    expect(find.text('메뉴판 사진 첨부'), findsNothing);
  });
}

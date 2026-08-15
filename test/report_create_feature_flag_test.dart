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
}

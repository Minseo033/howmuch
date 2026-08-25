import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/shared/widgets/login_required_dialog.dart';

void main() {
  testWidgets('shows login guidance as a centered dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showLoginRequiredDialog(
                context,
                message: '제보하려면 카카오 로그인이 필요해요.',
              ),
              child: const Text('제보하기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('제보하기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_required_dialog')), findsOneWidget);
    expect(find.text('로그인이 필요해요'), findsOneWidget);
    expect(find.text('제보하려면 카카오 로그인이 필요해요.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}

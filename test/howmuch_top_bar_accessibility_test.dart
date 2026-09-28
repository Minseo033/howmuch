import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/shared/widgets/custom_app_bar.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';

void main() {
  testWidgets('top bar exposes back and trailing action names', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HowmuchTopBar(
            title: '동네 제보',
            onBack: () {},
            trailingIcon: Icons.search_rounded,
            trailingTooltip: '검색',
            onTrailingTap: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('뒤로가기'), findsOneWidget);
    expect(find.bySemanticsLabel('검색'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('custom app bar back button exposes an accessible name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(appBar: CustomAppBar(title: '상세')),
                  ),
                ),
                child: const Text('상세 열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('상세 열기'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('뒤로가기'), findsOneWidget);
    semantics.dispose();
  });
}

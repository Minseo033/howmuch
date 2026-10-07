import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/shared/widgets/custom_app_bar.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';

import 'support/screen_reader.dart';

void main() {
  // QA 10/7 #51: each button is one element, named once.
  testWidgets('top bar reads back and trailing actions once', (tester) async {
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

    for (final name in ['뒤로가기', '검색']) {
      expect(readerElements(name), findsOne);
      expect(
        readerElements(name),
        isSemantics(tooltip: name, isButton: true, hasTapAction: true),
      );
    }
    semantics.dispose();
  });

  testWidgets('custom app bar reads its back button once', (tester) async {
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

    expect(readerElements('뒤로가기'), findsOne);
    expect(
      readerElements('뒤로가기'),
      isSemantics(tooltip: '뒤로가기', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });
}

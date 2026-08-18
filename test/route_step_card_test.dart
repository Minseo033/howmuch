import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_step_card.dart';

void main() {
  testWidgets('keeps route step content inside a narrow mobile layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RouteStepCard(
                index: '1',
                storeName: '매우 긴 매장 이름이 들어와도 한 줄로 잘려야 해요',
                details: '대표 메뉴 · 15000원 · 15771m',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('route-step-1')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('매우 긴 매장 이름이 들어와도 한 줄로 잘려야 해요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders route step details within the card width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 335,
              child: RouteStepCard(
                index: '2',
                storeName: '무한칼국수',
                details: '칼국수 · 5000원 · 803m',
              ),
            ),
          ),
        ),
      ),
    );

    final cardSize = tester.getSize(find.byKey(const ValueKey('route-step-2')));
    expect(cardSize.width, lessThanOrEqualTo(335));
    expect(find.text('무한칼국수'), findsOneWidget);
    expect(find.text('칼국수 · 5000원 · 803m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

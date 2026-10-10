import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/recommendation_radius_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _openSheet(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: Center(child: RecommendationRadiusButton())),
      ),
    ),
  );
  await tester.tap(find.byType(RecommendationRadiusButton));
  await tester.pumpAndSettle();
  return container;
}

/// Drags the knob from the stop for [fromKm] by [stops] kilometres.
Future<void> _dragKnob(WidgetTester tester, int fromKm, int stops) async {
  final track = tester.getRect(find.byType(Slider));
  // Where the slider's 1km and 15km stops sit; the rest are evenly between.
  final first = track.left + 28;
  final step = (track.width - 56) / 14;
  await tester.dragFrom(
    Offset(first + step * (fromKm - 1), track.center.dy),
    Offset(step * stops, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dragging the knob picks the distance the button applies', (
    tester,
  ) async {
    final container = await _openSheet(tester);
    expect(find.text('3km 이내', findRichText: true), findsWidgets);
    expect(find.text('3km 이내로 적용하기'), findsOneWidget);

    await _dragKnob(tester, 3, 4);

    expect(find.text('반경 7km 안의 매장을 추천해요'), findsOneWidget);
    expect(find.text('7km 이내로 적용하기'), findsOneWidget);
    expect(
      container.read(recommendationRadiusProvider),
      3000,
      reason: 'nothing changes until the button is pressed',
    );

    await tester.tap(find.text('7km 이내로 적용하기'));
    await tester.pumpAndSettle();

    expect(container.read(recommendationRadiusProvider), 7000);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '7km 이내'), findsOneWidget);
    // A guest has no account to keep it under, so it lasts this visit.
    expect(find.textContaining('로그인하면 다음에도 유지돼요'), findsOneWidget);
  });

  testWidgets('the knob stops at 1km and 15km', (tester) async {
    await _openSheet(tester);

    await _dragKnob(tester, 3, -6);
    expect(find.text('1km 이내로 적용하기'), findsOneWidget);

    await _dragKnob(tester, 1, 20);
    expect(find.text('15km 이내로 적용하기'), findsOneWidget);
  });

  testWidgets('closing the sheet without the button keeps the distance', (
    tester,
  ) async {
    final container = await _openSheet(tester);
    await _dragKnob(tester, 3, 6);
    expect(find.text('9km 이내로 적용하기'), findsOneWidget);

    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(container.read(recommendationRadiusProvider), 3000);
    expect(find.widgetWithText(OutlinedButton, '3km 이내'), findsOneWidget);
  });

  testWidgets('large text still fits the sheet and its scale', (tester) async {
    await _openSheet(tester, textScale: 2);
    await _dragKnob(tester, 3, 12);

    expect(tester.takeException(), isNull);
    expect(find.text('15km 이내로 적용하기'), findsOneWidget);
    for (final mark in ['1km', '5km', '10km', '15km']) {
      expect(
        tester.getSize(find.text(mark)).height,
        lessThan(40),
        reason: '$mark stays on one line',
      );
    }
  });
}

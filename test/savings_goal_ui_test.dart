import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_goal_setting_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const preview = bool.fromEnvironment('HOWMUCH_UI_PREVIEW');
  const stage = String.fromEnvironment('UI_STAGE', defaultValue: 'after');
  setUpAll(() async {
    if (!preview) return;
    final bytes = await File(
      '/System/Library/Fonts/AppleSDGothicNeo.ttc',
    ).readAsBytes();
    for (final family in ['Inter', 'Noto Sans KR', 'Preview']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'save and amount entry are disabled while loading or after load failure',
    (tester) async {
      final pending = Completer<http.Response>();
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: SavingsGoalSettingScreen()),
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        pending.complete(http.Response('{}', 500));
        await tester.pumpAndSettle();
        expect(find.text('절약 정보를 불러오지 못했어요.'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
        expect(find.byTooltip('뒤로가기'), findsOneWidget);
      }, () => MockClient((_) => pending.future));
    },
  );

  testWidgets('goal screen remains usable with keyboard and large amounts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: preview ? 'Preview' : null),
            home: const SavingsGoalSettingScreen(),
          ),
        );
        await tester.pumpAndSettle();
        if (preview) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../build/qa/savings-goal-$stage.png'),
          );
        }
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.enterText(find.byType(TextField), '100000');
        await tester.pumpAndSettle();
        expect(find.text('목표 저장하기').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/goal')
                ? {'goalAmount': 50000}
                : {'totalSavedAmount': 1234567, 'totalVisits': 123},
          ),
          200,
        ),
      ),
    );
  });
}

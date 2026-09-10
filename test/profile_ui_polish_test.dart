import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const preview = bool.fromEnvironment('HOWMUCH_UI_PREVIEW');
  setUpAll(() async {
    if (preview) {
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
    }
  });

  testWidgets(
    'nickname form stays usable above keyboard and clears validation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: preview ? 'Preview' : null),
            home: const ProfileEditScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (preview) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../build/qa/profile-polished.png'),
        );
      }
      await tester.tap(find.byKey(const ValueKey('profile-nickname-edit')));
      await tester.pumpAndSettle();
      if (preview) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../build/qa/nickname-polished.png'),
        );
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final field = find.byKey(const ValueKey('profile-nickname-field'));
      await tester.enterText(field, '   ');
      await tester.tap(find.text('변경'));
      await tester.pumpAndSettle();
      expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
      await tester.enterText(field, '새로운 이름');
      await tester.pumpAndSettle();
      expect(find.text('닉네임을 입력해주세요.'), findsNothing);
      await tester.tap(find.text('변경'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 이름'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 이름'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/privacy_policy_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/terms_of_service_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivacyPolicyScreen & TermsOfServiceScreen tests', () {
    testWidgets(
      'proves chapters 1 through 7 all exist with full body content on privacy policy screen',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
        );
        await tester.pumpAndSettle();

        // Brand label check
        expect(find.text('얼마고? 개인정보 처리방침'), findsOneWidget);

        // TOC entries 1..7 check
        expect(find.text('1. 수집하는 개인정보 항목'), findsOneWidget);
        expect(find.text('2. 개인정보 이용 목적'), findsOneWidget);
        expect(find.text('3. 보유 및 이용 기간'), findsOneWidget);
        expect(find.text('4. 제 3자 제공 안내'), findsOneWidget);
        expect(find.text('5. 위치 정보 처리'), findsOneWidget);
        expect(find.text('6. 이용자의 권리'), findsOneWidget);
        expect(find.text('7. 회원 탈퇴 시 데이터 처리'), findsOneWidget);

        // Chapter headings 1..7 check
        expect(find.text('수집하는 개인정보 항목'), findsOneWidget);
        expect(find.text('개인정보 이용 목적'), findsOneWidget);
        expect(find.text('보유 및 이용 기간'), findsOneWidget);
        expect(find.text('제 3자 제공 안내'), findsOneWidget);
        expect(find.text('위치 정보 처리'), findsOneWidget);
        expect(find.text('이용자의 권리'), findsOneWidget);
        expect(find.text('회원 탈퇴 시 데이터 처리'), findsOneWidget);

        // Chapter numbers 1..7 check
        for (var i = 1; i <= 7; i++) {
          expect(find.text('$i'), findsAtLeastNWidgets(1));
        }

        // Section 1 body content check
        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final allTexts = richTexts.map((r) => r.text.toPlainText()).toList();
        expect(
          allTexts.any((t) => t.contains('카카오 로그인 식별자, 이메일')),
          isTrue,
          reason: 'Chapter 1 must contain kakao login identifier and email',
        );
        expect(
          allTexts.any((t) => t.contains('위치 정보')),
          isTrue,
          reason: 'Chapter 1 must contain location info',
        );
        expect(
          allTexts.any((t) => t.contains('제보·리뷰·방문·찜·문의 기록')),
          isTrue,
          reason: 'Chapter 1 must contain report/review/visit records',
        );

        // Section 2 body content check
        expect(find.textContaining('회원 식별 및 서비스 제공'), findsOneWidget);
        expect(find.textContaining('주변 매장 추천 및 절약 리포트 산출'), findsOneWidget);
        expect(find.textContaining('부정 이용 방지 및 보안'), findsOneWidget);

        // Section 3 body content check
        expect(
          allTexts.any((t) => t.contains('회원 탈퇴 시 즉시 파기를 원칙으로 하나,')),
          isTrue,
        );
        expect(
          allTexts.any((t) => t.contains('관계 법령에 따라 일부 정보는 보관됩니다.')),
          isTrue,
        );

        // Section 4 body content check (from docs/PRIVACY_POLICY_DRAFT.md)
        expect(
          allTexts.any(
            (t) => t.contains('운영자는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.'),
          ),
          isTrue,
          reason: 'Chapter 4 must contain non-disclosure principle',
        );
        expect(
          allTexts.any((t) => t.contains('(주)카카오 (카카오 로그인 인증 목적 / 카카오 방침 준용)')),
          isTrue,
          reason: 'Chapter 4 must contain Kakao entity details',
        );

        // Section 5 body content check
        expect(
          allTexts.any(
            (t) => t.contains('매장 검색·추천 목적') && t.contains('별도로 저장하지 않습니다'),
          ),
          isTrue,
          reason: 'Chapter 5 must state location usage and non-storage',
        );

        // Section 6 body content check (from docs/PRIVACY_POLICY_DRAFT.md)
        expect(
          allTexts.any((t) => t.contains('마이페이지 프로필 수정')),
          isTrue,
          reason: 'Chapter 6 must contain profile modification right',
        );
        expect(
          allTexts.any((t) => t.contains('회원 탈퇴 시 계정 및 연관 데이터 즉시 삭제')),
          isTrue,
          reason: 'Chapter 6 must contain immediate deletion upon withdrawal',
        );
        expect(
          allTexts.any((t) => t.contains('단말기 OS 설정에서 위치·알림·사진 권한 해제')),
          isTrue,
          reason: 'Chapter 6 must contain permission withdrawal guide',
        );

        // Section 7 body content check
        expect(
          allTexts.any(
            (t) =>
                t.contains('승인된 제보 데이터는 익명화') &&
                t.contains('공익 목적으로 계속 활용됩니다.'),
          ),
          isTrue,
          reason: 'Chapter 7 must contain anonymized report retention',
        );
      },
    );

    testWidgets('proves relationship-law sentence span order in chapter 3', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final allTexts = richTexts.map((r) => r.text.toPlainText()).toList();

      final hasCorrectOrder = allTexts.any(
        (text) => text.contains('관계 법령에 따라 일부 정보는 보관됩니다.'),
      );
      expect(
        hasCorrectOrder,
        isTrue,
        reason: 'Sentence must be "관계 법령에 따라 일부 정보는 보관됩니다."',
      );

      final hasInvertedOrder = allTexts.any(
        (text) =>
            text.contains('에 따라 일부 정보는 보관됩니다.관계 법령') ||
            text.contains('에 따라 일부 정보는 보관됩니다. 관계 법령'),
      );
      expect(
        hasInvertedOrder,
        isFalse,
        reason: 'Inverted order must not exist',
      );
    });

    testWidgets('TOC scroll targets 1 through 7 all navigate without errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(SingleChildScrollView);
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(
          of: scrollableFinder,
          matching: find.byType(Scrollable),
        ),
      );
      final controller = scrollableState.position;

      final tocTitles = [
        '1. 수집하는 개인정보 항목',
        '2. 개인정보 이용 목적',
        '3. 보유 및 이용 기간',
        '4. 제 3자 제공 안내',
        '5. 위치 정보 처리',
        '6. 이용자의 권리',
        '7. 회원 탈퇴 시 데이터 처리',
      ];

      for (var i = 0; i < tocTitles.length; i++) {
        // Reset scroll to top so TOC is visible before tapping
        controller.jumpTo(0.0);
        await tester.pumpAndSettle();

        final tocItem = find.text(tocTitles[i]);
        expect(tocItem, findsOneWidget);

        await tester.tap(tocItem);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        if (i >= 3) {
          expect(controller.pixels, greaterThan(0.0));
        }
      }
    });

    testWidgets('clipboard copy strings use brand 얼마고? instead of 얼마에요', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      // Test PrivacyPolicyScreen clipboard
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('privacy-policy-action-icon')),
      );
      await tester.pumpAndSettle();

      expect(copiedText, contains('얼마고?'));
      expect(copiedText, isNot(contains('얼마에요')));
      expect(copiedText, '얼마고? 개인정보 처리방침 — 앱 내 마이페이지에서 확인');

      // Test TermsOfServiceScreen clipboard
      copiedText = null;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TermsOfServiceScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('terms-of-service-action-icon')),
      );
      await tester.pumpAndSettle();

      expect(copiedText, contains('얼마고?'));
      expect(copiedText, isNot(contains('얼마에요')));
      expect(copiedText, '얼마고? 서비스 이용약관 — 앱 내 마이페이지에서 확인');
    });

    testWidgets(
      'renders responsively without overflow on 320x568 and 568x320 landscape',
      (tester) async {
        // 320x568
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: TermsOfServiceScreen())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 568x320 landscape
        tester.view.physicalSize = const Size(568, 320);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: TermsOfServiceScreen())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

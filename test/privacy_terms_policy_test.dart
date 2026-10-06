import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/privacy_policy_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/terms_of_service_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivacyPolicyScreen & TermsOfServiceScreen tests', () {
    testWidgets(
      'proves chapters 1 through 8 match what the service actually processes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('얼마고? 개인정보 처리방침'), findsOneWidget);

        const chapterTitles = [
          '수집하는 개인정보 항목',
          '개인정보 이용 목적',
          '보유 및 이용 기간',
          '제 3자 제공 안내',
          '처리 위탁 및 국외 이전',
          '위치 정보 처리',
          '이용자의 권리',
          '회원 탈퇴 시 데이터 처리',
        ];
        for (var i = 0; i < chapterTitles.length; i++) {
          final toc = find.byKey(ValueKey('privacy-toc-$i'));
          final chapter = find.byKey(
            ValueKey('privacy-chapter-${i + 1}-title'),
          );
          expect(toc, findsOneWidget);
          expect(chapter, findsOneWidget);
          expect(tester.widget<Text>(toc).data, chapterTitles[i]);
          expect(tester.widget<Text>(chapter).data, chapterTitles[i]);
        }

        final allTexts = [
          for (final richText in tester.widgetList<RichText>(
            find.byType(RichText),
          ))
            richText.text.toPlainText(),
        ].join('\n');

        // Items the audit found missing (FE-MY-11 / P1-3).
        for (final fact in [
          '닉네임, 주 활동 동네, 관심 카테고리',
          '카카오 프로필 사진 주소',
          '이번 달 절약 목표 금액',
          '영수증 사진과 판독 결과',
          '푸시 알림용 기기 토큰',
          'AI 채팅을 이용한 경우',
          '서버에 저장하지 않습니다',
          'Firebase 클라우드 메시징',
          'Gemini API',
          'Cloud Vision API',
          'Cloudinary',
          '제보·문의·영수증 사진 저장과 전송',
          '국외 이전',
          '해외 서버로 전송·보관될 수 있습니다',
          '매장과의 거리(미터)만 기록',
          '위치 권한은 선택입니다',
          '동네·관심 카테고리 정정은 1:1 문의로 요청',
          '알림 내역과 설정, 기기 토큰, 올린 사진을 삭제',
          '승인된 제보는 작성자 연결과 첨부 사진을 지운 뒤',
          '카카오 계정과 얼마고?의 연결 끊기',
        ]) {
          expect(allTexts, contains(fact), reason: 'policy must state: $fact');
        }

        // Claims that do not match the code must stay out.
        expect(allTexts, isNot(contains('별도로 저장하지 않습니다.')));
        expect(allTexts, isNot(contains('프로필 수정에서 닉네임·동네 등 정정')));
        expect(allTexts, isNot(contains('관계 법령에 따라 일부 정보는 보관됩니다.')));

        expect(find.textContaining('회원 식별, 로그인 유지 및 서비스 제공'), findsOneWidget);
        expect(
          find.textContaining('제보 처리 결과, 댓글, 문의 답변, 공지 알림 발송'),
          findsOneWidget,
        );
        expect(find.textContaining('부정 이용 방지 및 보안'), findsOneWidget);
        expect(find.text('버전 2.5  ·  시행 2026.10.06'), findsOneWidget);
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

      final allTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText())
          .toList();

      expect(
        allTexts.any(
          (text) =>
              text.contains('· 다만 관계 법령에 따라 보존해야 하는 정보가 생기면 그 기간 동안 보관합니다.'),
        ),
        isTrue,
        reason: 'leading text, bold law reference and tail must stay in order',
      );
      expect(
        allTexts.any(
          (text) => text.contains('에 따라 보존해야 하는 정보가 생기면 그 기간 동안 보관합니다.관계 법령'),
        ),
        isFalse,
      );
    });

    testWidgets('TOC scroll targets 1 through 8 all navigate without errors', (
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

      for (var i = 0; i < 8; i++) {
        // Reset scroll to top so TOC is visible before tapping
        controller.jumpTo(0.0);
        await tester.pumpAndSettle();

        final tocItem = find.byKey(ValueKey('privacy-toc-$i'));
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

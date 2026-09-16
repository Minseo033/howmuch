import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:howmuch/features/store/presentation/screens/price_history_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/system/presentation/screens/network_error_screen.dart';
import 'package:howmuch/features/system/presentation/screens/session_expired_screen.dart';

void main() {
  final store = Store(
    id: 'responsive-test',
    storeName: '작은 화면 테스트 매장',
    address: '서울시 강남구 테스트로 1',
    phoneNumber: '02-000-0000',
    industry: '한식',
    menu1: '비빔밥',
    price1: '7000',
    menu2: '',
    price2: '',
    menu3: '',
    price3: '',
    menu4: '',
    price4: '',
    latitude: 37.5,
    longitude: 127.0,
    source: 'GOV',
  );

  final viewports = <String, Size>{
    '320x568': const Size(320, 568),
    '568x320': const Size(568, 320),
    '768x1024': const Size(768, 1024),
    '1280x800': const Size(1280, 800),
  };

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
    // Network-backed screens are intentionally only pumped for one frame; the
    // layout assertion must not depend on an API response.
    await tester.pump();
    final exception = tester.takeException();
    if (exception != null) {
      debugPrint('responsive exception: $exception');
      if (exception is FlutterError) {
        debugPrint(exception.toStringDeep());
      }
    }
    expect(exception, isNull);
  }

  for (final entry in viewports.entries) {
    testWidgets('second-pass responsive screens stay stable at ${entry.key}', (
      tester,
    ) async {
      final size = entry.value;

      await pumpAt(
        tester,
        size,
        OnboardingPage(
          slides: const [
            OnboardingSlideData(
              figmaId: 'responsive',
              title: '주변 매장을 찾아보세요',
              description: '작은 화면에서도 CTA가 접근 가능해야 해요.',
              eyebrow: 'HOWMUCH',
              eyebrowColor: Colors.blue,
              eyebrowBackgroundColor: Color(0xFFEFF6FF),
              artwork: OnboardingArtwork.nearby,
              primaryLabel: '다음',
            ),
          ],
          onComplete: _noop,
        ),
      );

      final screens = <Widget>[
        const SessionExpiredScreen(),
        const ReportCompleteScreen(),
        const CommunityFeedScreen(),
        const ProfileSetupScreen(),
        ReviewWriteScreen(store: store),
        PriceHistoryScreen(store: store),
        ReviewListScreen(store: store),
        const NetworkErrorScreen(),
      ];

      for (final screen in screens) {
        debugPrint(
          'responsive second pass: ${screen.runtimeType} at ${entry.key}',
        );
        await pumpAt(tester, size, screen);
      }
    });
  }
}

void _noop() {}

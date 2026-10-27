import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/startup_location.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:howmuch/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNearbyScreen extends ConsumerWidget {
  const OnboardingNearbyScreen({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPage(
      initialStep: initialStep,
      slides: _slides,
      // Everyone starts as a guest: permission setup, then home. Features
      // that need an account ask for login when they are used.
      onComplete: () => _finish(context, ref, AppRoutes.permissionSetup),
      onLoginPressed: () => _logIn(context, ref),
    );
  }

  /// Members log in on top of the slides. Leaving login comes back here;
  /// logging in opens the address requested before, otherwise home.
  Future<void> _logIn(BuildContext context, WidgetRef ref) async {
    if (!await openLoginFlow(context) || !context.mounted) return;
    await _finish(context, ref, ref.read(startupLocationProvider).take());
  }

  Future<void> _finish(BuildContext context, WidgetRef ref, String next) async {
    ref.read(onboardingCompletedProvider.notifier).state = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_completed', true);
    if (!context.mounted) return;
    context.go(next);
  }
}

const _slides = [
  OnboardingSlideData(
    figmaId: '1-1',
    eyebrow: '정부 인증 · 공공데이터',
    eyebrowColor: Color(0xFF2563EB),
    eyebrowBackgroundColor: Color(0xFFEFF4FF),
    artwork: OnboardingArtwork.nearby,
    title: '내 주변 착한가격업소를 한눈에',
    description: '공공데이터 기반으로 인증된 저렴한 매장을\n지도에서 쉽게 찾아보세요.',
    primaryLabel: '다음',
  ),
  OnboardingSlideData(
    figmaId: '1-2',
    eyebrow: '절약 리포트',
    eyebrowColor: Color(0xFF10B981),
    eyebrowBackgroundColor: Color(0xFFEFF4FF),
    artwork: OnboardingArtwork.savings,
    title: '오늘 아낀 금액이 쌓여요',
    description: '공공 가격 데이터와 비교해 얼마나 절약했는지\n월별 리포트로 확인할 수 있어요.',
    primaryLabel: '다음',
  ),
  OnboardingSlideData(
    figmaId: '1-3',
    eyebrow: '사용자 제보',
    eyebrowColor: Color(0xFFF97316),
    eyebrowBackgroundColor: Color(0xFFFFF3EA),
    artwork: OnboardingArtwork.storeReport,
    title: '좋은 가격은 함께 나눠요',
    description: '지도에 없는 동네 가성비 매장을 제보하고,\n더 정확한 가격 정보를 만들어보세요.',
    primaryLabel: '시작하기',
  ),
];

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:howmuch/features/onboarding/presentation/widgets/onboarding_page.dart';

class OnboardingNearbyScreen extends ConsumerWidget {
  const OnboardingNearbyScreen({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPage(
      initialStep: initialStep,
      slides: _slides,
      onComplete: () {
        ref.read(onboardingCompletedProvider.notifier).state = true;
        context.go(AppRoutes.login);
      },
      onSkipPressed: () {
        ref.read(onboardingCompletedProvider.notifier).state = true;
        context.go(AppRoutes.permissionSetup);
      },
    );
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
    description: '공공데이터 기반으로 인증된 저렴한 매장을 지도에서 쉽게 찾아보세요.',
    primaryLabel: '다음',
  ),
  OnboardingSlideData(
    figmaId: '1-2',
    eyebrow: '절약 리포트',
    eyebrowColor: Color(0xFF10B981),
    eyebrowBackgroundColor: Color(0xFFE8F8F1),
    artwork: OnboardingArtwork.savings,
    title: '오늘 아낀 금액이 쌓여요',
    description: '평균 가격과 비교해 얼마나 절약했는지 월별 리포트로 확인할 수 있어요.',
    primaryLabel: '다음',
  ),
  OnboardingSlideData(
    figmaId: '1-3',
    eyebrow: '사용자 제보',
    eyebrowColor: Color(0xFFF97316),
    eyebrowBackgroundColor: Color(0xFFFFF3EA),
    artwork: OnboardingArtwork.storeReport,
    title: '좋은 가격은 함께 나눠요',
    description: '지도에 없는 동네 가성비 매장을 제보하고, 더 정확한 가격 정보를 만들어보세요.',
    primaryLabel: '시작하기',
  ),
];

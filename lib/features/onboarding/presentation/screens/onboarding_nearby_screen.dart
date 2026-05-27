import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:howmuch/features/onboarding/presentation/widgets/onboarding_page.dart';

class OnboardingNearbyScreen extends ConsumerWidget {
  const OnboardingNearbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPage(
      figmaId: '1-1',
      title: '온보딩 · 주변 착한가격업소',
      icon: Icons.map,
      description: '내 주변의 착한가격업소와 사용자 제보 매장을 한눈에 확인합니다.',
      highlights: const [
        '현재 위치 기준으로 가까운 매장을 확인',
        '공공데이터와 사용자 제보를 함께 비교',
        '지도 API 연동 전에도 UI 흐름을 먼저 검증',
      ],
      step: 0,
      totalSteps: 3,
      primaryLabel: '다음',
      onPrimaryPressed: () => context.go(AppRoutes.onboardingSavingsReport),
      onSkipPressed: () {
        ref.read(onboardingCompletedProvider.notifier).state = true;
        context.go(AppRoutes.login);
      },
    );
  }
}

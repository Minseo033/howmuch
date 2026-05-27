import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:howmuch/features/onboarding/presentation/widgets/onboarding_page.dart';

class OnboardingSavingsReportScreen extends ConsumerWidget {
  const OnboardingSavingsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPage(
      figmaId: '1-2',
      title: '온보딩 · 절약 리포트',
      icon: Icons.savings,
      description: '착한가격업소 이용 기록을 바탕으로 내가 얼마나 아꼈는지 보여줍니다.',
      highlights: const [
        '방문 기록과 찜한 매장을 기반으로 절약액 계산',
        '관심 지역과 카테고리별 소비 흐름 확인',
        '가격 알림과 절약 목표로 재방문 유도',
      ],
      step: 1,
      totalSteps: 3,
      primaryLabel: '다음',
      onPrimaryPressed: () => context.go(AppRoutes.onboardingStoreReport),
      onSkipPressed: () {
        ref.read(onboardingCompletedProvider.notifier).state = true;
        context.go(AppRoutes.login);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:howmuch/features/onboarding/presentation/widgets/onboarding_page.dart';

class OnboardingStoreReportScreen extends ConsumerWidget {
  const OnboardingStoreReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPage(
      figmaId: '1-3',
      title: '온보딩 · 매장 제보',
      icon: Icons.rate_review,
      description: '동네의 좋은 가격 정보를 직접 제보하고 검토 상태를 확인합니다.',
      highlights: const [
        '가격표, 메뉴, 위치 정보를 간단히 제보',
        '관리자 검토 상태와 승인 결과 확인',
        '지역 가격 정보를 함께 채워가는 구조',
      ],
      step: 2,
      totalSteps: 3,
      primaryLabel: '시작하기',
      onPrimaryPressed: () {
        ref.read(onboardingCompletedProvider.notifier).state = true;
        context.go(AppRoutes.login);
      },
      onSkipPressed: () {
        ref.read(onboardingCompletedProvider.notifier).state = true;
        context.go(AppRoutes.login);
      },
    );
  }
}

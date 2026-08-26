import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/custom_app_bar.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ConnectedSocialAccountsScreen extends ConsumerWidget {
  const ConnectedSocialAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(userProfileProvider);
    final isLoggedIn = auth.isLoggedIn;
    final provider = auth.provider.trim().isEmpty ? '로그인 정보 없음' : auth.provider;
    final email =
        usableAccountEmail(profile.email) ?? usableAccountEmail(auth.email);

    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const CustomAppBar(title: '로그인 계정'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.kakaoYellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'K',
                        style: TextStyle(
                          color: AppColors.kakaoBrown,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoggedIn ? '$provider 로그인' : '로그인 정보 없음',
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLoggedIn
                                ? (email ?? '이메일 정보 없음')
                                : '로그인 후 계정 정보를 확인할 수 있어요.',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '현재는 카카오 로그인만 지원합니다.',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

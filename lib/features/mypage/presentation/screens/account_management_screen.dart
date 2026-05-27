import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_setting_tile.dart';

class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return HowmuchScaffold(
      title: '5-C 계정 관리',
      subtitle: '${auth.provider} 계정으로 로그인 중입니다.',
      child: HowmuchCard(
        child: Column(
          children: [
            HowmuchSettingTile(
              icon: Icons.link,
              title: '연결된 소셜 계정',
              subtitle: auth.email,
              onTap: () => context.go(AppRoutes.connectedSocialAccounts),
            ),
            HowmuchSettingTile(
              icon: Icons.privacy_tip,
              title: '개인정보 처리방침',
              subtitle: '수집 항목과 보관 기준 확인',
              onTap: () => context.go(AppRoutes.privacyPolicy),
            ),
            HowmuchSettingTile(
              icon: Icons.description,
              title: '서비스 이용약관',
              subtitle: '서비스 이용 규칙 확인',
              onTap: () => context.go(AppRoutes.termsOfService),
            ),
            HowmuchSettingTile(
              icon: Icons.logout,
              title: '로그아웃',
              subtitle: '더미 로그인 상태를 초기화합니다.',
              trailing: const Icon(Icons.power_settings_new),
              onTap: () {
                ref.read(authStateProvider.notifier).state = auth.copyWith(
                  isLoggedIn: false,
                );
                context.go(AppRoutes.login);
              },
            ),
            HowmuchSettingTile(
              icon: Icons.delete_forever,
              title: '회원 탈퇴',
              subtitle: '계정 삭제 전 유의사항 확인',
              onTap: () => context.go(AppRoutes.withdrawal),
            ),
          ],
        ),
      ),
    );
  }
}

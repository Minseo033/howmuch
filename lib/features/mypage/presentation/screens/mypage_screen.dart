import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_setting_tile.dart';
import 'package:howmuch/shared/widgets/howmuch_section.dart';

class MypageScreen extends ConsumerWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return HowmuchScaffold(
      title: '5-1 마이페이지',
      actions: [
        IconButton(
          tooltip: '홈',
          icon: const Icon(Icons.map),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ],
      child: Column(
        children: [
          HowmuchCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    profile.nickname.characters.first,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile.nickname}님',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(profile.region),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.favoriteCategories
                            .map((item) => Chip(label: Text(item)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '프로필 수정',
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.go(AppRoutes.profileEdit),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: '절약액',
                  value: '${profile.savedAmount}원',
                  icon: Icons.savings,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  label: '방문',
                  value: '${profile.visitCount}회',
                  icon: Icons.location_on,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox(
                  label: '제보',
                  value: '${profile.reportCount}건',
                  icon: Icons.rate_review,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle('설정'),
          const SizedBox(height: 8),
          HowmuchCard(
            child: Column(
              children: [
                HowmuchSettingTile(
                  icon: Icons.notifications,
                  title: '알림 설정',
                  subtitle: '가격, 리뷰, 제보 알림 관리',
                  onTap: () => context.go(AppRoutes.notificationSettings),
                ),
                HowmuchSettingTile(
                  icon: Icons.price_change,
                  title: '가격 알림 구독',
                  subtitle: '관심 지역과 카테고리의 가격 변동 알림',
                  onTap: () => context.go(AppRoutes.priceAlertSubscription),
                ),
                HowmuchSettingTile(
                  icon: Icons.manage_accounts,
                  title: '계정 관리',
                  subtitle: '소셜 연결, 약관, 탈퇴 관리',
                  onTap: () => context.go(AppRoutes.accountManagement),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('서비스'),
          const SizedBox(height: 8),
          HowmuchCard(
            child: Column(
              children: [
                HowmuchSettingTile(
                  icon: Icons.dataset,
                  title: '공공데이터 출처',
                  subtitle: '착한가격업소 데이터 기준 확인',
                  onTap: () => context.go(AppRoutes.publicDataSource),
                ),
                HowmuchSettingTile(
                  icon: Icons.support_agent,
                  title: '문의하기',
                  subtitle: '오류, 제휴, 가격 정보 문의',
                  onTap: () => context.go(AppRoutes.inquiry),
                ),
                HowmuchSettingTile(
                  icon: Icons.admin_panel_settings,
                  title: '관리자 화면',
                  subtitle: '제보와 문의 검토 더미 화면',
                  onTap: () => context.go(AppRoutes.adminReportReview),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

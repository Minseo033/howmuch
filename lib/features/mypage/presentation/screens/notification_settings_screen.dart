import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return HowmuchScaffold(
      title: '5-A 알림 설정',
      subtitle: '받고 싶은 알림만 켜두면 가격 변동과 제보 결과를 놓치지 않을 수 있어요.',
      child: HowmuchCard(
        child: Column(
          children: [
            _SwitchRow(
              title: '전체 알림',
              subtitle: '모든 앱 알림을 한 번에 관리합니다.',
              value: settings.all,
              onChanged: (value) =>
                  ref.read(notificationSettingsProvider.notifier).state =
                      settings.copyWith(all: value),
            ),
            _SwitchRow(
              title: '리뷰 알림',
              subtitle: '내 리뷰에 댓글이나 반응이 생기면 알려줍니다.',
              value: settings.review,
              onChanged: settings.all
                  ? (value) =>
                        ref.read(notificationSettingsProvider.notifier).state =
                            settings.copyWith(review: value)
                  : null,
            ),
            _SwitchRow(
              title: '제보 검토 알림',
              subtitle: '내 제보가 승인 또는 반려되면 알려줍니다.',
              value: settings.report,
              onChanged: settings.all
                  ? (value) =>
                        ref.read(notificationSettingsProvider.notifier).state =
                            settings.copyWith(report: value)
                  : null,
            ),
            _SwitchRow(
              title: '가격 변동 알림',
              subtitle: '찜한 매장과 구독 카테고리의 가격 변동 알림입니다.',
              value: settings.price,
              onChanged: settings.all
                  ? (value) =>
                        ref.read(notificationSettingsProvider.notifier).state =
                            settings.copyWith(price: value)
                  : null,
            ),
            _SwitchRow(
              title: '서비스 공지',
              subtitle: '점검, 정책 변경, 새 기능 소식을 받습니다.',
              value: settings.service,
              onChanged: settings.all
                  ? (value) =>
                        ref.read(notificationSettingsProvider.notifier).state =
                            settings.copyWith(service: value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

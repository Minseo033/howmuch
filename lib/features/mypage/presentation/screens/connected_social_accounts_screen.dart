import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class ConnectedSocialAccountsScreen extends ConsumerWidget {
  const ConnectedSocialAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(socialAccountsProvider);

    return HowmuchScaffold(
      title: '5-L 연결된 소셜 계정',
      subtitle: '더미 계정 연결 상태입니다. 실제 OAuth 연동 시 이 화면의 상태 저장소를 교체합니다.',
      child: Column(
        children: [
          for (final account in accounts) ...[
            HowmuchCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  account.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(account.description),
                secondary: Icon(_iconFor(account.name)),
                value: account.connected,
                onChanged: (value) {
                  ref.read(socialAccountsProvider.notifier).state = accounts
                      .map(
                        (item) => item.name == account.name
                            ? item.copyWith(connected: value)
                            : item,
                      )
                      .toList();
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    return switch (name) {
      '카카오' => Icons.chat_bubble,
      '네이버' => Icons.public,
      _ => Icons.account_circle,
    };
  }
}

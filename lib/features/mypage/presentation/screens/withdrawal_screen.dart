import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: '5-I 회원 탈퇴',
      subtitle: '탈퇴 전 저장된 활동 데이터와 알림 구독 상태를 확인합니다.',
      child: Column(
        children: [
          HowmuchCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _WarningRow('작성한 리뷰와 제보 내역은 비식별 처리될 수 있습니다.'),
                SizedBox(height: 10),
                _WarningRow('가격 알림 구독과 연결된 소셜 계정 정보가 해제됩니다.'),
                SizedBox(height: 10),
                _WarningRow('탈퇴 후 같은 계정으로 다시 가입해도 이전 활동은 복구되지 않습니다.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agreed,
            title: const Text('위 내용을 확인했습니다.'),
            onChanged: (value) => setState(() => _agreed = value ?? false),
          ),
          const SizedBox(height: 12),
          HowmuchButton(
            label: '회원 탈퇴 진행',
            icon: Icons.delete_forever,
            onPressed: _agreed ? _confirmWithdrawal : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWithdrawal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('정말 탈퇴할까요?'),
          content: const Text('현재는 더미 상태만 초기화하고 로그인 화면으로 이동합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: const Text('탈퇴'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    ref.read(authStateProvider.notifier).state = const AuthState(
      isLoggedIn: false,
      provider: '이메일',
      email: 'minseo@example.com',
    );
    context.go(AppRoutes.login);
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

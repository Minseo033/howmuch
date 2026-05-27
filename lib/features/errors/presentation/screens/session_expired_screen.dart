import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/shared/widgets/status_message.dart';

class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('7-6 세션 만료 · 재로그인')),
      body: StatusMessage(
        icon: Icons.lock_clock,
        title: '로그인이 만료되었어요',
        message: '개인정보 보호를 위해 다시 로그인한 뒤 서비스를 이용해주세요.',
        actionLabel: '재로그인',
        onAction: () {
          ref.read(authStateProvider.notifier).state = const AuthState(
            isLoggedIn: false,
            provider: '이메일',
            email: 'minseo@example.com',
          );
          context.go(AppRoutes.login);
        },
        secondaryLabel: '홈으로 이동',
        onSecondaryAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}

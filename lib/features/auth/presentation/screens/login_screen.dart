import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'minseo@example.com');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1-4 로그인')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                '얼마고?',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '동네 착한가격을 찾고, 제보하고, 절약 흐름까지 확인해요.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              HowmuchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '간편 로그인',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    HowmuchButton(
                      label: '카카오로 계속하기',
                      icon: Icons.chat_bubble,
                      onPressed: () => _loginWith('카카오', 'kakao@howmuch.app'),
                    ),
                    const SizedBox(height: 10),
                    HowmuchButton(
                      label: '네이버로 계속하기',
                      icon: Icons.public,
                      isPrimary: false,
                      onPressed: () => _loginWith('네이버', 'naver@howmuch.app'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HowmuchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이메일로 테스트 로그인',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        prefixIcon: Icon(Icons.mail),
                      ),
                    ),
                    const SizedBox(height: 14),
                    HowmuchButton(
                      label: '이메일로 로그인',
                      icon: Icons.login,
                      onPressed: () => _loginWith(
                        '이메일',
                        _emailController.text.trim().isEmpty
                            ? 'minseo@example.com'
                            : _emailController.text.trim(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.screenCatalog),
                icon: const Icon(Icons.grid_view),
                label: const Text('개발용 화면 목록 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loginWith(String provider, String email) {
    ref.read(authStateProvider.notifier).state = AuthState(
      isLoggedIn: true,
      provider: provider,
      email: email,
    );
    context.go(AppRoutes.permissionSetup);
  }
}

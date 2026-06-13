import re

with open("lib/features/auth/presentation/screens/login_screen.dart", "r") as f:
    code = f.read()

# Add import if missing
if "kakao_login_service.dart" not in code:
    code = code.replace("import 'package:howmuch/features/auth/presentation/state/auth_state.dart';", "import 'package:howmuch/features/auth/presentation/state/auth_state.dart';\nimport 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';")

# Replace _loginWith with _handleSocialLogin logic
old_login_with = """  void _loginWith(
    WidgetRef ref,
    BuildContext context, {
    required String provider,
  }) {
    // TODO(박지환 BE): 실제 OAuth 로그인 API 응답으로 토큰, 이메일, 관리자 권한을 저장하세요.
    ref.read(authStateProvider.notifier).state = AuthState(
      isLoggedIn: true,
      isAdmin: false,
      provider: provider,
      email: '',
    );
    context.go(AppRoutes.permissionSetup);
  }"""

new_login_with = """  Future<void> _loginWith(
    WidgetRef ref,
    BuildContext context, {
    required String provider,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (provider == '카카오') {
      final success = await ref.read(kakaoLoginServiceProvider).login();
      if (success) {
        if (context.mounted) {
          context.go(AppRoutes.permissionSetup);
          messenger.showSnackBar(const SnackBar(content: Text('카카오로 로그인했어요.')));
        }
      } else {
        if (context.mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('로그인에 실패했습니다.')));
        }
      }
    } else {
      // 💡 타 소셜 로그인은 현재 더미 로직 유지
      ref.read(authStateProvider.notifier).state = AuthState(
        isLoggedIn: true,
        isAdmin: false,
        provider: provider,
        email: 'user@example.com',
      );
      if (context.mounted) {
        context.go(AppRoutes.permissionSetup);
        messenger.showSnackBar(SnackBar(content: Text('$provider로 로그인했어요. (더미)')));
      }
    }
  }"""

if old_login_with in code:
    code = code.replace(old_login_with, new_login_with)
    with open("lib/features/auth/presentation/screens/login_screen.dart", "w") as f:
        f.write(code)
    print("Patched _loginWith successfully.")
else:
    print("Could not find _loginWith.")


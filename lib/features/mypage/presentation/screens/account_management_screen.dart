import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';

class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});
  @override
  ConsumerState<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState
    extends ConsumerState<AccountManagementScreen> {
  bool _loggingOut = false;
  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('다시 로그인하면 저장된 설정과 활동 내역을 확인할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(kakaoLoginServiceProvider).logout();
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃을 완료하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(userProfileProvider);
    final location = ref.watch(locationAccessProvider);
    final email =
        usableAccountEmail(profile.email) ??
        usableAccountEmail(auth.email) ??
        '이메일 정보 없음';
    return SettingsPage(
      title: '계정 관리',
      onBack: () => leaveSettings(context, AppRoutes.mypage),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSection(
            children: [
              SettingsLink(
                title: profile.nickname,
                subtitle: email,
                icon: Icons.person_outline,
                onTap: auth.isLoggedIn
                    ? () => context.push(AppRoutes.profileEdit)
                    : () => context.go(AppRoutes.login),
              ),
              SettingsLink(
                title: '프로필 수정',
                subtitle: '닉네임과 계정 정보 확인',
                onTap: auth.isLoggedIn
                    ? () => context.push(AppRoutes.profileEdit)
                    : () => context.go(AppRoutes.login),
              ),
            ],
          ),
          SettingsSection(
            title: '계정과 권한',
            children: [
              SettingsLink(
                title: '로그인 계정',
                subtitle: auth.isLoggedIn ? auth.provider : '로그인 정보 없음',
                onTap: () => context.push(AppRoutes.connectedSocialAccounts),
              ),
              SettingsLink(
                title: '위치 권한',
                subtitle: location.when(
                  data: deviceAccessLabel,
                  loading: () => '확인 중…',
                  error: (_, _) => '권한을 확인하지 못했어요',
                ),
                onTap: () async {
                  await context.push(AppRoutes.locationSettings);
                  if (mounted) ref.invalidate(locationAccessProvider);
                },
              ),
              SettingsLink(
                title: '푸시 및 알림 설정',
                onTap: () => context.push(AppRoutes.notificationSettings),
              ),
            ],
          ),
          SettingsSection(
            title: '약관 및 정책',
            children: [
              SettingsLink(
                title: '개인정보 처리방침',
                onTap: () => context.push(AppRoutes.privacyPolicy),
              ),
              SettingsLink(
                title: '서비스 이용약관',
                onTap: () => context.push(AppRoutes.termsOfService),
              ),
            ],
          ),
          if (auth.isLoggedIn) ...[
            OutlinedButton(
              onPressed: _loggingOut ? null : _logout,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_loggingOut ? '로그아웃 중…' : '로그아웃'),
              ),
            ),
            const SizedBox(height: 24),
            SettingsSection(
              title: '회원 탈퇴',
              children: [
                SettingsLink(
                  title: '회원 탈퇴',
                  subtitle: '계정과 활동 데이터 삭제 안내를 확인해 주세요.',
                  onTap: _loggingOut
                      ? null
                      : () => context.push(AppRoutes.withdrawal),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

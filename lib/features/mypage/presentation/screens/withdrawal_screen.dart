import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});
  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  bool _confirmed = false;
  bool _busy = false;
  bool _asking = false;
  String? _error;
  Future<void> _withdraw() async {
    if (!_confirmed || _busy || _asking) return;
    _asking = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 탈퇴할까요?'),
        content: const Text(
          '얼마고 계정과 연결된 활동 데이터가 삭제되며 복구할 수 없어요. 카카오 계정 자체는 삭제되지 않아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '탈퇴하고 데이터 삭제',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계정 유지'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted || accepted != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ApiClient.delete(
        ApiClient.uri('/api/user'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode != 200) {
        throw StateError('Account deletion failed');
      }
      // The server has already removed this account's device registrations.
      if (!mounted) return;
      await ref
          .read(kakaoLoginServiceProvider)
          .clearLocalSession(unregisterDevice: false);
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '탈퇴 처리를 완료하지 못했어요. 연결 상태를 확인한 뒤 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SettingsPage(
      title: '회원 탈퇴',
      onBack: () {
        if (!_busy) leaveSettings(context, AppRoutes.accountManagement);
      },
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) SettingsMessage(_error!, isError: true),
          FilledButton(
            onPressed: _busy
                ? null
                : () => leaveSettings(context, AppRoutes.accountManagement),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('계정 유지'),
            ),
          ),
          TextButton(
            onPressed: !_confirmed || _busy ? null : _withdraw,
            child: Text(
              _busy ? '처리 중…' : '탈퇴하기',
              style: TextStyle(color: _confirmed ? AppColors.error : null),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SettingsSection(
            title: '탈퇴 전 확인해 주세요',
            children: [
              SettingsMessage(
                '탈퇴하면 얼마고 계정과 연결된 활동 데이터가 삭제돼요. 삭제된 데이터는 복구할 수 없어요.',
                isError: true,
              ),
              SettingsLink(
                title: '삭제 대상',
                subtitle: '프로필, 찜 목록, 방문·절약 기록, 제보·리뷰·댓글, 문의와 알림 설정',
              ),
              SettingsMessage('카카오 계정 자체는 유지돼요. 재가입해도 이전 기록이 자동으로 복구되지 않아요.'),
            ],
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: CheckboxListTile(
              key: const ValueKey('withdrawal-consent'),
              contentPadding: const EdgeInsets.all(16),
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                '안내를 확인했고, 계정과 데이터가 삭제되는 것에 동의해요.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

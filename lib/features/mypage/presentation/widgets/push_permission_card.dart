import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';

class PushPermissionCard extends ConsumerStatefulWidget {
  const PushPermissionCard({super.key});
  @override
  ConsumerState<PushPermissionCard> createState() => _PushPermissionCardState();
}

class _PushPermissionCardState extends ConsumerState<PushPermissionCard>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(pushAccessProvider);
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final registered = await ref
        .read(pushNotificationServiceProvider)
        .registerForCurrentSession();
    if (!mounted) return;
    ref.invalidate(pushAccessProvider);
    setState(() {
      _busy = false;
      _message = registered
          ? '현재 기기의 알림 수신을 연결했어요.'
          : '기기를 연결하지 못했어요. 알림 권한과 연결 상태를 확인한 뒤 다시 시도해 주세요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(devicePermissionServiceProvider);
    final access = ref.watch(pushAccessProvider);
    return SettingsSection(
      title: '이 기기의 푸시 알림',
      children: [
        SettingsLink(
          title: service.web ? '브라우저 푸시는 지원하지 않아요' : '기기 알림 권한',
          icon: Icons.notifications_active_outlined,
          subtitle: service.web
              ? '웹에서는 앱 안의 알림함에서 확인할 수 있어요. 아래 수신 설정은 계정에 저장돼요.'
              : access.when(
                  data: deviceAccessLabel,
                  loading: () => '확인 중…',
                  error: (_, _) => '확인하지 못했어요',
                ),
        ),
        if (service.supportsPush) ...[
          const SettingsMessage('기기에서 알림을 허용하고 수신을 연결해야 푸시를 받을 수 있어요.'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _register,
                  child: Text(_busy ? '연결 중…' : '권한 확인 및 수신 연결'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final opened = await service.openSettings();
                          if (!mounted || opened) return;
                          setState(
                            () => _message = '기기 설정에서 얼마고의 알림 권한을 변경해 주세요.',
                          );
                        },
                  child: const Text('기기 설정 열기'),
                ),
              ],
            ),
          ),
        ],
        if (_message != null) SettingsMessage(_message!),
      ],
    );
  }
}

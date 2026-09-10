import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({super.key});
  @override
  ConsumerState<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends ConsumerState<LocationSettingsScreen>
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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(locationAccessProvider);
    }
  }

  Future<void> _act(DeviceAccess access) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final service = ref.read(devicePermissionServiceProvider);
    if (access == DeviceAccess.denied) {
      await service.requestLocation();
    } else {
      final opened = await service.openSettings(
        locationService: access == DeviceAccess.serviceOff,
      );
      if (!mounted) return;
      if (!opened) {
        _message = service.web
            ? '주소창의 사이트 설정에서 위치 권한을 변경한 뒤 다시 확인해 주세요.'
            : '기기 설정에서 얼마고의 위치 권한을 변경해 주세요.';
      }
    }
    if (!mounted) return;
    ref.invalidate(locationAccessProvider);
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(locationAccessProvider);
    final service = ref.watch(devicePermissionServiceProvider);
    return SettingsPage(
      title: '위치 권한',
      onBack: () => leaveSettings(context, AppRoutes.mypage),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSection(
            children: [
              SettingsLink(
                title: '현재 기기의 위치 권한',
                icon: Icons.location_on_outlined,
                subtitle: access.when(
                  data: deviceAccessLabel,
                  loading: () => '확인 중…',
                  error: (_, _) => '확인하지 못했어요',
                ),
              ),
              const SettingsMessage(
                '주변 매장과 거리순 결과를 찾을 때 사용해요. 이 화면에서는 현재 위치를 수집하지 않아요.',
              ),
              if (service.web)
                const SettingsMessage('브라우저의 사이트 설정에서 위치 접근을 허용하거나 차단할 수 있어요.'),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (access.valueOrNull != null)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(access.requireValue),
                        child: Text(
                          _busy
                              ? '처리 중…'
                              : access.valueOrNull == DeviceAccess.denied
                              ? '위치 권한 요청'
                              : '권한 변경 안내',
                        ),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => ref.invalidate(locationAccessProvider),
                      child: const Text('상태 다시 확인'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_message != null) SettingsMessage(_message!),
        ],
      ),
    );
  }
}

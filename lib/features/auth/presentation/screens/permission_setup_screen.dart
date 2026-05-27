import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/permission_state.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class PermissionSetupScreen extends ConsumerWidget {
  const PermissionSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(permissionSettingsProvider);

    return HowmuchScaffold(
      title: '1-5 권한 설정',
      subtitle: '실제 권한 요청은 지도 API 연동 단계에서 붙이고, 지금은 앱 내부 상태로 흐름을 확인합니다.',
      child: Column(
        children: [
          HowmuchCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('위치 권한'),
                  subtitle: const Text('주변 착한가격업소를 거리순으로 보여줍니다.'),
                  value: settings.location,
                  secondary: const Icon(Icons.my_location),
                  onChanged: (value) =>
                      ref.read(permissionSettingsProvider.notifier).state =
                          settings.copyWith(location: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('알림 권한'),
                  subtitle: const Text('가격 변동과 제보 검토 결과를 알려줍니다.'),
                  value: settings.notification,
                  secondary: const Icon(Icons.notifications),
                  onChanged: (value) =>
                      ref.read(permissionSettingsProvider.notifier).state =
                          settings.copyWith(notification: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('혜택/공지 알림'),
                  subtitle: const Text('서비스 공지와 추천 정보를 받을 수 있습니다.'),
                  value: settings.marketing,
                  secondary: const Icon(Icons.campaign),
                  onChanged: (value) =>
                      ref.read(permissionSettingsProvider.notifier).state =
                          settings.copyWith(marketing: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          HowmuchButton(
            label: '홈으로 이동',
            icon: Icons.map,
            onPressed: () => context.go(AppRoutes.home),
          ),
          const SizedBox(height: 8),
          HowmuchButton(
            label: '나중에 설정',
            icon: Icons.arrow_forward,
            isPrimary: false,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}

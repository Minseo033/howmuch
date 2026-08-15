import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/permission_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSetupScreen extends ConsumerWidget {
  const PermissionSetupScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;
    final safeBottom = FigmaMobileCanvas.designSafePaddingOf(context).bottom;

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48.89204406738281 + topOffset,
            width: double.infinity,
            padding: EdgeInsets.only(top: topOffset, left: 8, right: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: .909),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: ink,
                    size: 20,
                  ),
                  onPressed: () => context.go(AppRoutes.login),
                ),
                const Text(
                  '3 / 3',
                  style: TextStyle(
                    color: muted,
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: _PermissionHeroIcon(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '더 정확한 추천을 위해\n권한이 필요해요',
                    style: TextStyle(
                      color: ink,
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '아래 권한을 허용하면 모든 기능을 사용할 수 있어요',
                    style: TextStyle(
                      color: muted,
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(flex: 3),
                  const Column(
                    children: [
                      _PermissionCard(
                        icon: Icons.location_on_outlined,
                        iconColor: blue,
                        iconBackground: Color(0xFFEFF4FF),
                        title: '위치 권한 (필수)',
                        description: '현재 위치 주변의 착한가격업소를 보여드려요.',
                        status: '허용',
                        allowed: true,
                      ),
                      SizedBox(height: 10),
                      _PermissionCard(
                        icon: Icons.notifications_none_rounded,
                        iconColor: orange,
                        iconBackground: Color(0xFFFFF3EA),
                        title: '알림 권한',
                        description: '찜한 매장의 가격 변동과 제보 승인 소식을 알려드려요.',
                        status: '허용',
                        allowed: true,
                      ),
                      SizedBox(height: 10),
                      _PermissionCard(
                        icon: Icons.photo_camera_outlined,
                        iconColor: muted,
                        iconBackground: Color(0xFFF1F5F9),
                        title: '사진 접근',
                        description: '매장 제보 시 메뉴판 사진을 첨부할 수 있어요.',
                        status: '나중에',
                        allowed: false,
                      ),
                    ],
                  ),
                  const Spacer(flex: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _PrimaryButton(
                      label: '앱 시작하기',
                      onPressed: () => _startApp(context, ref),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      '권한은 나중에 설정에서 변경할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontFamily: fontFamily,
                        fontFamilyFallback: fontFallback,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: safeBottom > 0 ? safeBottom / 2 : 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startApp(BuildContext context, WidgetRef ref) async {
    final result = await _requestStartupPermissions();

    if (!context.mounted) {
      return;
    }

    ref.read(permissionSettingsProvider.notifier).state = PermissionSettings(
      location: result.location,
      notification: result.notification,
      marketing: false,
    );
    context.go(AppRoutes.homeAiFab);
  }

  Future<_StartupPermissionResult> _requestStartupPermissions() async {
    if (kIsWeb) {
      return const _StartupPermissionResult(location: true, notification: true);
    }

    try {
      final location = await Permission.locationWhenInUse.request();
      final notification = await Permission.notification.request();

      return _StartupPermissionResult(
        location: location.isGranted || location.isLimited,
        notification: notification.isGranted || notification.isLimited,
      );
    } on MissingPluginException {
      return const _StartupPermissionResult(location: true, notification: true);
    }
  }
}

class _StartupPermissionResult {
  const _StartupPermissionResult({
    required this.location,
    required this.notification,
  });

  final bool location;
  final bool notification;
}

class _PermissionHeroIcon extends StatelessWidget {
  const _PermissionHeroIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFEFF4FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: PermissionSetupScreen.blue,
        size: 27,
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.status,
    required this.allowed,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final String status;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 89.78692626953125,
      padding: const EdgeInsets.symmetric(
        horizontal: 16.9033203125,
        vertical: 15.994,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: .909),
      ),
      child: Row(
        children: [
          Container(
            width: 47.99715805053711,
            height: 47.99715805053711,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 11.988636016845703),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PermissionSetupScreen.ink,
                    fontFamily: PermissionSetupScreen.fontFamily,
                    fontFamilyFallback: PermissionSetupScreen.fontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 1.989),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PermissionSetupScreen.muted,
                    fontFamily: PermissionSetupScreen.fontFamily,
                    fontFamilyFallback: PermissionSetupScreen.fontFallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11.988636016845703),
          Container(
            width: allowed ? 60.96590805053711 : 56.9886360168457,
            height: 30.468748092651367,
            decoration: BoxDecoration(
              color: allowed
                  ? const Color(0xFFE8F8F1)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (allowed) ...[
                  const Icon(
                    Icons.check_rounded,
                    color: PermissionSetupScreen.green,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  status,
                  style: TextStyle(
                    color: allowed
                        ? PermissionSetupScreen.green
                        : PermissionSetupScreen.muted,
                    fontFamily: PermissionSetupScreen.fontFamily,
                    fontFamilyFallback: PermissionSetupScreen.fontFallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PermissionSetupScreen.blue,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      shadowColor: const Color(0x4D2563EB),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onPressed(),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: PermissionSetupScreen.fontFamily,
              fontFamilyFallback: PermissionSetupScreen.fontFallback,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

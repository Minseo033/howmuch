import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

enum DeviceAccess { allowed, denied, blocked, serviceOff, unsupported, unknown }

/// Browser permission settings cannot be opened or revoked by the website.
Future<void> manageLocationPermission(
  BuildContext context,
  WidgetRef ref,
  DeviceAccess access,
) async {
  final service = ref.read(devicePermissionServiceProvider);
  if (service.web) {
    // A site the browser has not answered yet can still ask, so asking is
    // the main action then. Anything else changes only in the browser.
    final canAsk = access == DeviceAccess.denied;
    await showDialog<void>(
      context: context,
      builder: (context) => HowmuchDialog(
        title: '위치 권한 관리',
        description: '웹사이트가 권한을 직접 해제할 수는 없어요. 변경 후 돌아와 권한을 다시 확인해 주세요.',
        cancelLabel: '닫기',
        confirmLabel: canAsk ? '위치 사용 허용 요청' : '권한 다시 확인',
        onConfirm: () async {
          if (canAsk) await service.requestLocation();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: const _BrowserSteps(),
      ),
    );
  } else if (access == DeviceAccess.denied) {
    await service.requestLocation();
  } else {
    final opened = await service.openSettings(
      locationService: access == DeviceAccess.serviceOff,
    );
    if (!opened && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => HowmuchDialog(
          title: '기기 설정에서 변경해 주세요',
          description: '기기 설정 → 얼마고 → 위치 권한에서 허용 여부를 변경할 수 있어요.',
          cancelLabel: '닫기',
          confirmLabel: '권한 다시 확인',
          onConfirm: () => Navigator.of(context).pop(),
        ),
      );
    }
  }
  if (context.mounted) ref.invalidate(locationAccessProvider);
}

/// Where Chrome and Safari keep a site's location permission, one row each.
class _BrowserSteps extends StatelessWidget {
  const _BrowserSteps();

  static const _steps = [
    ('Chrome', '주소창 왼쪽 사이트 정보 → 사이트 설정 → 위치에서 변경해 주세요.'),
    ('Safari', '웹사이트 설정의 위치 항목에서 변경해 주세요.'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (browser, step)) in _steps.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
            // Read as one sentence: "Chrome, 주소창 왼쪽 …".
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      browser,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _keepWords(step),
                      semanticsLabel: step,
                      style: const TextStyle(
                        color: AppColors.textBody,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Joins the letters of each word so Korean wraps between words only.
  /// KeepAllText does this by measuring, which a dialog cannot host.
  static String _keepWords(String text) =>
      text.split(' ').map((word) => word.characters.join('\u2060')).join(' ');
}

class DevicePermissionService {
  bool get web => kIsWeb;
  bool get supportsPush =>
      !web &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<DeviceAccess> location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return DeviceAccess.serviceOff;
      }
      return _location(await Geolocator.checkPermission());
    } catch (_) {
      return DeviceAccess.unknown;
    }
  }

  Future<DeviceAccess> requestLocation() async {
    try {
      return _location(await Geolocator.requestPermission());
    } catch (_) {
      return DeviceAccess.unknown;
    }
  }

  DeviceAccess _location(LocationPermission permission) => switch (permission) {
    LocationPermission.always ||
    LocationPermission.whileInUse => DeviceAccess.allowed,
    LocationPermission.denied => DeviceAccess.denied,
    LocationPermission.deniedForever => DeviceAccess.blocked,
    LocationPermission.unableToDetermine => DeviceAccess.unknown,
  };

  Future<DeviceAccess> push() async {
    if (!supportsPush) return DeviceAccess.unsupported;
    try {
      final status = await permissions.Permission.notification.status;
      if (status.isGranted || status.isProvisional) return DeviceAccess.allowed;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return DeviceAccess.blocked;
      }
      return DeviceAccess.denied;
    } catch (_) {
      return DeviceAccess.unknown;
    }
  }

  Future<bool> openSettings({bool locationService = false}) async {
    if (web) return false;
    try {
      if (locationService && await Geolocator.openLocationSettings()) {
        return true;
      }
      return permissions.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

final devicePermissionServiceProvider = Provider(
  (_) => DevicePermissionService(),
);
final locationAccessProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(devicePermissionServiceProvider).location(),
);
final pushAccessProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(devicePermissionServiceProvider).push(),
);

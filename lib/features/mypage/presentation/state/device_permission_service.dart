import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 관리'),
        content: const Text(
          'Chrome: 주소창 왼쪽 사이트 정보 → 사이트 설정 → 위치에서 변경해 주세요.\n\n'
          'Safari: 웹사이트 설정의 위치 항목에서 변경해 주세요.\n\n'
          '웹사이트가 권한을 직접 해제할 수는 없어요. 변경 후 돌아와 권한을 다시 확인해 주세요.',
        ),
        actions: [
          if (access == DeviceAccess.denied)
            TextButton(
              onPressed: () async {
                await service.requestLocation();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('위치 사용 허용 요청'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('권한 다시 확인'),
          ),
        ],
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
        builder: (context) => AlertDialog(
          title: const Text('기기 설정에서 변경해 주세요'),
          content: const Text('기기 설정 → 얼마고 → 위치 권한에서 허용 여부를 변경할 수 있어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    }
  }
  if (context.mounted) ref.invalidate(locationAccessProvider);
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

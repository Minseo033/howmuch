import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

enum DeviceAccess { allowed, denied, blocked, serviceOff, unsupported, unknown }

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

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PermissionSettings {
  const PermissionSettings({
    required this.location,
    required this.notification,
    required this.marketing,
  });

  final bool location;
  final bool notification;
  final bool marketing;

  PermissionSettings copyWith({
    bool? location,
    bool? notification,
    bool? marketing,
  }) {
    return PermissionSettings(
      location: location ?? this.location,
      notification: notification ?? this.notification,
      marketing: marketing ?? this.marketing,
    );
  }
}

final permissionSettingsProvider = StateProvider<PermissionSettings>(
  (ref) => const PermissionSettings(
    location: true,
    notification: true,
    marketing: false,
  ),
);

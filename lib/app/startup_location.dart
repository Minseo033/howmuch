import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';

/// Screens of the splash, onboarding, terms, login and sign-up flow. A
/// requested address waits while the visitor is on one of these.
const Set<String> _startupPaths = {
  AppRoutes.root,
  AppRoutes.splash,
  AppRoutes.onboardingNearby,
  AppRoutes.onboardingSavingsReport,
  AppRoutes.onboardingStoreReport,
  AppRoutes.authTerms,
  AppRoutes.login,
  AppRoutes.permissionSetup,
  AppRoutes.profileSetup,
  '/oauth',
  '/oauth_loading',
};

bool isStartupPath(String path) => _startupPaths.contains(path);

/// Reopenable addresses that only make sense with an account.
const Set<String> _accountOnlyPaths = {
  AppRoutes.myReportsV2,
  AppRoutes.reportDetailV2,
  AppRoutes.accountManagement,
};

/// Where a guest lands for a [location] taken from [StartupLocation]: MY,
/// which offers login, instead of a screen that needs an account.
String guestStartupLocation(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  return _accountOnlyPaths.contains(path) ? AppRoutes.mypage : location;
}

/// Addresses that reopen the same screen after a reload: the bottom tabs and
/// the screens the app itself opens with `go`, so they can be in the address
/// bar. Each goes back on its own when nothing is beneath it.
const Set<String> _reopenablePaths = {
  AppRoutes.home,
  AppRoutes.communityFeed,
  AppRoutes.mypage,
  AppRoutes.savingsReportDashboard,
  AppRoutes.notifications,
  AppRoutes.myReportsV2,
  AppRoutes.accountManagement,
  AppRoutes.notificationSettings,
};

/// Where a reloaded or typed web address should land once the session is
/// known, or null for home.
///
/// Other screens below a tab (pushed screens keep the tab's address) return
/// to that tab, and screens that need data from the previous screen, such as
/// store detail, return home. Unknown addresses also return home.
String? reopenableStartupLocation(String? requested) {
  final uri = requested == null ? null : Uri.tryParse(requested);
  if (uri == null) return null;
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (_reopenablePaths.contains(path)) return path;
  if (path == AppRoutes.reportDetailV2) {
    final id = uri.queryParameters['id']?.trim() ?? '';
    return id.isEmpty
        ? AppRoutes.myReportsV2
        : Uri(path: path, queryParameters: {'id': id}).toString();
  }
  if (path.startsWith('${AppRoutes.mypage}/')) return AppRoutes.mypage;
  if (path.startsWith('${AppRoutes.communityFeed}/')) {
    return AppRoutes.communityFeed;
  }
  if (path.startsWith('/savings/')) return AppRoutes.savingsReportDashboard;
  return null;
}

/// The address a web visitor opened before the splash checked the session
/// (QA 10/7 #8). The startup flow opens it once, after the session check or
/// after login, instead of always opening home.
class StartupLocation {
  StartupLocation(String? requested)
    : _pending = reopenableStartupLocation(requested);

  String? _pending;

  String? get pending => _pending;

  /// The requested address the first time, home afterwards.
  String take() {
    final location = _pending ?? AppRoutes.home;
    _pending = null;
    return location;
  }

  /// Reaching another screen first, such as browsing without login, ends the
  /// request so a later login does not jump to it.
  void clear() => _pending = null;
}

/// Created together with the router, before the router replaces the
/// browser address with the splash address.
final startupLocationProvider = Provider<StartupLocation>((ref) {
  return StartupLocation(
    WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );
});

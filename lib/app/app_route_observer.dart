import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouteObserverProvider = Provider<RouteObserver<PageRoute<dynamic>>>(
  (ref) => RouteObserver<PageRoute<dynamic>>(),
);

/// Follows the root navigator for overlays drawn above it, such as the web
/// unread banner: whether a dialog or sheet is open, and when the page
/// changes (QA 10/7 #21).
class AppNavigationTracker extends NavigatorObserver with ChangeNotifier {
  final Set<Route<dynamic>> _popups = {};
  int _pageChanges = 0;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Whether a dialog, bottom sheet or menu is open.
  bool get hasPopup => _popups.isNotEmpty;

  /// Grows whenever a page is pushed, popped, removed or replaced.
  int get pageChanges => _pageChanges;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      // The first page is where the user arrives, not a move between pages.
      _added(route, countsAsPageChange: previousRoute != null);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _removed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _removed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _removed(oldRoute);
    if (newRoute != null) _added(newRoute);
  }

  void _added(Route<dynamic> route, {bool countsAsPageChange = true}) {
    if (route is PopupRoute) {
      _popups.add(route);
    } else if (route is PageRoute && countsAsPageChange) {
      _pageChanges++;
    } else {
      return;
    }
    _changed();
  }

  void _removed(Route<dynamic> route) {
    if (!_popups.remove(route)) {
      if (route is! PageRoute) return;
      _pageChanges++;
    }
    _changed();
  }

  // The router updates its pages while the tree builds. Listeners rebuild
  // widgets above the navigator, so they hear about it after that frame.
  void _changed() {
    if (_disposed) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduler.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final appNavigationTrackerProvider = Provider<AppNavigationTracker>((ref) {
  final tracker = AppNavigationTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
});

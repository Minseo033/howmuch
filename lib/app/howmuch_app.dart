import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_routes.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'widgets/web_notification_prompt.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';

class CustomWebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class HowmuchApp extends ConsumerStatefulWidget {
  const HowmuchApp({super.key});

  @override
  ConsumerState<HowmuchApp> createState() => _HowmuchAppState();
}

class _HowmuchAppState extends ConsumerState<HowmuchApp>
    with WidgetsBindingObserver {
  ProviderSubscription<AuthState>? _authListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiClient.setSessionExpiredHandler(() async {
      await ref
          .read(kakaoLoginServiceProvider)
          .clearLocalSession(unregisterDevice: false);
      ref.read(appRouterProvider).go(AppRoutes.sessionExpired);
    });
    _authListener = ref.listenManual<AuthState>(authStateProvider, (
      previous,
      next,
    ) {
      if (next.isLoggedIn) {
        ref.read(pushNotificationServiceProvider).registerForCurrentSession();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiClient.setSessionExpiredHandler(null);
    _authListener?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!ref.read(authStateProvider).isLoggedIn) return;
    ref.read(notificationsProvider.notifier).loadNotifications(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: '얼마고?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: CustomWebScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        final currentPath = router.routerDelegate.currentConfiguration.uri.path;
        final isHome =
            currentPath == AppRoutes.home || currentPath == AppRoutes.homeAiFab;
        return WebNotificationPrompt(
          onOpenNotifications: () => router.go(AppRoutes.notifications),
          isHome: isHome,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'app_routes.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'widgets/web_notification_prompt.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
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

class _HowmuchAppState extends ConsumerState<HowmuchApp> {
  ProviderSubscription<AuthState>? _authListener;

  @override
  void initState() {
    super.initState();
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
    _authListener?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    MCPToolkitBinding.instance.navigatorKey =
        router.routerDelegate.navigatorKey;

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

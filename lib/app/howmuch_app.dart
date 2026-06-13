import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'app_theme.dart';

class CustomWebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class HowmuchApp extends ConsumerWidget {
  const HowmuchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '얼마고?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: CustomWebScrollBehavior(),
      routerConfig: router,
    );
  }
}

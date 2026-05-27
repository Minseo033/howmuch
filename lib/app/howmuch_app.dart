import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screen_catalog_screen.dart';

class HowmuchApp extends StatelessWidget {
  const HowmuchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '얼마고?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ScreenCatalogScreen(),
    );
  }
}

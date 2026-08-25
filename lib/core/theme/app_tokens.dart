import 'package:flutter/material.dart';

/// Shared visual primitives for the HowMuch product surfaces.
///
/// Keep feature-specific values close to their feature. Values promoted here
/// must be reused across multiple screens or represent a product-wide rule.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
}

abstract final class AppRadii {
  static const double input = 10;
  static const double button = 12;
  static const double card = 16;
  static const double overlay = 20;
  static const double pill = 999;
}

abstract final class AppSizes {
  static const double minimumTouchTarget = 48;
  static const double compactTouchTarget = 44;
  static const double bottomNavItemWidth = 60;
}

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Curve standard = Curves.easeOutCubic;
}

abstract final class AppElevation {
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140F172A), blurRadius: 28, offset: Offset(0, 14)),
  ];
}

/// Semantic overlay order. Flutter widgets usually express this structurally,
/// but named values keep custom Stack implementations consistent.
abstract final class AppLayer {
  static const double base = 0;
  static const double raised = 1;
  static const double floating = 10;
  static const double modal = 20;
  static const double toast = 30;
}

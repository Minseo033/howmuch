import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Low-saturation woodland palette: calm over long sessions while retaining
  // the warmth and trust expected from a neighbourhood savings service.
  static const Color primary = Color(0xFF315F52);
  static const Color primaryPressed = Color(0xFF274C42);
  static const Color lime = Color(0xFFAABF96);
  static const Color cream = Color(0xFFF7F5EE);
  static const Color primaryLight = Color(0xFFE7EEE7);
  static const Color primaryAlpha = Color(0x22315F52);
  static const Color primarySubtle = Color(0xFFEEF2EC);

  // Text-capable status tokens meet WCAG AA contrast on white backgrounds.
  static const Color success = Color(0xFF39705C);
  static const Color successLight = Color(0xFFE7F0E8);
  static const Color successSubtle = Color(0xFFEEF5EF);

  static const Color warning = Color(0xFF9B6541);
  static const Color warningLight = Color(0xFFF6EDE4);
  static const Color warningDark = Color(0xFF7A4D30);
  static const Color warningBorder = Color(0xFFE7CDAF);

  static const Color error = Color(0xFFA64B4B);
  static const Color errorLight = Color(0xFFF8EAEA);
  static const Color errorAlpha = Color(0x26A64B4B);

  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoBrown = Color(0xFF191600);
  static const Color naverGreen = Color(0xFF03C75A);

  static const Color star = Color(0xFFFFC107);
  static const Color starAlt = Color(0xFFF59E0B);

  static const Color orangeTheme = Color(0xFFA76546);
  static const Color orangeLight = warningLight;
  static const Color tealLight = Color(0xFFE0EBE1);

  static const Color ink = Color(0xFF1F342D);
  static const Color textDark = Color(0xFF2C443A);
  static const Color textBody = Color(0xFF46564D);
  static const Color textMuted = Color(0xFF707A70);
  static const Color textLight = Color(0xFF707A70);

  static const Color black = ink;
  static const Color muted = Color(0xFF707A70);
  static const Color disabled = Color(0xFFA8AEA4);
  static const Color disabledSurface = Color(0xFFD9DDD2);
  static const Color border = Color(0xFFD9DDD2);
  static const Color borderLight = Color(0xFFE7E9E1);
  static const Color borderMedium = Color(0xFFC9D0C5);
  static const Color borderSubtle = Color(0xFFF0F1EB);

  static const Color surface = cream;
  static const Color background = Color(0xFFF0F0E9);
  static const Color backgroundLight = Color(0xFFF5F3EC);
  static const Color backgroundDark = Color(0xFFFBFAF5);
  static const Color bgLight = backgroundDark;

  static const Color white = Color(0xFFFFFDF8);
  static const Color transparent = Colors.transparent;

  // Semantic surface and content roles. New shared components should prefer
  // these names over feature-local raw colors.
  static const Color surfaceCanvas = surface;
  static const Color surfaceRaised = white;
  static const Color surfaceOverlay = white;
  static const Color surfaceSunken = background;
  static const Color textPrimary = ink;
  static const Color textSecondary = muted;
  static const Color textDisabled = disabled;
  static const Color accent = primary;
  static const Color reportAccent = orangeTheme;
  static const Color focus = Color(0xFF527A6C);
  static const Color modalScrim = Color(0x6B1F342D);
}

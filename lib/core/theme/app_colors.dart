import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Low-saturation woodland palette: calm over long sessions while retaining
  // the warmth and trust expected from a neighbourhood savings service.
  static const Color primary = Color(0xFF359A6B);
  static const Color primaryPressed = Color(0xFF287D55);
  static const Color lime = Color(0xFFC7DFAA);
  static const Color cream = Color(0xFFFCFBF7);
  static const Color primaryLight = Color(0xFFDDF4E5);
  static const Color primaryAlpha = Color(0x22359A6B);
  static const Color primarySubtle = Color(0xFFF1FAF4);

  // Text-capable status tokens meet WCAG AA contrast on white backgrounds.
  static const Color success = Color(0xFF4D9D75);
  static const Color successLight = Color(0xFFE5F7EB);
  static const Color successSubtle = Color(0xFFF1FBF5);

  static const Color warning = Color(0xFFB97852);
  static const Color warningLight = Color(0xFFFCF1EA);
  static const Color warningDark = Color(0xFF925B3C);
  static const Color warningBorder = Color(0xFFF0D7C3);

  static const Color error = Color(0xFFC05A5A);
  static const Color errorLight = Color(0xFFFCEDEE);
  static const Color errorAlpha = Color(0x26C05A5A);

  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoBrown = Color(0xFF191600);
  static const Color naverGreen = Color(0xFF03C75A);

  static const Color star = Color(0xFFFFC107);
  static const Color starAlt = Color(0xFFF59E0B);

  static const Color orangeTheme = Color(0xFFC47A53);
  static const Color orangeLight = warningLight;
  static const Color tealLight = Color(0xFFE5F5EA);

  static const Color ink = Color(0xFF243E35);
  static const Color textDark = Color(0xFF304B40);
  static const Color textBody = Color(0xFF53645B);
  static const Color textMuted = Color(0xFF748078);
  static const Color textLight = Color(0xFF748078);

  static const Color black = ink;
  static const Color muted = Color(0xFF748078);
  static const Color disabled = Color(0xFFAAB3AA);
  static const Color disabledSurface = Color(0xFFD8E7DB);
  static const Color border = Color(0xFFD8E7DB);
  static const Color borderLight = Color(0xFFE8F0E9);
  static const Color borderMedium = Color(0xFFC9DDCE);
  static const Color borderSubtle = Color(0xFFF3F7F3);

  static const Color surface = cream;
  static const Color background = Color(0xFFF6F7F2);
  static const Color backgroundLight = Color(0xFFFAFAF6);
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
  static const Color focus = Color(0xFF65B489);
  static const Color modalScrim = Color(0x6B243E35);
}

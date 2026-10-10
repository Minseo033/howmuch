import 'package:flutter/material.dart';

import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.lime,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      outlineVariant: AppColors.border,
      // Stock Material parts (dialogs, menus, sheets, selected chips, check
      // boxes) read these roles. Left to the seed they come out lavender,
      // which is what made untouched parts look like a default Android app.
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.borderMedium,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.white,
      surfaceContainer: AppColors.white,
      surfaceContainerHigh: AppColors.white,
      surfaceContainerHighest: AppColors.background,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryPressed,
      secondaryContainer: AppColors.primaryLight,
      onSecondaryContainer: AppColors.primaryPressed,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Noto Sans KR',
      fontFamilyFallback: const [
        'Noto Sans KR',
        'Apple SD Gothic Neo',
        'AppleGothic',
        'Malgun Gothic',
        'Arial Unicode MS',
        'sans-serif',
      ],
      scaffoldBackgroundColor: AppColors.surface,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textBody,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textBody,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.5,
        ),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        hoverColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          hoverColor: AppColors.primaryLight,
          highlightColor: AppColors.primaryLight,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minimumTouchTarget),
          disabledBackgroundColor: AppColors.disabledSurface,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minimumTouchTarget),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.disabledSurface,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minimumTouchTarget),
          side: const BorderSide(color: AppColors.borderMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.compactTouchTarget,
            AppSizes.compactTouchTarget,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Noto Sans KR',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        backgroundColor: AppColors.white,
        selectedColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.border),
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const BorderSide(color: Colors.transparent, width: 0)
              : const BorderSide(color: AppColors.borderMedium, width: 1.5),
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.selected)) return AppColors.white;
          return states.contains(WidgetState.disabled)
              ? AppColors.disabled
              : AppColors.primary;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        modalBackgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.disabled,
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.overlay),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.overlay),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.ink,
          fontFamily: 'Noto Sans KR',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.muted,
          fontFamily: 'Noto Sans KR',
          fontSize: 14,
          height: 1.6,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: const Color(0x330F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          color: AppColors.textBody,
          fontFamily: 'Noto Sans KR',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: AppColors.white,
          fontFamily: 'Noto Sans KR',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight,
        refreshBackgroundColor: AppColors.white,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // Fallback styling for third-party or not-yet-migrated snack bars.
      // Product code uses HowmuchSnackBar for semantic icons and hierarchy.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceOverlay,
        contentTextStyle: const TextStyle(
          color: AppColors.textBody,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.overlay),
          side: const BorderSide(color: AppColors.border),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        closeIconColor: AppColors.textSecondary,
        // Product snack bars provide their own labeled 44px dismiss control.
        // Keep the fallback off to avoid a duplicate close button.
        showCloseIcon: false,
      ),
    );
  }
}

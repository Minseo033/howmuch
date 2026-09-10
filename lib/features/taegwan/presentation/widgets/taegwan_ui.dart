import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

class TaegwanColors {
  const TaegwanColors._();

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF4F6FA);
  static const softBlue = Color(0xFFEFF6FF);
  static const softOrange = Color(0xFFFFF7ED);
  static const softGreen = Color(0xFFE8F8F1);
}

class TaegwanText {
  const TaegwanText._();

  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];
}

class TaegwanAppFrame extends StatelessWidget {
  const TaegwanAppFrame({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.showBack = false,
    this.currentTab,
    this.backgroundColor = TaegwanColors.surface,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool showBack;
  final String? currentTab;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomNavHeight = currentTab == null
        ? safePadding.bottom + 24
        : HowmuchBottomNav.heightFor(safePadding.bottom);

    void goBack() {
      if (context.canPop()) {
        context.pop();
      }
    }

    return FigmaMobileCanvas(
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 56 + topOffset,
            child: _Header(
              title: title,
              topOffset: topOffset,
              trailing: trailing,
              showBack: showBack,
              onBack: goBack,
            ),
          ),
          Positioned(
            left: 0,
            top: 56 + topOffset,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomNavHeight),
              child: child,
            ),
          ),
          if (currentTab != null)
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              height: bottomNavHeight,
              child: HowmuchBottomNav(
                safeBottom: safePadding.bottom,
                activeTab: _bottomTabFor(currentTab!),
              ),
            ),
        ],
      ),
    );
  }

  HowmuchBottomTab _bottomTabFor(String tab) {
    return switch (tab) {
      'home' => HowmuchBottomTab.home,
      'explore' => HowmuchBottomTab.explore,
      'savings' => HowmuchBottomTab.savings,
      'mypage' => HowmuchBottomTab.mypage,
      _ => HowmuchBottomTab.home,
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.topOffset,
    required this.showBack,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final double topOffset;
  final bool showBack;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TaegwanColors.border)),
      ),
      child: Stack(
        children: [
          if (showBack)
            Positioned(
              left: 8,
              top: topOffset + 6,
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
                color: TaegwanColors.ink,
              ),
            ),
          Positioned(
            left: showBack ? 52 : 20,
            top: topOffset + 15,
            child: Text(
              title,
              style: const TextStyle(
                color: TaegwanColors.ink,
                fontFamily: TaegwanText.fontFamily,
                fontFamilyFallback: TaegwanText.fontFallback,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          if (trailing != null)
            Positioned(right: 16, top: topOffset + 8, child: trailing!),
        ],
      ),
    );
  }
}

class TaegwanChip extends StatelessWidget {
  const TaegwanChip({
    super.key,
    required this.label,
    this.color = TaegwanColors.blue,
    this.backgroundColor = TaegwanColors.softBlue,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: TaegwanText.fontFamily,
          fontFamilyFallback: TaegwanText.fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}

class TaegwanPrimaryButton extends StatelessWidget {
  const TaegwanPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = TaegwanColors.blue,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: TaegwanText.fontFamily,
                fontFamilyFallback: TaegwanText.fontFallback,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';

class HowmuchTopBar extends StatelessWidget {
  const HowmuchTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailingIcon,
    this.onTrailingTap,
    this.showBorder = true,
    this.titleFontSize = 16,
  });

  static const double height = 48.878;
  static const double actionSize = 48.0;
  static const double iconSize = 22.0;

  final String title;
  final VoidCallback? onBack;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final bool showBorder;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showBorder
            ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
            : null,
      ),
      child: Stack(
        children: [
          if (onBack != null)
            Positioned(
              left: AppSizes.horizontalPadding - 12,
              top: 0,
              width: actionSize,
              height: height,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: iconSize,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF0A0A0A),
                fontFamily: 'Inter',
                fontFamilyFallback: const [
                  'Noto Sans KR',
                  'Apple SD Gothic Neo',
                  'AppleGothic',
                  'Arial Unicode MS',
                  'Malgun Gothic',
                  'sans-serif',
                ],
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          if (trailingIcon != null)
            Positioned(
              right: AppSizes.horizontalPadding - 12,
              top: 0,
              width: actionSize,
              height: height,
              child: IconButton(
                onPressed: onTrailingTap,
                icon: Icon(
                  trailingIcon,
                  size: iconSize,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

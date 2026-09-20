import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';

enum HowmuchBottomTab { home, explore, report, savings, mypage }

class HowmuchBottomNav extends StatelessWidget {
  const HowmuchBottomNav({
    super.key,
    required this.safeBottom,
    this.activeTab = HowmuchBottomTab.home,
  });

  static const blue = AppColors.primary;
  static const orange = AppColors.orangeTheme;
  static const hint = Color(0xFFAAB3AA);
  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  static const designHeight = 81.98863220214844;
  static const contentHeight = 60.002838134765625;
  static const designBottomReserve = designHeight - contentHeight;
  static const contentLift = 0.0; // Removed the 32.0 compensation hack

  static double heightFor(double safeBottom) {
    return contentHeight + (safeBottom > 8.0 ? safeBottom : 8.0) + contentLift;
  }

  final double safeBottom;
  final HowmuchBottomTab activeTab;

  @override
  Widget build(BuildContext context) {
    final bottomReserve = safeBottom > 8.0 ? safeBottom : 8.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomReserve + contentLift,
            height: contentHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: .94),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x241F342D),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.home_outlined,
                            label: '홈',
                            active: activeTab == HowmuchBottomTab.home,
                            onTap: () => context.go(AppRoutes.home),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.explore_outlined,
                            label: '탐색',
                            active: activeTab == HowmuchBottomTab.explore,
                            onTap: () => context.go(AppRoutes.communityFeed),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.add_rounded,
                            label: '제보',
                            active: activeTab == HowmuchBottomTab.report,
                            onTap: () => context.push(AppRoutes.reportCreate),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.bar_chart_rounded,
                            label: '리포트',
                            active: activeTab == HowmuchBottomTab.savings,
                            onTap: () =>
                                context.go(AppRoutes.savingsReportDashboard),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.person_outline_rounded,
                            label: 'MY',
                            active: activeTab == HowmuchBottomTab.mypage,
                            onTap: () => context.go(AppRoutes.mypage),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? HowmuchBottomNav.blue : HowmuchBottomNav.hint;

    return Semantics(
      button: true,
      selected: active,
      label: '$label 탭',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: 54,
            height: 50,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: .13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: active
                  ? Border.all(color: AppColors.white.withValues(alpha: .9))
                  : null,
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x18315F52),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: HowmuchBottomNav.fontFamily,
                    fontFamilyFallback: HowmuchBottomNav.fontFallback,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

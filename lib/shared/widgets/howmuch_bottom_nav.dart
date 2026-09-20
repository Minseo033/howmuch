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
  static const hint = Color(0xFFA8AEA4);
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
      color: AppColors.cream,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(
            top: BorderSide(color: Color(0xFFD9DDD2), width: .909),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomReserve + contentLift,
              height: contentHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      label: '홈',
                      active: activeTab == HowmuchBottomTab.home,
                      onTap: () => context.go(AppRoutes.home),
                    ),
                    _NavItem(
                      icon: Icons.explore_outlined,
                      label: '탐색',
                      active: activeTab == HowmuchBottomTab.explore,
                      onTap: () => context.go(AppRoutes.communityFeed),
                    ),
                    _ReportNavItem(
                      active: activeTab == HowmuchBottomTab.report,
                    ),
                    _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: '리포트',
                      active: activeTab == HowmuchBottomTab.savings,
                      onTap: () => context.go(AppRoutes.savingsReportDashboard),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: '마이',
                      active: activeTab == HowmuchBottomTab.mypage,
                      onTap: () => context.go(AppRoutes.mypage),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        radius: 30,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: SizedBox(
          width: AppSizes.bottomNavItemWidth,
          height: 54,
          child: Column(
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Icon(
                  icon,
                  color: active ? AppColors.lime : color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
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
    );
  }
}

class _ReportNavItem extends StatelessWidget {
  const _ReportNavItem({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final labelColor = active ? HowmuchBottomNav.orange : HowmuchBottomNav.hint;

    return Semantics(
      button: true,
      selected: active,
      label: '제보 탭',
      child: InkResponse(
        onTap: () => context.push(AppRoutes.reportCreate),
        radius: 30,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: SizedBox(
          width: AppSizes.bottomNavItemWidth,
          height: 50.002838134765625,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                child: Container(
                  width: 40,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x16245846),
                        blurRadius: 5,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
              ),
              Positioned(
                top: 39,
                child: Text(
                  '제보',
                  style: TextStyle(
                    color: labelColor,
                    fontFamily: HowmuchBottomNav.fontFamily,
                    fontFamilyFallback: HowmuchBottomNav.fontFallback,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

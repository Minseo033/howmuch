import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';

enum HowmuchBottomTab { home, explore, report, savings, mypage }

class HowmuchBottomNav extends StatelessWidget {
  const HowmuchBottomNav({
    super.key,
    required this.safeBottom,
    this.activeTab = HowmuchBottomTab.home,
  });

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const hint = Color(0xFF94A3B8);
  static const fontFamily = 'Inter';
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
  static const contentLift = 32.0;

  static double heightFor(double safeBottom) {
    return contentHeight +
        (safeBottom > designBottomReserve ? safeBottom : designBottomReserve) +
        contentLift;
  }

  final double safeBottom;
  final HowmuchBottomTab activeTab;

  @override
  Widget build(BuildContext context) {
    final bottomReserve = safeBottom > designBottomReserve
        ? safeBottom
        : designBottomReserve;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: .909)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomReserve + contentLift,
            height: contentHeight,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 7.5426025390625,
                right: 7.571,
                top: 10,
              ),
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
                  _ReportNavItem(active: activeTab == HowmuchBottomTab.report),
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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 50.002838134765625,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5.994326591491699),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: HowmuchBottomNav.fontFamily,
                fontFamilyFallback: HowmuchBottomNav.fontFallback,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
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

    return GestureDetector(
      onTap: () => context.push(AppRoutes.reportCreate),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 50.002838134765625,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -13.991455078125,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: HowmuchBottomNav.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x47F97316),
                      blurRadius: 5,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ),
            Positioned(
              top: 32.0028076171875,
              child: Text(
                '제보',
                style: TextStyle(
                  color: labelColor,
                  fontFamily: HowmuchBottomNav.fontFamily,
                  fontFamilyFallback: HowmuchBottomNav.fontFallback,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

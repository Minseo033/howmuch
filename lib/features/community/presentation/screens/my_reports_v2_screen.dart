import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

enum _ReportFilter { all, pending, approved, needsEdit, rejected }

class MyReportsV2Screen extends StatefulWidget {
  const MyReportsV2Screen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF4F6FA);
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  State<MyReportsV2Screen> createState() => _MyReportsV2ScreenState();
}

class _MyReportsV2ScreenState extends State<MyReportsV2Screen> {
  _ReportFilter _filter = _ReportFilter.all;

  List<_MyReportData> get _visibleReports {
    if (_filter == _ReportFilter.all) {
      return _reports;
    }
    return _reports.where((report) => report.filter == _filter).toList();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomNavHeight = HowmuchBottomNav.heightFor(safePadding.bottom);

    return FigmaMobileCanvas(
      backgroundColor: MyReportsV2Screen.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: FigmaMobileCanvas.width,
            height: topOffset + 97.756,
            child: const ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: 0,
            top: topOffset,
            width: FigmaMobileCanvas.width,
            height: 48.878,
            child: _Header(
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(AppRoutes.reportComplete);
              },
              onSearch: () => _showSnack('내 제보 검색은 다음 단계에서 연결할게요.'),
            ),
          ),
          Positioned(
            left: 0,
            top: topOffset + 48.878,
            width: FigmaMobileCanvas.width,
            height: 48.878,
            child: _Tabs(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          ),
          Positioned(
            left: 0,
            top: topOffset + 97.756,
            width: FigmaMobileCanvas.width,
            height: FigmaMobileCanvas.height - topOffset - 97.756,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                15.994,
                20,
                bottomNavHeight + 24,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _SummaryCard(
                  onTap: () => setState(() => _filter = _ReportFilter.all),
                ),
                const SizedBox(height: 11.989),
                ..._visibleReports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportCard(
                      report: report,
                      onTap: () => context.push('${AppRoutes.reportDetailV2}?id=${report.id}'),
                      onPrimaryTap: () {
                        if (report.filter == _ReportFilter.approved) {
                          context.go(AppRoutes.home);
                          return;
                        }
                        if (report.filter == _ReportFilter.needsEdit) {
                          context.push(AppRoutes.reportCreate);
                          return;
                        }
                        context.push('${AppRoutes.reportDetailV2}?id=${report.id}');
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
            height: bottomNavHeight,
            child: HowmuchBottomNav(
              safeBottom: safePadding.bottom,
              activeTab: HowmuchBottomTab.report,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSearch});

  final VoidCallback onBack;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: MyReportsV2Screen.border, width: .909),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            width: 56,
            height: 48.878,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: MyReportsV2Screen.ink,
                size: 24,
              ),
            ),
          ),
          const Center(
            child: Text(
              '내 제보',
              style: TextStyle(
                color: MyReportsV2Screen.black,
                fontFamily: MyReportsV2Screen.fontFamily,
                fontFamilyFallback: MyReportsV2Screen.fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            width: 56,
            height: 48.878,
            child: IconButton(
              onPressed: onSearch,
              icon: const Icon(
                Icons.search_rounded,
                color: MyReportsV2Screen.ink,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final _ReportFilter selected;
  final ValueChanged<_ReportFilter> onChanged;

  static const _items = [
    (_ReportFilter.all, '전체', 3),
    (_ReportFilter.pending, '검토 중', 1),
    (_ReportFilter.approved, '승인 완료', 1),
    (_ReportFilter.needsEdit, '보완 요청', 1),
    (_ReportFilter.rejected, '반려', 0),
  ];

  @override
  Widget build(BuildContext context) {
    final tabWidth = FigmaMobileCanvas.width / _items.length;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: MyReportsV2Screen.border, width: .909),
        ),
      ),
      child: Row(
        children: [
          for (final item in _items)
            SizedBox(
              width: tabWidth,
              child: _TabButton(
                label: item.$2,
                count: item.$3,
                selected: selected == item.$1,
                onTap: () => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MyReportsV2Screen.blue : MyReportsV2Screen.muted;
    final countColor = selected ? MyReportsV2Screen.blue : MyReportsV2Screen.hint;

    return InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.02),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontFamily: MyReportsV2Screen.fontFamily,
                        fontFamilyFallback: MyReportsV2Screen.fontFallback,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      maxLines: 1,
                      style: TextStyle(
                        color: countColor,
                        fontFamily: MyReportsV2Screen.fontFamily,
                        fontFamilyFallback: MyReportsV2Screen.fontFallback,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 1.989,
                child: Center(
                  child: SizedBox(
                    width: 35.185,
                    height: 1.989,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: MyReportsV2Screen.blue,
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 68.48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment(-0.98, -0.2),
            end: Alignment(0.98, 1),
            colors: [Color(0xFFEFF4FF), Color(0xFFFFF3EA)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 13.99,
              top: 15.24,
              width: 37.997,
              height: 37.997,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: MyReportsV2Screen.blue,
                  size: 18,
                ),
              ),
            ),
            const Positioned(
              left: 63.98,
              top: 13.99,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '총 제보',
                    style: TextStyle(
                      color: MyReportsV2Screen.muted,
                      fontFamily: MyReportsV2Screen.fontFamily,
                      fontFamilyFallback: MyReportsV2Screen.fontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '3건 '),
                        TextSpan(
                          text: '승인 1건',
                          style: TextStyle(
                            color: MyReportsV2Screen.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: MyReportsV2Screen.black,
                      fontFamily: MyReportsV2Screen.fontFamily,
                      fontFamilyFallback: MyReportsV2Screen.fontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 14.99,
              top: 22.24,
              child: Icon(
                Icons.chevron_right_rounded,
                color: MyReportsV2Screen.muted,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    required this.onPrimaryTap,
  });

  final _MyReportData report;
  final VoidCallback onTap;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: report.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MyReportsV2Screen.border, width: .909),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 15.99,
                top: 15.99,
                child: _StatusBadge(report: report),
              ),
              Positioned(
                right: 17.82,
                top: 18.24,
                child: Text(
                  report.date,
                  style: const TextStyle(
                    color: MyReportsV2Screen.muted,
                    fontFamily: MyReportsV2Screen.fontFamily,
                    fontFamilyFallback: MyReportsV2Screen.fontFallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              Positioned(
                left: 15.99,
                top: 44.99,
                child: Text(
                  report.title,
                  style: const TextStyle(
                    color: MyReportsV2Screen.black,
                    fontFamily: MyReportsV2Screen.fontFamily,
                    fontFamilyFallback: MyReportsV2Screen.fontFallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              const Positioned(
                left: 15.99,
                top: 72.22,
                child: Text(
                  '대표 메뉴',
                  style: TextStyle(
                    color: MyReportsV2Screen.muted,
                    fontFamily: MyReportsV2Screen.fontFamily,
                    fontFamilyFallback: MyReportsV2Screen.fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              Positioned(
                right: 17.82,
                top: 71.48,
                child: Text(
                  report.menu,
                  style: const TextStyle(
                    color: MyReportsV2Screen.black,
                    fontFamily: MyReportsV2Screen.fontFamily,
                    fontFamilyFallback: MyReportsV2Screen.fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              if (report.notice != null)
                Positioned(
                  left: 15.99,
                  top: 98.96,
                  width: 301.648,
                  height: 31.378,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: MyReportsV2Screen.orange,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            report.notice!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontFamily: MyReportsV2Screen.fontFamily,
                              fontFamilyFallback: MyReportsV2Screen.fontFallback,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              if (report.actionLabel != null)
                Positioned(
                  right: 17.82,
                  top: report.actionTop,
                  width: report.actionWidth,
                  height: 33.991,
                  child: _SmallActionButton(
                    label: report.actionLabel!,
                    color: report.actionColor,
                    icon: report.actionIcon,
                    onTap: onPrimaryTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.report});

  final _MyReportData report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: report.badgeWidth,
      height: 20.994,
      decoration: BoxDecoration(
        color: report.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: report.badgeDotColor ?? report.badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            report.status,
            style: TextStyle(
              color: report.badgeTextColor ?? report.badgeColor,
              fontFamily: MyReportsV2Screen.fontFamily,
              fontFamilyFallback: MyReportsV2Screen.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: MyReportsV2Screen.fontFamily,
                fontFamilyFallback: MyReportsV2Screen.fontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyReportData {
  const _MyReportData({
    required this.id,
    required this.filter,
    required this.status,
    required this.date,
    required this.title,
    required this.menu,
    required this.badgeBackground,
    required this.badgeColor,
    this.badgeDotColor,
    this.badgeTextColor,
    required this.badgeWidth,
    required this.height,
    this.notice,
    this.actionLabel,
    this.actionColor = MyReportsV2Screen.blue,
    this.actionIcon = Icons.location_on_outlined,
    this.actionTop = 102.95,
    this.actionWidth = 120.185,
  });

  final String id;
  final _ReportFilter filter;
  final String status;
  final String date;
  final String title;
  final String menu;
  final Color badgeBackground;
  final Color badgeColor;
  final Color? badgeDotColor;
  final Color? badgeTextColor;
  final double badgeWidth;
  final double height;
  final String? notice;
  final String? actionLabel;
  final Color actionColor;
  final IconData actionIcon;
  final double actionTop;
  final double actionWidth;
}

const _reports = [
  _MyReportData(
    id: '1',
    filter: _ReportFilter.pending,
    status: '검토 중',
    date: '2026.05.12',
    title: '골목밥상',
    menu: '제육덮밥 6,000원',
    badgeBackground: Color(0xFFFEF3C7),
    badgeColor: Color(0xFF92400E),
    badgeWidth: 60.497,
    height: 108.778,
  ),
  _MyReportData(
    id: '2',
    filter: _ReportFilter.approved,
    status: '승인 완료',
    date: '2026.05.09',
    title: '동네카페',
    menu: '아메리카노 2,000원',
    badgeBackground: Color(0xFFE8F8F1),
    badgeColor: MyReportsV2Screen.green,
    badgeWidth: 70.497,
    height: 154.759,
    actionLabel: '지도에서 보기',
    actionColor: MyReportsV2Screen.blue,
    actionIcon: Icons.location_on_outlined,
  ),
  _MyReportData(
    id: '3',
    filter: _ReportFilter.needsEdit,
    status: '보완 요청',
    date: '2026.05.08',
    title: '착한김밥',
    menu: '김밥 2,500원',
    badgeBackground: Color(0xFFFEF3C7),
    badgeColor: MyReportsV2Screen.orange,
    badgeDotColor: Color(0xFFF59E0B),
    badgeTextColor: Color(0xFF92400E),
    badgeWidth: 70.497,
    height: 194.134,
    notice: '메뉴판 사진이 흐려 가격 확인이 어려워요',
    actionLabel: '수정하기',
    actionColor: MyReportsV2Screen.blue,
    actionIcon: Icons.edit_outlined,
    actionTop: 142.33,
    actionWidth: 120.185,
  ),
];

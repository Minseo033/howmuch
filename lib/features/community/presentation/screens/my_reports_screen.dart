import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

enum _ReportFilter { all, pending, approved, needsEdit, rejected }

class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key});

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
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  _ReportFilter _filter = _ReportFilter.all;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshReports);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshReports() async {
    final reports = await ref.read(reportServiceProvider).fetchMyReports();
    if (!mounted) return;
    if (reports == null) return;
    ref.read(userReportsProvider.notifier).mergeFetchedReports(reports);
  }

  String _formatReportDate(UserReportStatus report) {
    final parsed = DateTime.tryParse(report.createdAt);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  }

  List<_MyReportData> _getMappedReports(
    List<UserReportStatus> riverpodReports,
  ) {
    return riverpodReports.map((r) {
      _ReportFilter filter = _ReportFilter.all;
      if (r.status.contains('검토')) {
        filter = _ReportFilter.pending;
      } else if (r.status.contains('승인')) {
        filter = _ReportFilter.approved;
      } else if (r.status.contains('보완')) {
        filter = _ReportFilter.needsEdit;
      } else if (r.status.contains('반려')) {
        filter = _ReportFilter.rejected;
      }

      final notice =
          (filter == _ReportFilter.needsEdit ||
                  filter == _ReportFilter.rejected) &&
              r.rejectReason.trim().isNotEmpty
          ? r.rejectReason.trim()
          : null;

      double height = 108.778;
      if (filter == _ReportFilter.approved) {
        height = 154.759;
      } else if (filter == _ReportFilter.needsEdit) {
        height = 194.134;
      } else if (notice != null) {
        height = 144.134;
      }

      return _MyReportData(
        id: r.id,
        source: r,
        filter: filter,
        status: r.status,
        date: _formatReportDate(r),
        title: r.store,
        menu: r.menu,
        badgeBackground: Color(r.statusBg),
        badgeColor: Color(r.textColor),
        badgeWidth: 70.497,
        height: height,
        notice: notice,
        actionLabel: filter == _ReportFilter.approved
            ? '지도에서 보기'
            : (filter == _ReportFilter.needsEdit ? '수정하기' : null),
        actionColor: filter == _ReportFilter.needsEdit
            ? MyReportsScreen.orange
            : MyReportsScreen.blue,
        actionIcon: filter == _ReportFilter.needsEdit
            ? Icons.edit_outlined
            : Icons.location_on_outlined,
        actionTop: 142.33,
        actionWidth: 120.185,
      );
    }).toList();
  }

  List<_MyReportData> _visibleReports(List<UserReportStatus> riverpodReports) {
    final mapped = _getMappedReports(riverpodReports);
    final filtered = _filter == _ReportFilter.all
        ? mapped
        : mapped.where((r) => r.filter == _filter).toList();
    return filtered;
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

    final riverpodReports = ref.watch(userReportsProvider);
    final mappedReports = _getMappedReports(riverpodReports);
    final counts = <_ReportFilter, int>{
      _ReportFilter.all: mappedReports.length,
      _ReportFilter.pending: mappedReports
          .where((report) => report.filter == _ReportFilter.pending)
          .length,
      _ReportFilter.approved: mappedReports
          .where((report) => report.filter == _ReportFilter.approved)
          .length,
      _ReportFilter.needsEdit: mappedReports
          .where((report) => report.filter == _ReportFilter.needsEdit)
          .length,
      _ReportFilter.rejected: mappedReports
          .where((report) => report.filter == _ReportFilter.rejected)
          .length,
    };

    return FigmaMobileCanvas(
      backgroundColor: MyReportsScreen.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: topOffset + 97.756,
            child: const ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: 0,
            top: topOffset,
            right: 0,
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
            right: 0,
            height: 48.878,
            child: _Tabs(
              selected: _filter,
              counts: counts,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          ),
          Positioned(
            left: 0,
            top: topOffset + 97.756,
            right: 0,
            bottom: 0,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                15.994,
                20,
                bottomNavHeight + 24,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _SummaryCard(
                  totalCount: counts[_ReportFilter.all] ?? 0,
                  approvedCount: counts[_ReportFilter.approved] ?? 0,
                  onTap: () => setState(() => _filter = _ReportFilter.all),
                ),
                const SizedBox(height: 11.989),
                ..._visibleReports(riverpodReports).map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportCard(
                      report: report,
                      onTap: () => context.push(
                        '${AppRoutes.reportDetailV2}?id=${report.id}',
                        extra: report.source,
                      ),
                      onPrimaryTap: () {
                        if (report.filter == _ReportFilter.approved) {
                          context.go(AppRoutes.home);
                          return;
                        }
                        if (report.filter == _ReportFilter.needsEdit) {
                          context.push(
                            AppRoutes.reportCreate,
                            extra: report.source,
                          );
                          return;
                        }
                        context.push(
                          '${AppRoutes.reportDetailV2}?id=${report.id}',
                          extra: report.source,
                        );
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
            right: 0,
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
          bottom: BorderSide(color: MyReportsScreen.border, width: .909),
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
                color: MyReportsScreen.ink,
                size: 24,
              ),
            ),
          ),
          const Center(
            child: Text(
              '내 제보',
              style: TextStyle(
                color: MyReportsScreen.black,
                fontFamily: MyReportsScreen.fontFamily,
                fontFamilyFallback: MyReportsScreen.fontFallback,
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
                color: MyReportsScreen.ink,
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
  const _Tabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _ReportFilter selected;
  final Map<_ReportFilter, int> counts;
  final ValueChanged<_ReportFilter> onChanged;

  static const _items = [
    (_ReportFilter.all, '전체'),
    (_ReportFilter.pending, '검토 중'),
    (_ReportFilter.approved, '승인 완료'),
    (_ReportFilter.needsEdit, '보완 요청'),
    (_ReportFilter.rejected, '반려'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: MyReportsScreen.border, width: .909),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _items.length;
          return Row(
            children: [
              for (final item in _items)
                SizedBox(
                  width: tabWidth,
                  child: _TabButton(
                    label: item.$2,
                    count: counts[item.$1] ?? 0,
                    selected: selected == item.$1,
                    onTap: () => onChanged(item.$1),
                  ),
                ),
            ],
          );
        },
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
    final color = selected ? MyReportsScreen.blue : MyReportsScreen.muted;
    final countColor = selected ? MyReportsScreen.blue : MyReportsScreen.hint;

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
                        fontFamily: MyReportsScreen.fontFamily,
                        fontFamilyFallback: MyReportsScreen.fontFallback,
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
                        fontFamily: MyReportsScreen.fontFamily,
                        fontFamilyFallback: MyReportsScreen.fontFallback,
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
                        color: MyReportsScreen.blue,
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
  const _SummaryCard({
    required this.totalCount,
    required this.approvedCount,
    required this.onTap,
  });

  final int totalCount;
  final int approvedCount;
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
                  color: MyReportsScreen.blue,
                  size: 18,
                ),
              ),
            ),
            Positioned(
              left: 63.98,
              top: 13.99,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '총 제보',
                    style: const TextStyle(
                      color: MyReportsScreen.muted,
                      fontFamily: MyReportsScreen.fontFamily,
                      fontFamilyFallback: MyReportsScreen.fontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$totalCount건 '),
                        TextSpan(
                          text: '승인 $approvedCount건',
                          style: const TextStyle(
                            color: MyReportsScreen.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      color: MyReportsScreen.black,
                      fontFamily: MyReportsScreen.fontFamily,
                      fontFamilyFallback: MyReportsScreen.fontFallback,
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
                color: MyReportsScreen.muted,
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
            border: Border.all(color: MyReportsScreen.border, width: .909),
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
                    color: MyReportsScreen.muted,
                    fontFamily: MyReportsScreen.fontFamily,
                    fontFamilyFallback: MyReportsScreen.fontFallback,
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
                    color: MyReportsScreen.black,
                    fontFamily: MyReportsScreen.fontFamily,
                    fontFamilyFallback: MyReportsScreen.fontFallback,
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
                    color: MyReportsScreen.muted,
                    fontFamily: MyReportsScreen.fontFamily,
                    fontFamilyFallback: MyReportsScreen.fontFallback,
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
                    color: MyReportsScreen.black,
                    fontFamily: MyReportsScreen.fontFamily,
                    fontFamilyFallback: MyReportsScreen.fontFallback,
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
                        const SizedBox(width: AppSizes.smallSpacing),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: MyReportsScreen.orange,
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
                              fontFamily: MyReportsScreen.fontFamily,
                              fontFamilyFallback: MyReportsScreen.fontFallback,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.smallSpacing),
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
              color: report.badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            report.status,
            style: TextStyle(
              color: report.badgeColor,
              fontFamily: MyReportsScreen.fontFamily,
              fontFamilyFallback: MyReportsScreen.fontFallback,
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
                fontFamily: MyReportsScreen.fontFamily,
                fontFamilyFallback: MyReportsScreen.fontFallback,
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
    required this.source,
    required this.filter,
    required this.status,
    required this.date,
    required this.title,
    required this.menu,
    required this.badgeBackground,
    required this.badgeColor,
    required this.badgeWidth,
    required this.height,
    this.notice,
    this.actionLabel,
    this.actionColor = MyReportsScreen.blue,
    this.actionIcon = Icons.location_on_outlined,
    this.actionTop = 102.95,
    this.actionWidth = 120.185,
  });

  final String id;
  final UserReportStatus source;
  final _ReportFilter filter;
  final String status;
  final String date;
  final String title;
  final String menu;
  final Color badgeBackground;
  final Color badgeColor;
  final double badgeWidth;
  final double height;
  final String? notice;
  final String? actionLabel;
  final Color actionColor;
  final IconData actionIcon;
  final double actionTop;
  final double actionWidth;
}

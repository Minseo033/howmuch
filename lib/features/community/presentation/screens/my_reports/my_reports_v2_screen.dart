import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_all_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_pending_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_approved_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_needs_edit_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_rejected_tab.dart';

class MyReportsV2Screen extends ConsumerStatefulWidget {
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
  ConsumerState<MyReportsV2Screen> createState() => _MyReportsV2ScreenState();
}

class _MyReportsV2ScreenState extends ConsumerState<MyReportsV2Screen> {
  ReportFilter _filter = ReportFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshReports);
  }

  Future<void> _refreshReports() async {
    final reports = await ref.read(reportServiceProvider).fetchMyReports();
    if (!mounted) return;
    if (reports == null) return;
    ref.read(userReportsProvider.notifier).mergeFetchedReports(reports);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCurrentTab() {
    switch (_filter) {
      case ReportFilter.all:
        return const MyReportsAllTab();
      case ReportFilter.pending:
        return const MyReportsPendingTab();
      case ReportFilter.approved:
        return const MyReportsApprovedTab();
      case ReportFilter.needsEdit:
        return const MyReportsNeedsEditTab();
      case ReportFilter.rejected:
        return const MyReportsRejectedTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final reports = ref.watch(myReportDataProvider);
    final counts = <ReportFilter, int>{
      ReportFilter.all: reports.length,
      ReportFilter.pending: reports
          .where((report) => report.filter == ReportFilter.pending)
          .length,
      ReportFilter.approved: reports
          .where((report) => report.filter == ReportFilter.approved)
          .length,
      ReportFilter.needsEdit: reports
          .where((report) => report.filter == ReportFilter.needsEdit)
          .length,
      ReportFilter.rejected: reports
          .where((report) => report.filter == ReportFilter.rejected)
          .length,
    };

    return FigmaMobileCanvas(
      backgroundColor: MyReportsV2Screen.surface,
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
              filter: _filter,
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
              padding: EdgeInsets.fromLTRB(
                20,
                15.994,
                20,
                (safePadding.bottom > 0 ? safePadding.bottom + 68 : 88) + 44,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_buildCurrentTab()],
            ),
          ),

          if (_filter == ReportFilter.all)
            Positioned(
              left: 0,
              bottom: safePadding.bottom > 0 ? safePadding.bottom + 20 : 40,
              right: 0,
              height: 88,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: MyReportsV2Screen.border,
                      width: 0.909,
                    ),
                  ),
                ),
                child: Material(
                  color: MyReportsV2Screen.blue,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.reportCreate),
                    borderRadius: BorderRadius.circular(14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 4),
                        Text(
                          '새 제보 등록하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: MyReportsV2Screen.fontFamily,
                            fontFamilyFallback: MyReportsV2Screen.fontFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.onBack,
    required this.onSearch,
  });

  final ReportFilter filter;
  final VoidCallback onBack;
  final VoidCallback onSearch;

  String get _title {
    switch (filter) {
      case ReportFilter.all:
        return '내 제보 내역';
      case ReportFilter.pending:
        return '검토 중';
      case ReportFilter.approved:
        return '승인 완료';
      case ReportFilter.needsEdit:
        return '보완 요청';
      case ReportFilter.rejected:
        return '반려';
    }
  }

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
          Center(
            child: Text(
              _title,
              style: const TextStyle(
                color: MyReportsV2Screen.black,
                fontFamily: MyReportsV2Screen.fontFamily,
                fontFamilyFallback: MyReportsV2Screen.fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          if (filter == ReportFilter.all)
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
  const _Tabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final ReportFilter selected;
  final Map<ReportFilter, int> counts;
  final ValueChanged<ReportFilter> onChanged;

  static const _items = [
    (ReportFilter.all, '전체'),
    (ReportFilter.pending, '검토 중'),
    (ReportFilter.approved, '승인 완료'),
    (ReportFilter.needsEdit, '보완 요청'),
    (ReportFilter.rejected, '반려'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: MyReportsV2Screen.border, width: .909),
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
    final color = selected ? MyReportsV2Screen.blue : MyReportsV2Screen.muted;
    final countColor = selected
        ? MyReportsV2Screen.blue
        : MyReportsV2Screen.hint;

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

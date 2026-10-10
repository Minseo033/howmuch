import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_all_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_pending_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_approved_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_needs_edit_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_no_change_tab.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/tabs/my_reports_rejected_tab.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_action_bar.dart';

class MyReportsV2Screen extends ConsumerStatefulWidget {
  const MyReportsV2Screen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFFCBD5E1);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF4F6FA);
  static const fontFamily = 'Noto Sans KR';
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
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  // Starts as loading so an empty list does not flash before the first fetch.
  bool _loading = true;

  /// The refresh came from pulling the list, whose indicator already shows.
  bool _pulling = false;
  bool _loadFailed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetchReports);
  }

  Future<void> _refreshReports({bool pulled = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _pulling = pulled;
    });
    await _fetchReports();
  }

  Future<void> _fetchReports() async {
    final reports = await ref.read(reportServiceProvider).fetchMyReports();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _pulling = false;
      _loadFailed = reports == null;
    });
    if (reports != null) {
      ref.read(userReportsProvider.notifier).mergeFetchedReports(reports);
    }
  }

  Widget _buildCurrentTab() {
    switch (_filter) {
      case ReportFilter.all:
        return const MyReportsAllTab();
      case ReportFilter.pending:
        return const MyReportsPendingTab();
      case ReportFilter.approved:
        return const MyReportsApprovedTab();
      case ReportFilter.noChange:
        return const MyReportsNoChangeTab();
      case ReportFilter.needsEdit:
        return const MyReportsNeedsEditTab();
      case ReportFilter.rejected:
        return const MyReportsRejectedTab();
    }
  }

  /// What the list area shows when no report matches the tab and search.
  Widget _emptyListState() {
    if (_loading && !_pulling) return const _LoadingState();
    if (_loadFailed) {
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        title: '내 제보를 불러오지 못했어요.',
        message: '잠시 후 다시 시도해 주세요.',
        actionLabel: '다시 불러오기',
        onAction: _refreshReports,
      );
    }
    void showAll() => setState(() {
      _searchController.clear();
      _filter = ReportFilter.all;
    });
    if (_searchController.text.trim().isNotEmpty) {
      return _StateMessage(
        icon: Icons.search_off_rounded,
        title: '검색 결과가 없어요.',
        message: '다른 검색어를 입력해 주세요.',
        actionLabel: '전체 제보 보기',
        onAction: showAll,
      );
    }
    if (_filter != ReportFilter.all) {
      return _StateMessage(
        icon: Icons.inbox_outlined,
        title: '이 상태의 제보가 없어요.',
        message: '다른 상태의 제보를 확인해 보세요.',
        actionLabel: '전체 제보 보기',
        onAction: showAll,
      );
    }
    // The bar below already offers to write a new report.
    return const _StateMessage(
      icon: Icons.edit_note_rounded,
      title: '아직 등록한 제보가 없어요.',
      message: '동네의 좋은 가격 정보를 제보해 주세요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final topChromeHeight = HowmuchTopBar.height * 2 + (_searchOpen ? 72 : 0);
    final actionBarHeight = HowmuchBottomActionBar.heightFor(
      safePadding.bottom,
      contentHeight: 56,
    );
    final reports = ref
        .watch(myReportDataProvider)
        .where(
          (report) =>
              matchesMyReportQuery(report.source, _searchController.text),
        )
        .toList();
    final visibleCount = reports
        .where(
          (report) => _filter == ReportFilter.all || report.filter == _filter,
        )
        .length;
    final counts = <ReportFilter, int>{
      for (final filter in ReportFilter.values)
        filter: filter == ReportFilter.all
            ? reports.length
            : reports.where((report) => report.filter == filter).length,
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
            height: topOffset + topChromeHeight,
            child: const ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: 0,
            top: topOffset,
            right: 0,
            height: HowmuchTopBar.height,
            child: _Header(
              filter: _filter,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                // This screen can be opened directly from a deep link. In
                // that case there is no completion screen to return to;
                // return to the owning tab instead of replaying a submitted
                // report confirmation.
                context.go(AppRoutes.mypage);
              },
              onSearch: () => setState(() {
                _searchOpen = !_searchOpen;
                // 검색창을 닫으면 보이지 않는 검색어가 목록을 계속 거르지 않게 지웁니다.
                if (!_searchOpen) _searchController.clear();
              }),
            ),
          ),
          if (_searchOpen)
            Positioned(
              left: 20,
              right: 20,
              top: topOffset + HowmuchTopBar.height * 2 + 12,
              // Named for screen readers now that no floating label shows.
              child: Semantics(
                label: '내 제보 검색',
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: MyReportsV2Screen.ink,
                    fontFamily: MyReportsV2Screen.fontFamily,
                    fontFamilyFallback: MyReportsV2Screen.fontFallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '매장명, 주소, 메뉴, 신고 설명',
                    hintStyle: const TextStyle(
                      color: MyReportsV2Screen.muted,
                      fontFamily: MyReportsV2Screen.fontFamily,
                      fontFamilyFallback: MyReportsV2Screen.fontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: MyReportsV2Screen.muted,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            onPressed: () => setState(_searchController.clear),
                            icon: const Icon(
                              Icons.cancel_rounded,
                              size: 19,
                              color: AppColors.disabled,
                            ),
                          ),
                    // A cream field on the white strip, like the store search.
                    filled: true,
                    fillColor: MyReportsV2Screen.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: MyReportsV2Screen.blue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: topOffset + HowmuchTopBar.height,
            right: 0,
            height: HowmuchTopBar.height,
            child: _Tabs(
              selected: _filter,
              counts: counts,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          ),
          Positioned(
            left: 0,
            top: topOffset + topChromeHeight,
            right: 0,
            bottom: 0,
            // Pulling shows the refresh indicator only; a list already on
            // screen stays put while it refreshes.
            child: RefreshIndicator(
              onRefresh: () => _refreshReports(pulled: true),
              color: MyReportsV2Screen.blue,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = EdgeInsets.fromLTRB(
                    20,
                    15.994,
                    20,
                    actionBarHeight + 24,
                  );
                  return ListView(
                    padding: padding,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (visibleCount == 0)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - padding.vertical,
                            ),
                          ),
                          child: Center(child: _emptyListState()),
                        )
                      else ...[
                        if (_loadFailed) ...[
                          _RefreshFailedBanner(
                            // A pull shows its own indicator instead.
                            busy: _loading && !_pulling,
                            onRetry: _refreshReports,
                          ),
                          const SizedBox(height: 12),
                        ],
                        ProviderScope(
                          overrides: [
                            myReportDataProvider.overrideWithValue(reports),
                          ],
                          child: _buildCurrentTab(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),

          if (_filter == ReportFilter.all)
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              height: actionBarHeight,
              child: HowmuchBottomActionBar(
                safeBottom: safePadding.bottom,
                child: SizedBox(
                  height: 56,
                  child: Semantics(
                    button: true,
                    child: Material(
                      color: MyReportsV2Screen.blue,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => context.push(AppRoutes.reportCreate),
                        borderRadius: BorderRadius.circular(14),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '새 제보 등록하기',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: MyReportsV2Screen.fontFamily,
                                fontFamilyFallback:
                                    MyReportsV2Screen.fontFallback,
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
      case ReportFilter.noChange:
        return '수정 없음';
      case ReportFilter.needsEdit:
        return '보완 요청';
      case ReportFilter.rejected:
        return '반려';
    }
  }

  @override
  Widget build(BuildContext context) {
    return HowmuchTopBar(
      title: _title,
      onBack: onBack,
      trailingIcon: Icons.search_rounded,
      trailingTooltip: '내 제보 검색',
      onTrailingTap: onSearch,
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
    (ReportFilter.noChange, '수정 없음'),
    (ReportFilter.needsEdit, '보완 요청'),
    (ReportFilter.rejected, '반려'),
  ];

  // 서버에 아직 없는 보완 요청과 드물게 생기는 수정 없음은 비어 있으면 탭을 숨깁니다.
  static const _hiddenWhenEmpty = {
    ReportFilter.noChange,
    ReportFilter.needsEdit,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MyReportsV2Screen.surface,
        border: Border(
          bottom: BorderSide(color: MyReportsV2Screen.border, width: .909),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            for (final item in _items)
              if (!_hiddenWhenEmpty.contains(item.$1) ||
                  (counts[item.$1] ?? 0) > 0 ||
                  selected == item.$1)
                item,
          ];
          final tabWidth = constraints.maxWidth / items.length;
          return Row(
            children: [
              for (final item in items)
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

    // The tabs filter the list like chips: read each as a button with its
    // count and whether it is the current filter (QA 10/7 #54).
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: '$label $count건',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
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
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: MyReportsV2Screen.blue,
              semanticsLabel: '내 제보 조회 중',
            ),
          ),
          SizedBox(height: 14),
          ExcludeSemantics(
            child: Text(
              '내 제보를 불러오고 있어요',
              style: TextStyle(
                color: MyReportsV2Screen.muted,
                fontFamily: MyReportsV2Screen.fontFamily,
                fontFamilyFallback: MyReportsV2Screen.fontFallback,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A centered state like the community feed's: an icon, a bold line, a
/// muted line and, when there is something to do, a button.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: MyReportsV2Screen.border),
            ),
            child: Icon(icon, size: 26, color: MyReportsV2Screen.muted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MyReportsV2Screen.ink,
              fontFamily: MyReportsV2Screen.fontFamily,
              fontFamilyFallback: MyReportsV2Screen.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MyReportsV2Screen.muted,
              fontFamily: MyReportsV2Screen.fontFamily,
              fontFamilyFallback: MyReportsV2Screen.fontFallback,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: MyReportsV2Screen.blue,
                backgroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                side: const BorderSide(color: MyReportsV2Screen.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: MyReportsV2Screen.fontFamily,
                  fontFamilyFallback: MyReportsV2Screen.fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown above reports that are still on screen when a refresh failed.
class _RefreshFailedBanner extends StatelessWidget {
  const _RefreshFailedBanner({required this.busy, required this.onRetry});

  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: AppColors.warningDark,
      fontFamily: MyReportsV2Screen.fontFamily,
      fontFamilyFallback: MyReportsV2Screen.fontFallback,
      fontSize: 12,
      height: 1.5,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '내 제보를 새로 불러오지 못했어요.',
                  style: textStyle.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text('기존 내역은 유지했어요.', style: textStyle),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: busy ? null : onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontFamily: MyReportsV2Screen.fontFamily,
                fontFamilyFallback: MyReportsV2Screen.fontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warning,
                      semanticsLabel: '내 제보 조회 중',
                    ),
                  )
                : const Text('다시 불러오기'),
          ),
        ],
      ),
    );
  }
}

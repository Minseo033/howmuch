import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/admin/presentation/state/admin_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class AdminReportReviewScreen extends ConsumerStatefulWidget {
  const AdminReportReviewScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const surface = Color(0xFFF4F6FA);
  static const border = Color(0xFFE5E7EB);
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
  ConsumerState<AdminReportReviewScreen> createState() =>
      _AdminReportReviewScreenState();
}

class _AdminReportReviewScreenState
    extends ConsumerState<AdminReportReviewScreen> {
  final _searchController = TextEditingController();
  AdminReviewStatus _selectedStatus = AdminReviewStatus.fresh;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;
    final reports = ref.watch(adminReportsProvider);
    final filtered = _filteredReports(reports);
    final contentHeight = math.max(
      900.0 + topOffset,
      226.0 + topOffset + (filtered.length * 600.0),
    );

    return FigmaMobileCanvas(
      backgroundColor: AdminReportReviewScreen.surface,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            width: double.infinity,
            height: contentHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: 48.877838134765625 + topOffset,
                  child: _Header(
                    topOffset: topOffset,
                    onInquiryTap: () =>
                        context.go(AppRoutes.adminInquiryReview),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 48.8779296875 + topOffset,
                  right: 0,
                  height: 116,
                  child: _SearchAndFilters(
                    controller: _searchController,
                    selectedStatus: _selectedStatus,
                    countFor: (status) => _displayCount(status, reports),
                    onStatusChanged: (status) {
                      setState(() => _selectedStatus = status);
                    },
                  ),
                ),
                if (filtered.isEmpty)
                  Positioned(
                    left: 20,
                    top: 191.647705078125 + topOffset,
                    right: 20,
                    child: const _EmptyReportCard(),
                  )
                else
                  ...List.generate(filtered.length, (index) {
                    final top = 175.6396484375 + topOffset + (index * 600.0);
                    return Positioned(
                      left: 20,
                      top: top,
                      right: 20,
                      child: _ReportReviewCard(
                        report: filtered[index],
                        onCheckTap: (checkIndex) =>
                            _toggleCheck(filtered[index], checkIndex),
                        onDetailsTap: () => _showDetails(filtered[index]),
                        onPhotoTap: () => _showPhotos(filtered[index]),
                        onReject: () => _updateReportStatus(
                          filtered[index],
                          AdminReviewStatus.rejected,
                        ),
                        onRevision: () => _updateReportStatus(
                          filtered[index],
                          AdminReviewStatus.revision,
                        ),
                        onApprove: () => _updateReportStatus(
                          filtered[index],
                          AdminReviewStatus.approved,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AdminReportReview> _filteredReports(List<AdminReportReview> reports) {
    final keyword = _searchController.text.trim().toLowerCase();
    return reports.where((report) {
      final matchesStatus = report.status == _selectedStatus;
      final searchSource =
          '${report.storeName} ${report.category} ${report.reporter} ${report.address}'
              .toLowerCase();
      return matchesStatus &&
          (keyword.isEmpty || searchSource.contains(keyword));
    }).toList();
  }

  int _displayCount(AdminReviewStatus status, List<AdminReportReview> reports) {
    const figmaBase = {
      AdminReviewStatus.fresh: 8,
      AdminReviewStatus.reviewing: 3,
      AdminReviewStatus.approved: 42,
      AdminReviewStatus.rejected: 2,
    };
    const initialVisible = {
      AdminReviewStatus.fresh: 1,
      AdminReviewStatus.reviewing: 1,
      AdminReviewStatus.approved: 0,
      AdminReviewStatus.rejected: 0,
    };
    final current = reports.where((report) => report.status == status).length;
    final base = figmaBase[status] ?? 0;
    final initial = initialVisible[status] ?? 0;
    return math.max(0, base + current - initial);
  }

  void _toggleCheck(AdminReportReview report, int index) {
    final nextChecks = [...report.checks];
    nextChecks[index] = !nextChecks[index];
    ref.read(adminReportsProvider.notifier).state = [
      for (final item in ref.read(adminReportsProvider))
        item.id == report.id ? item.copyWith(checks: nextChecks) : item,
    ];
  }

  void _updateReportStatus(AdminReportReview report, AdminReviewStatus status) {
    // TODO(BE): 박지환 팀원의 관리자 제보 검토 API로 교체하세요.
    ref.read(adminReportsProvider.notifier).state = [
      for (final item in ref.read(adminReportsProvider))
        item.id == report.id ? item.copyWith(status: status) : item,
    ];

    final message = switch (status) {
      AdminReviewStatus.approved => '${report.storeName} 제보를 승인했어요.',
      AdminReviewStatus.rejected => '${report.storeName} 제보를 반려했어요.',
      AdminReviewStatus.revision => '${report.storeName} 제보에 보완을 요청했어요.',
      AdminReviewStatus.fresh ||
      AdminReviewStatus.reviewing => '${report.storeName} 상태를 변경했어요.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDetails(AdminReportReview report) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.storeName, style: _sheetTitleText),
              const SizedBox(height: 12),
              _SheetInfo(label: '주소', value: report.address),
              const SizedBox(height: 10),
              _SheetInfo(label: '메모', value: report.memo),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotos(AdminReportReview report) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${report.storeName} 첨부 사진'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                report.photoCount,
                (index) => _PhotoPreview(index: index),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.topOffset, required this.onInquiryTap});

  final double topOffset;
  final VoidCallback onInquiryTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AdminReportReviewScreen.border,
            width: .909,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 11.98876953125 + topOffset,
            child: Row(
              children: [
                const Text('제보 검토', style: _headerTitleText),
                const SizedBox(width: 7.997),
                Container(
                  height: 17.485794067382812,
                  padding: const EdgeInsets.symmetric(horizontal: 5.994),
                  decoration: BoxDecoration(
                    color: AdminReportReviewScreen.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text('ADMIN', style: _adminBadgeText),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 2.98583984375 + topOffset,
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: '문의 검토로 이동',
              onPressed: onInquiryTap,
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AdminReportReviewScreen.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.selectedStatus,
    required this.countFor,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final AdminReviewStatus selectedStatus;
  final int Function(AdminReviewStatus status) countFor;
  final ValueChanged<AdminReviewStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      AdminReviewStatus.fresh,
      AdminReviewStatus.reviewing,
      AdminReviewStatus.approved,
      AdminReviewStatus.rejected,
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 11.989),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AdminReportReviewScreen.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 11.989),
                    const Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: AdminReportReviewScreen.hint,
                    ),
                    const SizedBox(width: 7.997),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: _inputText,
                        cursorColor: AdminReportReviewScreen.blue,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: AdminReportReviewScreen.surface,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '매장명 또는 지역 검색',
                          hintStyle: _hintText,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11.989),
            SizedBox(
              height: 30.795454025268555,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 5.994),
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  return _FilterChip(
                    label: status.label,
                    count: countFor(status),
                    selected: selectedStatus == status,
                    onTap: () => onStatusChanged(status),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    final background = selected ? AdminReportReviewScreen.blue : Colors.white;
    final foreground = selected ? Colors.white : AdminReportReviewScreen.muted;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 30.795454025268555,
          padding: const EdgeInsets.symmetric(horizontal: 10.994),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: AdminReportReviewScreen.border,
                    width: .909,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$label ', style: _chipText.copyWith(color: foreground)),
              Container(
                height: 16.988636016845703,
                constraints: const BoxConstraints(minWidth: 17.798294067382812),
                padding: const EdgeInsets.symmetric(horizontal: 5.994),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .25)
                      : AdminReportReviewScreen.surface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: _chipCountText.copyWith(color: foreground),
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

class _ReportReviewCard extends StatelessWidget {
  const _ReportReviewCard({
    required this.report,
    required this.onCheckTap,
    required this.onDetailsTap,
    required this.onPhotoTap,
    required this.onReject,
    required this.onRevision,
    required this.onApprove,
  });

  final AdminReportReview report;
  final ValueChanged<int> onCheckTap;
  final VoidCallback onDetailsTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onReject;
  final VoidCallback onRevision;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 514,
          padding: const EdgeInsets.all(16.903411865234375),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AdminReportReviewScreen.border,
              width: .909,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 7,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: report.status),
                  const Spacer(),
                  Text('ID #${report.id}', style: _tinyMutedText),
                ],
              ),
              const SizedBox(height: 15.994),
              Text(report.storeName, style: _storeTitleText),
              const SizedBox(height: 3.991),
              Text(
                '${report.category} · ${report.reporter} · ${report.createdAt}',
                style: _metaText,
              ),
              const SizedBox(height: 11.989),
              Container(
                height: 43.99147415161133,
                padding: const EdgeInsets.symmetric(horizontal: 11.989),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '대표 메뉴 · ${report.menuName}',
                        style: _menuLabelText,
                      ),
                    ),
                    Text(report.priceText, style: _priceText),
                  ],
                ),
              ),
              const SizedBox(height: 15.994),
              Row(
                children: [
                  const Text('첨부 사진', style: _miniSectionText),
                  const Spacer(),
                  Text('${report.photoCount}장', style: _tinyMutedText),
                ],
              ),
              const SizedBox(height: 7.997),
              GestureDetector(
                onTap: onPhotoTap,
                child: Row(
                  children: [
                    const _PhotoPreview(index: 0),
                    const SizedBox(width: 5.994),
                    const _PhotoPreview(index: 1),
                    const SizedBox(width: 5.994),
                    const _PhotoPreview(index: 2),
                    const SizedBox(width: 5.994),
                    _MorePhotoBox(count: math.max(0, report.photoCount - 3)),
                  ],
                ),
              ),
              const SizedBox(height: 15.994),
              Row(
                children: [
                  const Text('상세 정보', style: _miniSectionText),
                  const Spacer(),
                  GestureDetector(
                    onTap: onDetailsTap,
                    child: const Text('주소 · 메모 ›', style: _tinyMutedText),
                  ),
                ],
              ),
              const SizedBox(height: 7.997),
              Container(
                height: 36.49147415161133,
                padding: const EdgeInsets.symmetric(horizontal: 11.989),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AdminReportReviewScreen.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(report.address, style: _metaText),
              ),
              const SizedBox(height: 15.994),
              _ChecklistPanel(report: report, onCheckTap: onCheckTap),
            ],
          ),
        ),
        Container(
          height: 76,
          padding: const EdgeInsets.only(top: 14, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '반려',
                  icon: Icons.close_rounded,
                  background: const Color(0xFFFEE2E2),
                  foreground: AdminReportReviewScreen.red,
                  onTap: onReject,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '보완 요청',
                  icon: Icons.warning_amber_rounded,
                  background: const Color(0xFFFFF3EA),
                  foreground: AdminReportReviewScreen.orange,
                  onTap: onRevision,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 126,
                child: _ActionButton(
                  label: '승인',
                  icon: Icons.check_rounded,
                  background: AdminReportReviewScreen.green,
                  foreground: Colors.white,
                  onTap: onApprove,
                  emphasized: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({required this.report, required this.onCheckTap});

  final AdminReportReview report;
  final ValueChanged<int> onCheckTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['주소 확인', '가격 확인', '중복 매장 여부', '부적절한 내용 없음'];

    return Container(
      height: 124,
      padding: const EdgeInsets.fromLTRB(11.989, 13.5, 11.989, 13.5),
      decoration: BoxDecoration(
        color: AdminReportReviewScreen.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('검증 체크리스트', style: _checkTitleText),
              const Spacer(),
              Text(
                '${report.completedChecks} / ${report.checks.length} 확인',
                style: _checkCountText,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 26,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: labels.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onCheckTap(index),
                  child: Row(
                    children: [
                      _CheckBox(checked: report.checks[index]),
                      const SizedBox(width: 7.997),
                      Expanded(child: Text(labels[index], style: _checkText)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17.99715805053711,
      height: 17.99715805053711,
      decoration: BoxDecoration(
        color: checked ? AdminReportReviewScreen.green : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked
              ? AdminReportReviewScreen.green
              : const Color(0xFFCBD5E1),
          width: .909,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      elevation: emphasized ? 4 : 0,
      shadowColor: AdminReportReviewScreen.green.withValues(alpha: .3),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontFamily: AdminReportReviewScreen.fontFamily,
                  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
                  fontSize: emphasized ? 13 : 12,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const gradients = [
      [Color(0xFFFCD34D), Color(0xFFF97316)],
      [Color(0xFFA7F3D0), Color(0xFF34D399)],
      [Color(0xFFBFDBFE), Color(0xFF60A5FA)],
      [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    ];
    final colors = gradients[index % gradients.length];

    return Container(
      width: 53.99147415161133,
      height: 53.99147415161133,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.white, size: 17),
    );
  }
}

class _MorePhotoBox extends StatelessWidget {
  const _MorePhotoBox({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 53.99147415161133,
      height: 53.99147415161133,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+$count',
        style: _metaText.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AdminReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      AdminReviewStatus.fresh => (
        bg: const Color(0xFFEFF4FF),
        fg: AdminReportReviewScreen.blue,
      ),
      AdminReviewStatus.reviewing || AdminReviewStatus.revision => (
        bg: const Color(0xFFFFF3EA),
        fg: AdminReportReviewScreen.orange,
      ),
      AdminReviewStatus.approved => (
        bg: const Color(0xFFE8F8F1),
        fg: AdminReportReviewScreen.green,
      ),
      AdminReviewStatus.rejected => (
        bg: const Color(0xFFFEE2E2),
        fg: AdminReportReviewScreen.red,
      ),
    };

    return Container(
      height: 20.99431800842285,
      padding: const EdgeInsets.symmetric(horizontal: 8.991),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
            child: const SizedBox(width: 5, height: 5),
          ),
          const SizedBox(width: 3.991),
          Text(status.label, style: _badgeText.copyWith(color: colors.fg)),
        ],
      ),
    );
  }
}

class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminReportReviewScreen.border, width: .909),
      ),
      child: const Text('조건에 맞는 제보가 없어요.', style: _metaText),
    );
  }
}

class _SheetInfo extends StatelessWidget {
  const _SheetInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _miniSectionText),
        const SizedBox(height: 5),
        Text(value, style: _metaText),
      ],
    );
  }
}

const _headerTitleText = TextStyle(
  color: AdminReportReviewScreen.black,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _adminBadgeText = TextStyle(
  color: Colors.white,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 9,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _hintText = TextStyle(
  color: AdminReportReviewScreen.hint,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _inputText = TextStyle(
  color: AdminReportReviewScreen.ink,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _chipText = TextStyle(
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _chipCountText = TextStyle(
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _badgeText = TextStyle(
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _storeTitleText = TextStyle(
  color: AdminReportReviewScreen.black,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _metaText = TextStyle(
  color: AdminReportReviewScreen.muted,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _tinyMutedText = TextStyle(
  color: AdminReportReviewScreen.muted,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _menuLabelText = TextStyle(
  color: AdminReportReviewScreen.muted,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _priceText = TextStyle(
  color: AdminReportReviewScreen.orange,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _miniSectionText = TextStyle(
  color: AdminReportReviewScreen.ink,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _checkTitleText = TextStyle(
  color: AdminReportReviewScreen.ink,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _checkCountText = TextStyle(
  color: AdminReportReviewScreen.orange,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _checkText = TextStyle(
  color: AdminReportReviewScreen.ink,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _sheetTitleText = TextStyle(
  color: AdminReportReviewScreen.ink,
  fontFamily: AdminReportReviewScreen.fontFamily,
  fontFamilyFallback: AdminReportReviewScreen.fontFallback,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

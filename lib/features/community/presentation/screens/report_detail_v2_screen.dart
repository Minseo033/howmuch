import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:image_picker/image_picker.dart';

class ReportDetailV2Screen extends ConsumerStatefulWidget {
  const ReportDetailV2Screen({super.key, this.reportId, this.initialReport});

  final String? reportId;
  final UserReportStatus? initialReport;

  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFF97316);
  static const _green = Color(0xFF10B981);
  static const _ink = Color(0xFF0F172A);
  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE5E7EB);
  static const _hint = Color(0xFF94A3B8);
  static const _surface = Color(0xFFF4F6FA);
  static const _contentLeft = 20.0;
  static const _contentRight = 20.0;
  static const _fontFamily = 'Inter';
  static const _fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  ConsumerState<ReportDetailV2Screen> createState() =>
      _ReportDetailV2ScreenState();
}

class _ReportDetailV2ScreenState extends ConsumerState<ReportDetailV2Screen> {
  String? _alertedRejectReportId;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(userReportsProvider);
    final report =
        widget.initialReport ??
        reports.where((item) => item.id == widget.reportId).firstOrNull;
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom > 24 ? safePadding.bottom : 24.0;
    final actionBottomGap = bottomOffset + 46;
    const actionHeight = 45.994;

    void goBack() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutes.myReportsV2);
    }

    if (report == null) {
      return FigmaMobileCanvas(
        backgroundColor: ReportDetailV2Screen._surface,
        child: Center(
          child: Text(
            '제보 정보를 찾을 수 없어요.',
            style: const TextStyle(
              color: ReportDetailV2Screen._muted,
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    _showRejectReasonAlertIfNeeded(report);

    return FigmaMobileCanvas(
      backgroundColor: ReportDetailV2Screen._surface,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: topOffset,
            child: const ColoredBox(color: Colors.white),
          ),
          Positioned(
            left: 0,
            top: topOffset,
            right: 0,
            height: 48.878,
            child: _Header(onBack: goBack),
          ),
          Positioned(
            left: 0,
            top: topOffset + 48.878,
            right: 0,
            bottom: 0,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                ReportDetailV2Screen._contentLeft,
                15.992,
                ReportDetailV2Screen._contentRight,
                actionBottomGap + actionHeight + 24,
              ),
              children: [
                _ReportInfoCard(report: report),
                const SizedBox(height: 11.989),
                _ProgressCard(report: report),
                const SizedBox(height: 11.989),
                _InfoMessageCard(report: report),
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            right: 0,
            height: actionBottomGap + actionHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ReportDetailV2Screen._contentLeft,
                0,
                ReportDetailV2Screen._contentRight,
                actionBottomGap,
              ),
              child: Row(
                children: [
                  const Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: actionHeight,
                      child: _OutlineActionButton(),
                    ),
                  ),
                  const SizedBox(width: 7.997),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      height: actionHeight,
                      child: _PrimaryActionButton(report: report),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectReasonAlertIfNeeded(UserReportStatus report) {
    final rejectReason = report.rejectReason.trim();
    if (!report.status.contains('반려') || rejectReason.isEmpty) return;
    if (_alertedRejectReportId == report.id) return;

    _alertedRejectReportId = report.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('반려 사유'),
            content: Text(rejectReason),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ReportDetailV2Screen._border)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: AppSizes.horizontalPadding,
            top: 13.98,
            width: 28,
            height: 20,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: ReportDetailV2Screen._ink,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 11.99,
            child: Center(
              child: Text(
                '제보 상세',
                style: TextStyle(
                  color: ReportDetailV2Screen._black,
                  fontFamily: ReportDetailV2Screen._fontFamily,
                  fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSizes.horizontalPadding,
            top: 12.5,
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: ReportDetailV2Screen._ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportInfoCard extends StatelessWidget {
  const _ReportInfoCard({required this.report});

  final UserReportStatus report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReportDetailV2Screen._border, width: .909),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserBadgeRow(report: report),
          const SizedBox(height: 12),
          Text(
            report.store.isEmpty ? '매장명 없음' : report.store,
            style: const TextStyle(
              color: ReportDetailV2Screen._black,
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _InfoLine(
            label: '업종',
            value: report.category.isEmpty ? '입력 없음' : report.category,
            valueWeight: FontWeight.w600,
            valueColor: ReportDetailV2Screen._ink,
          ),
          const SizedBox(height: AppSizes.smallSpacing),
          _InfoLine(
            label: '주소',
            value: report.address.isEmpty ? '입력 없음' : report.address,
            valueWeight: FontWeight.w600,
            valueColor: ReportDetailV2Screen._ink,
          ),
          const SizedBox(height: AppSizes.smallSpacing),
          _PriceLine(report: report),
          const SizedBox(height: AppSizes.itemSpacing),
          _PhotoSection(imageUrls: report.imageUrls),
        ],
      ),
    );
  }
}

class _UserBadgeRow extends StatelessWidget {
  const _UserBadgeRow({required this.report});

  final UserReportStatus report;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: ReportDetailV2Screen._orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '사용자 제보',
              style: TextStyle(
                color: ReportDetailV2Screen._orange,
                fontFamily: ReportDetailV2Screen._fontFamily,
                fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Color(report.statusBg),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(report.textColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                report.status,
                style: TextStyle(
                  color: Color(report.textColor),
                  fontFamily: ReportDetailV2Screen._fontFamily,
                  fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    required this.valueWeight,
    this.valueColor,
  });

  final String label;
  final String value;
  final FontWeight valueWeight;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ReportDetailV2Screen._muted,
            fontFamily: ReportDetailV2Screen._fontFamily,
            fontFamilyFallback: ReportDetailV2Screen._fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? ReportDetailV2Screen._ink,
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 12,
              fontWeight: valueWeight,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.report});

  final UserReportStatus report;

  List<(String, String)> get _items {
    if (report.menuPrices.isNotEmpty) {
      return report.menuPrices.map((item) {
        final price = item.price.isEmpty
            ? ''
            : (item.price.endsWith('원') ? item.price : '${item.price}원');
        return (item.menu, price);
      }).toList();
    }
    final trimmed = report.menu.trim();
    if (trimmed.isEmpty) return [('입력 없음', '')];
    final lastSpace = trimmed.lastIndexOf(' ');
    if (lastSpace == -1) return [(trimmed, '')];
    return [
      (
        trimmed.substring(0, lastSpace).trim(),
        trimmed.substring(lastSpace + 1).trim(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대표 메뉴',
          style: TextStyle(
            color: ReportDetailV2Screen._muted,
            fontFamily: ReportDetailV2Screen._fontFamily,
            fontFamilyFallback: ReportDetailV2Screen._fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${items[index].$1} ',
                        style: const TextStyle(
                          color: ReportDetailV2Screen._ink,
                        ),
                      ),
                      TextSpan(
                        text: items[index].$2,
                        style: const TextStyle(
                          color: ReportDetailV2Screen._orange,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: ReportDetailV2Screen._fontFamily,
                    fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                if (index != items.length - 1) const SizedBox(height: 3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.report});

  final UserReportStatus report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReportDetailV2Screen._border, width: .909),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '검토 진행 상태',
            style: TextStyle(
              color: ReportDetailV2Screen._black,
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSizes.largeSpacing),
          _ProgressSteps(report: report),
        ],
      ),
    );
  }
}

class _InfoMessageCard extends StatelessWidget {
  const _InfoMessageCard({required this.report});

  final UserReportStatus report;

  @override
  Widget build(BuildContext context) {
    final hasNotice = report.rejectReason.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: hasNotice ? const Color(0xFFFFF3EA) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasNotice ? const Color(0xFFFED7AA) : const Color(0xFFDBEAFE),
          width: .909,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasNotice ? Icons.warning_amber_rounded : Icons.access_time,
            color: hasNotice
                ? ReportDetailV2Screen._orange
                : ReportDetailV2Screen._blue,
            size: 16,
          ),
          const SizedBox(width: AppSizes.smallSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.status,
                  style: TextStyle(
                    color: hasNotice
                        ? ReportDetailV2Screen._orange
                        : ReportDetailV2Screen._blue,
                    fontFamily: ReportDetailV2Screen._fontFamily,
                    fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasNotice
                      ? report.rejectReason.trim()
                      : '현재 가격과 위치 정보를 확인하고 있어요.',
                  style: const TextStyle(
                    color: ReportDetailV2Screen._black,
                    fontFamily: ReportDetailV2Screen._fontFamily,
                    fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.report});

  final UserReportStatus report;

  int get _currentIndex {
    if (report.status.contains('승인')) return 3;
    if (report.status.contains('반려') || report.status.contains('보완')) {
      return 2;
    }
    return 1;
  }

  Color get _currentColor {
    if (report.status.contains('승인')) return ReportDetailV2Screen._green;
    if (report.status.contains('반려')) return const Color(0xFFEF4444);
    return ReportDetailV2Screen._orange;
  }

  String get _reviewResultLabel {
    if (report.status.contains('반려')) return '반려';
    if (report.status.contains('보완')) return '보완 요청';
    if (report.status.contains('승인')) return '승인 완료';
    return '검토 결과';
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex;
    final items = [
      _StepData('접수 완료', 0, ReportDetailV2Screen._green, currentIndex > 0),
      _StepData(
        '정보 확인',
        1,
        currentIndex >= 1
            ? ReportDetailV2Screen._green
            : const Color(0xFFCBD5E1),
        currentIndex > 1,
      ),
      _StepData(
        _reviewResultLabel,
        2,
        currentIndex >= 2 ? _currentColor : const Color(0xFFCBD5E1),
        currentIndex > 2,
      ),
      _StepData(
        '지도 반영',
        3,
        currentIndex >= 3
            ? ReportDetailV2Screen._green
            : const Color(0xFFCBD5E1),
        currentIndex >= 3,
      ),
    ];

    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const circleSize = 22.0;
          const connectorInset = 5.0;
          const connectorHeight = 2.0;
          const labelTop = 28.5;
          final stepWidth = constraints.maxWidth / items.length;
          final circleTop = 0.0;
          final connectorTop = circleTop + (circleSize - connectorHeight) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < items.length - 1; index++)
                Positioned(
                  left:
                      stepWidth * index +
                      stepWidth / 2 +
                      circleSize / 2 +
                      connectorInset,
                  top: connectorTop,
                  width: stepWidth - circleSize - connectorInset * 2,
                  height: connectorHeight,
                  child: ColoredBox(
                    color: index < currentIndex
                        ? ReportDetailV2Screen._green
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              for (var index = 0; index < items.length; index++)
                Positioned(
                  left: stepWidth * index,
                  top: circleTop,
                  width: stepWidth,
                  child: Center(
                    child: _StepCircle(item: items[index], index: index),
                  ),
                ),
              for (var index = 0; index < items.length; index++)
                Positioned(
                  left: stepWidth * index,
                  top: labelTop,
                  width: stepWidth,
                  child: _StepLabel(
                    item: items[index],
                    isCurrent: index == currentIndex,
                    currentColor: index == currentIndex
                        ? _currentColor
                        : ReportDetailV2Screen._orange,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.item, required this.index});

  final _StepData item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21.989,
      height: 21.989,
      decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: item.done
          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
          : Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: ReportDetailV2Screen._fontFamily,
                fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.item,
    required this.isCurrent,
    required this.currentColor,
  });

  final _StepData item;
  final bool isCurrent;
  final Color currentColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      item.label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.visible,
      style: TextStyle(
        color: isCurrent
            ? currentColor
            : (item.done
                  ? ReportDetailV2Screen._ink
                  : ReportDetailV2Screen._muted),
        fontFamily: ReportDetailV2Screen._fontFamily,
        fontFamilyFallback: ReportDetailV2Screen._fontFallback,
        fontSize: 9.5,
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        height: 1.2,
      ),
    );
  }
}

class _StepData {
  const _StepData(this.label, this.index, this.color, this.done);

  final String label;
  final int index;
  final Color color;
  final bool done;
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final visibleImages = imageUrls.take(3).toList();
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleImages.isEmpty ? 1 : visibleImages.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppSizes.smallSpacing),
        itemBuilder: (context, index) {
          if (visibleImages.isEmpty) {
            return const _EmptyPhotoSlot();
          }
          return _PhotoThumb(imagePath: visibleImages[index]);
        },
      ),
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ReportDetailV2Screen._border,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.camera_alt_outlined,
        color: ReportDetailV2Screen._hint,
        size: 22,
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final isRemote =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');
    return SizedBox(
      width: 70,
      height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            border: Border.all(color: ReportDetailV2Screen._border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: isRemote
              ? Image.network(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PhotoFallbackIcon(),
                )
              : FutureBuilder(
                  future: XFile(imagePath).readAsBytes(),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const _PhotoFallbackIcon();
                    }
                    return Image.memory(bytes, fit: BoxFit.cover);
                  },
                ),
        ),
      ),
    );
  }
}

class _PhotoFallbackIcon extends StatelessWidget {
  const _PhotoFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: ReportDetailV2Screen._hint,
        size: 22,
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ReportDetailV2Screen._border,
              width: .909,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mode_comment_outlined,
                size: 14,
                color: ReportDetailV2Screen._ink,
              ),
              const SizedBox(width: 6),
              const Text(
                '문의하기',
                style: TextStyle(
                  color: ReportDetailV2Screen._ink,
                  fontFamily: ReportDetailV2Screen._fontFamily,
                  fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.report});

  final UserReportStatus report;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.push(AppRoutes.reportCreate, extra: report),
      style: FilledButton.styleFrom(
        backgroundColor: ReportDetailV2Screen._blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          const Text(
            '제보 수정하기',
            style: TextStyle(
              color: Colors.white,
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

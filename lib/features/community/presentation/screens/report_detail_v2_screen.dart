import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ReportDetailV2Screen extends StatelessWidget {
  const ReportDetailV2Screen({super.key});

  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFF97316);
  static const _green = Color(0xFF10B981);
  static const _ink = Color(0xFF0F172A);
  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE5E7EB);
  static const _hint = Color(0xFF94A3B8);
  static const _surface = Color(0xFFF4F6FA);
  static const _softOrange = Color(0xFFFFF3EA);
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
  Widget build(BuildContext context) {
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

    return FigmaMobileCanvas(
      backgroundColor: _surface,
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
                _contentLeft,
                15.992,
                _contentRight,
                actionBottomGap + actionHeight + 24,
              ),
              children: [
                const _ReportInfoCard(),
                const SizedBox(height: 11.989),
                const _ProgressCard(),
                const SizedBox(height: 11.989),
                const _InfoMessageCard(),
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
                _contentLeft,
                0,
                _contentRight,
                actionBottomGap,
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: actionHeight,
                      child: _OutlineActionButton(),
                    ),
                  ),
                  SizedBox(width: 7.997),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      height: actionHeight,
                      child: _PrimaryActionButton(),
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
  const _ReportInfoCard();

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
        children: const [
          _UserBadgeRow(),
          SizedBox(height: 12),
          Text(
            '골목밥상',
            style: TextStyle(
              color: ReportDetailV2Screen._black,
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12),
          _InfoLine(
            label: '업종',
            value: '음식점 · 한식',
            valueWeight: FontWeight.w600,
            valueColor: ReportDetailV2Screen._ink,
          ),
          SizedBox(height: AppSizes.smallSpacing),
          _InfoLine(
            label: '주소',
            value: '서울시 마포구 합정동',
            valueWeight: FontWeight.w600,
            valueColor: ReportDetailV2Screen._ink,
          ),
          SizedBox(height: AppSizes.smallSpacing),
          _PriceLine(),
          SizedBox(height: AppSizes.itemSpacing),
          _PhotoSection(),
        ],
      ),
    );
  }
}

class _UserBadgeRow extends StatelessWidget {
  const _UserBadgeRow();

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
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF92400E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '검토 중',
                style: TextStyle(
                  color: Color(0xFF92400E),
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
  const _PriceLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Text(
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
        SizedBox(width: 20),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '제육덮밥 ',
                  style: TextStyle(color: ReportDetailV2Screen._ink),
                ),
                TextSpan(
                  text: '6,000원',
                  style: TextStyle(color: ReportDetailV2Screen._orange),
                ),
              ],
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

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
        children: const [
          Text(
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
          SizedBox(height: AppSizes.largeSpacing),
          _ProgressSteps(),
        ],
      ),
    );
  }
}

class _InfoMessageCard extends StatelessWidget {
  const _InfoMessageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE), width: .909),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.access_time,
            color: ReportDetailV2Screen._blue,
            size: 16,
          ),
          const SizedBox(width: AppSizes.smallSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '검토 중',
                  style: TextStyle(
                    color: ReportDetailV2Screen._blue,
                    fontFamily: ReportDetailV2Screen._fontFamily,
                    fontFamilyFallback: ReportDetailV2Screen._fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '현재 가격과 위치 정보를 확인하고 있어요.',
                  style: TextStyle(
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
  const _ProgressSteps();

  @override
  Widget build(BuildContext context) {
    const items = [
      _StepData('접수 완료', 0, ReportDetailV2Screen._green, true),
      _StepData('정보 확인', 1, ReportDetailV2Screen._green, true),
      _StepData('검토 결과', 2, ReportDetailV2Screen._orange, false),
      _StepData('지도 반영', 3, Color(0xFFCBD5E1), false),
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
                    color: index < 2
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
                  child: _StepLabel(item: items[index], isCurrent: index == 2),
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
  const _StepLabel({required this.item, required this.isCurrent});

  final _StepData item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Text(
      item.label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.visible,
      style: TextStyle(
        color: isCurrent
            ? ReportDetailV2Screen._orange
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

class _ReasonItem extends StatelessWidget {
  const _ReasonItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: ReportDetailV2Screen._orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSizes.smallSpacing),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7C2D12),
              fontFamily: ReportDetailV2Screen._fontFamily,
              fontFamilyFallback: ReportDetailV2Screen._fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _PhotoThumb(
          colors: [Color(0xFFFCA5A5), Color(0xFFFBBF24)],
          icon: Icons.image_outlined,
          showWarning: false,
        ),
        SizedBox(width: AppSizes.smallSpacing),
        _PhotoThumb(
          colors: [Color(0xFFA7F3D0), Color(0xFF34D399)],
          icon: Icons.image_outlined,
        ),
        SizedBox(width: AppSizes.smallSpacing),
        _EmptyPhotoSlot(),
      ],
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
  const _PhotoThumb({
    required this.colors,
    required this.icon,
    this.showWarning = false,
  });

  final List<Color> colors;
  final IconData icon;
  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          if (showWarning)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: ReportDetailV2Screen._orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
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
  const _PrimaryActionButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.push(AppRoutes.reportCreate),
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

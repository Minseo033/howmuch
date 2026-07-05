import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFF97316);
  static const _green = Color(0xFF10B981);
  static const _ink = Color(0xFF0F172A);
  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE5E7EB);
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
      context.go(AppRoutes.myReports);
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
                const SizedBox(height: 11.99),
                const _ReasonCard(),
                const SizedBox(height: 11.989),
                const _PhotoSection(),
                const SizedBox(height: 11.989),
                const _DescriptionSection(),
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
        border: Border(bottom: BorderSide(color: ReportDetailScreen._border)),
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
                color: ReportDetailScreen._ink,
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
                  color: ReportDetailScreen._black,
                  fontFamily: ReportDetailScreen._fontFamily,
                  fontFamilyFallback: ReportDetailScreen._fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
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
        border: Border.all(color: ReportDetailScreen._border, width: .909),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _StatusRow(),
          SizedBox(height: 7.997),
          Text(
            '착한김밥',
            style: TextStyle(
              color: ReportDetailScreen._black,
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          SizedBox(height: 7.997),
          _InfoLine(
            label: '업종',
            value: '음식점 · 분식',
            valueWeight: FontWeight.w600,
          ),
          SizedBox(height: 5.994),
          _PriceLine(),
          SizedBox(height: 5.994),
          _InfoLine(
            label: '위치',
            value: '서울시 강남구 역삼동',
            valueWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _StatusBadge(),
        Spacer(),
        Text(
          '제보일 2026.05.08',
          style: TextStyle(
            color: ReportDetailScreen._muted,
            fontFamily: ReportDetailScreen._fontFamily,
            fontFamilyFallback: ReportDetailScreen._fontFallback,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70.497,
      height: 20.994,
      decoration: BoxDecoration(
        color: ReportDetailScreen._softOrange,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: ReportDetailScreen._orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '보완 요청',
            style: TextStyle(
              color: ReportDetailScreen._orange,
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    required this.valueWeight,
  });

  final String label;
  final String value;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ReportDetailScreen._muted,
            fontFamily: ReportDetailScreen._fontFamily,
            fontFamilyFallback: ReportDetailScreen._fontFallback,
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
              color: ReportDetailScreen._ink,
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
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
            color: ReportDetailScreen._muted,
            fontFamily: ReportDetailScreen._fontFamily,
            fontFamilyFallback: ReportDetailScreen._fontFallback,
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
                  text: '김밥 ',
                  style: TextStyle(color: ReportDetailScreen._ink),
                ),
                TextSpan(
                  text: '2,500원',
                  style: TextStyle(color: ReportDetailScreen._orange),
                ),
              ],
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
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
      padding: const EdgeInsets.fromLTRB(16.903, 16.904, 16.904, 13.991),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReportDetailScreen._border, width: .909),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '검토 진행 단계',
            style: TextStyle(
              color: ReportDetailScreen._black,
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          SizedBox(height: 13.991),
          _ProgressSteps(),
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
      _StepData('접수 완료', 0, ReportDetailScreen._green, true),
      _StepData('정보 확인 중', 1, ReportDetailScreen._green, true),
      _StepData('보완 요청', 2, ReportDetailScreen._orange, false),
      _StepData('승인 대기', 3, Color(0xFFCBD5E1), false),
      _StepData('지도 반영', 4, Color(0xFFCBD5E1), false),
    ];

    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const circleSize = 21.989;
          const connectorInset = 5.5;
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
                        ? ReportDetailScreen._green
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
                fontFamily: ReportDetailScreen._fontFamily,
                fontFamilyFallback: ReportDetailScreen._fontFallback,
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
            ? ReportDetailScreen._orange
            : (item.done ? ReportDetailScreen._ink : ReportDetailScreen._muted),
        fontFamily: ReportDetailScreen._fontFamily,
        fontFamilyFallback: ReportDetailScreen._fontFallback,
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

class _ReasonCard extends StatelessWidget {
  const _ReasonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: ReportDetailScreen._softOrange,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33F97316), width: .909),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xFF9A3412),
              ),
              SizedBox(width: 6),
              Text(
                '보완 요청 사유',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontFamily: ReportDetailScreen._fontFamily,
                  fontFamilyFallback: ReportDetailScreen._fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 7.997),
          _ReasonItem('메뉴판 사진이 흐려 가격 확인이 어렵습니다.'),
          SizedBox(height: 5.994),
          _ReasonItem('대표 메뉴 가격을 다시 확인해주세요.'),
        ],
      ),
    );
  }
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
            color: ReportDetailScreen._orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSizes.smallSpacing),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7C2D12),
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '첨부 사진',
          style: TextStyle(
            color: ReportDetailScreen._muted,
            fontFamily: ReportDetailScreen._fontFamily,
            fontFamilyFallback: ReportDetailScreen._fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 5.994),
        Row(
          children: const [
            _PhotoThumb(
              colors: [Color(0xFFFCA5A5), Color(0xFFFBBF24)],
              icon: Icons.image_outlined,
              showWarning: true,
            ),
            SizedBox(width: AppSizes.smallSpacing),
            _PhotoThumb(
              colors: [Color(0xFFA7F3D0), Color(0xFF34D399)],
              icon: Icons.image_outlined,
            ),
          ],
        ),
      ],
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
                  color: ReportDetailScreen._orange,
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

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '입력한 설명',
          style: TextStyle(
            color: ReportDetailScreen._muted,
            fontFamily: ReportDetailScreen._fontFamily,
            fontFamilyFallback: ReportDetailScreen._fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 5.994),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11.99, 11.9, 13.465, 13.9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ReportDetailScreen._border, width: .909),
          ),
          child: const Text(
            '역삼역 1번 출구 근처 작은 김밥집인데 김밥이 2,500원이라 정말 저렴해요. 점심에 자주 가는 곳입니다.',
            style: TextStyle(
              color: ReportDetailScreen._ink,
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
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

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push(AppRoutes.inquiry),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ReportDetailScreen._border, width: .909),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mode_comment_outlined,
                size: 14,
                color: ReportDetailScreen._ink,
              ),
              const SizedBox(width: 6),
              const Text(
                '문의하기',
                style: TextStyle(
                  color: ReportDetailScreen._ink,
                  fontFamily: ReportDetailScreen._fontFamily,
                  fontFamilyFallback: ReportDetailScreen._fontFallback,
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
        backgroundColor: ReportDetailScreen._blue,
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
              fontFamily: ReportDetailScreen._fontFamily,
              fontFamilyFallback: ReportDetailScreen._fontFallback,
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

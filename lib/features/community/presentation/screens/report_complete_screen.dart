import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ReportCompleteScreen extends StatelessWidget {
  const ReportCompleteScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
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
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom + 48;

    return FigmaMobileCanvas(
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: SizedBox(
          height: FigmaMobileCanvas.height,
          child: Stack(
            children: [
          Positioned(
            left: 0,
            top: topOffset,
            width: FigmaMobileCanvas.width,
            height: 33.977,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.go(AppRoutes.communityFeed),
                padding: const EdgeInsets.only(left: 20),
                constraints: const BoxConstraints.tightFor(
                  width: 64,
                  height: 33.977,
                ),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: ink,
                  size: 21.989,
                ),
              ),
            ),
          ),
          Positioned(
            left: 117.73,
            top: topOffset + 73.98,
            width: 140,
            height: 140,
            child: const _SuccessMark(),
          ),
          Positioned(
            left: 78.79,
            top: topOffset + 241.97,
            width: 217.855,
            height: 79.972,
            child: const Column(
              children: [
                Text(
                  '제보가 접수되었어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 7.997),
                Text(
                  '검토 후 지도에 사용자 제보 매장으로 표시될 예정이에요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            top: topOffset + 349.94,
            width: 335.455,
            height: 166.747,
            child: const _SubmittedReportCard(),
          ),
          Positioned(
            left: 20,
            bottom: bottomOffset + 66,
            width: 335.455,
            height: 50,
            child: _BottomActionButton(
              label: '지도에서 주변 매장 더 보기',
              backgroundColor: blue,
              foregroundColor: Colors.white,
              shadow: const [
                BoxShadow(
                  color: Color(0x4D2563EB),
                  blurRadius: 8,
                  offset: Offset(0, 6),
                ),
              ],
              onTap: () => context.go(AppRoutes.home),
            ),
          ),
          Positioned(
            left: 20,
            bottom: bottomOffset,
            width: 335.455,
            height: 50,
            child: _BottomActionButton(
              label: '내 제보 내역 확인',
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: ink,
              onTap: () => context.go(AppRoutes.myReports),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFE8F8F1),
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          left: 20,
          top: 20,
          child: Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: 30,
          top: 30,
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: ReportCompleteScreen.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x6610B981),
                  blurRadius: 15,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmittedReportCard extends StatelessWidget {
  const _SubmittedReportCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ReportCompleteScreen.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReportCompleteScreen.border, width: .909),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15.99, 15.99, 17.82, 15.99),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PillBadge(
                  label: '사용자 제보',
                  backgroundColor: Color(0xFFFFF3EA),
                  color: ReportCompleteScreen.orange,
                  width: 79.503,
                ),
                _StatusBadge(),
              ],
            ),
            const SizedBox(height: 11.99),
            const Text(
              '골목밥상',
              style: TextStyle(
                color: Color(0xFF0A0A0A),
                fontFamily: ReportCompleteScreen.fontFamily,
                fontFamilyFallback: ReportCompleteScreen.fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10.99),
            _InfoRow(
              label: '대표 메뉴',
              value: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: ReportCompleteScreen.ink,
                    fontFamily: ReportCompleteScreen.fontFamily,
                    fontFamilyFallback: ReportCompleteScreen.fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: '제육덮밥 '),
                    TextSpan(
                      text: '6,000원',
                      style: TextStyle(
                        color: ReportCompleteScreen.orange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5.994),
            const _InfoRow(label: '위치', text: '현재 위치 근처'),
            const SizedBox(height: 5.994),
            const _InfoRow(label: '제보일', text: '2026.05.16'),
          ],
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.backgroundColor,
    required this.color,
    required this.width,
  });

  final String label;
  final Color backgroundColor;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 20.994,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5.994,
            height: 5.994,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3.99),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: ReportCompleteScreen.fontFamily,
              fontFamilyFallback: ReportCompleteScreen.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 67.031,
      height: 22.983,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '● 검토 중',
        style: TextStyle(
          color: Color(0xFF92400E),
          fontFamily: ReportCompleteScreen.fontFamily,
          fontFamilyFallback: ReportCompleteScreen.fontFallback,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.text, this.value});

  final String label;
  final String? text;
  final Widget? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ReportCompleteScreen.muted,
            fontFamily: ReportCompleteScreen.fontFamily,
            fontFamilyFallback: ReportCompleteScreen.fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        value ??
            Text(
              text ?? '',
              style: const TextStyle(
                color: ReportCompleteScreen.ink,
                fontFamily: ReportCompleteScreen.fontFamily,
                fontFamilyFallback: ReportCompleteScreen.fontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
      ],
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.shadow = const [],
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: shadow,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontFamily: ReportCompleteScreen.fontFamily,
                fontFamilyFallback: ReportCompleteScreen.fontFallback,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class PublicDataSourceScreen extends StatelessWidget {
  const PublicDataSourceScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
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
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyButton.heightFor(bottomOffset);
    final scrollContentHeight = 627.51416015625 + topOffset + footerHeight + 24;

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(
                width: FigmaMobileCanvas.width,
                height: scrollContentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 64.8720703125 + topOffset,
                      width: 335.45452880859375,
                      height: 89.58806610107422,
                      child: const _IntroCard(),
                    ),
                    Positioned(
                      left: 23.991455078125,
                      top: 170.45458984375 + topOffset,
                      child: const _SectionLabel('데이터 출처'),
                    ),
                    Positioned(
                      left: 20,
                      top: 194.94287109375 + topOffset,
                      width: 335.45452880859375,
                      height: 311.1505432128906,
                      child: const Column(
                        children: [
                          _SourceCard(
                            icon: Icons.verified_user_outlined,
                            color: PublicDataSourceScreen.blue,
                            title: '행정안전부 착한가격업소',
                            subtitle: '인증 매장 · 가격 정보',
                          ),
                          SizedBox(height: 7.997),
                          _SourceCard(
                            icon: Icons.storage_rounded,
                            color: PublicDataSourceScreen.green,
                            title: '공공데이터포털',
                            subtitle: 'data.go.kr',
                          ),
                          SizedBox(height: 7.997),
                          _SourceCard(
                            icon: Icons.auto_awesome_rounded,
                            color: PublicDataSourceScreen.orange,
                            title: '기상청 날씨 API',
                            subtitle: '오늘의 픽 추천에 활용',
                          ),
                          SizedBox(height: 7.997),
                          _SourceCard(
                            icon: Icons.place_outlined,
                            color: PublicDataSourceScreen.muted,
                            title: '지도 API',
                            subtitle: '위치 표시 및 길찾기',
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 522.087890625 + topOffset,
                      width: 335.45452880859375,
                      height: 56.96022415161133,
                      child: const _NoticeBox(
                        color: Color(0xFFFEF3C7),
                        iconColor: Color(0xFF92400E),
                        icon: Icons.warning_amber_rounded,
                        text: '공공데이터는 주기적으로 동기화되며,\n실제 매장 정보와 차이가 있을 수 있어요.',
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 587.04541015625 + topOffset,
                      width: 335.45452880859375,
                      height: 40.46875,
                      child: const _NoticeBox(
                        color: Color(0xFFFFF3EA),
                        iconColor: Color(0xFF9A3412),
                        icon: Icons.check_rounded,
                        text: '사용자 제보 정보는 검토 후 지도에 반영됩니다.',
                        singleLine: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Header(
            topOffset: topOffset,
            title: '공공데이터 출처',
            onBack: () => context.go(AppRoutes.mypage),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
            height: footerHeight,
            child: _StickyButton(
              safeBottom: bottomOffset,
              label: '문의하기',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => context.go(AppRoutes.inquiry),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.topOffset,
    required this.title,
    required this.onBack,
  });

  final double topOffset;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: FigmaMobileCanvas.width,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: PublicDataSourceScreen.border,
              width: .909,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 72,
              height: 48.877838134765625,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: PublicDataSourceScreen.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 11.98876953125 + topOffset,
              child: const IgnorePointer(
                child: Text(
                  '공공데이터 출처',
                  textAlign: TextAlign.center,
                  style: _headerTitleText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        border: Border.all(color: const Color(0x212563EB), width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16.9034423828125,
            top: 16.9033203125,
            width: 40,
            height: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: PublicDataSourceScreen.blue,
              ),
            ),
          ),
          Positioned(
            left: 68.89208984375,
            top: 16.9033203125,
            width: 210,
            height: 57,
            child: RichText(
              text: const TextSpan(
                style: _introText,
                children: [
                  TextSpan(
                    text: '얼마고?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '는 행정안전부\n'),
                  TextSpan(
                    text: '착한가격업소 공공데이터',
                    style: TextStyle(
                      color: PublicDataSourceScreen.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: '를\n기반으로 정보를 제공합니다.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 335.45452880859375,
      height: 71.7897720336914,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: PublicDataSourceScreen.border, width: .909),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 14.9005126953125,
              top: 14.90087890625,
              width: 41.9886360168457,
              height: 41.9886360168457,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
            ),
            Positioned(
              left: 68.8778076171875,
              top: 16.40087890625,
              width: 225.69601440429688,
              height: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _sourceTitleText),
                  const SizedBox(height: .994),
                  Text(subtitle, style: _captionText),
                ],
              ),
            ),
            const Positioned(
              right: 14.9005126953125,
              top: 28.89208984375,
              child: Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: PublicDataSourceScreen.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.text,
    this.singleLine = false,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final String text;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 11.9886474609375,
            top: singleLine ? 13.97705078125 : 13.9775390625,
            child: Icon(icon, size: 13, color: iconColor),
          ),
          Positioned(
            left: 32.98291015625,
            top: 11.98876953125,
            child: Text(
              text,
              style: TextStyle(
                color: iconColor,
                fontFamily: PublicDataSourceScreen.fontFamily,
                fontFamilyFallback: PublicDataSourceScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _sectionText);
  }
}

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.safeBottom,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  static const buttonHeight = 51.9886360168457;
  static const topGap = 12.89794921875;
  static const bottomGap = 26.0;
  static const minimumSafeBottom = 34.0;

  final double safeBottom;
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  static double effectiveSafeBottom(double safeBottom) {
    return safeBottom > minimumSafeBottom ? safeBottom : minimumSafeBottom;
  }

  static double heightFor(double safeBottom) {
    return topGap + buttonHeight + bottomGap + effectiveSafeBottom(safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottom = effectiveSafeBottom(safeBottom);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: PublicDataSourceScreen.border, width: .909),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: effectiveBottom + bottomGap,
            height: buttonHeight,
            child: ElevatedButton.icon(
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: PublicDataSourceScreen.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: PublicDataSourceScreen.fontFamily,
                  fontFamilyFallback: PublicDataSourceScreen.fontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}

const _headerTitleText = TextStyle(
  color: PublicDataSourceScreen.black,
  fontFamily: PublicDataSourceScreen.fontFamily,
  fontFamilyFallback: PublicDataSourceScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _introText = TextStyle(
  color: PublicDataSourceScreen.ink,
  fontFamily: PublicDataSourceScreen.fontFamily,
  fontFamilyFallback: PublicDataSourceScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _sectionText = TextStyle(
  color: PublicDataSourceScreen.muted,
  fontFamily: PublicDataSourceScreen.fontFamily,
  fontFamilyFallback: PublicDataSourceScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _sourceTitleText = TextStyle(
  color: PublicDataSourceScreen.ink,
  fontFamily: PublicDataSourceScreen.fontFamily,
  fontFamilyFallback: PublicDataSourceScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _captionText = TextStyle(
  color: PublicDataSourceScreen.muted,
  fontFamily: PublicDataSourceScreen.fontFamily,
  fontFamilyFallback: PublicDataSourceScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

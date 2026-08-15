import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

enum OnboardingArtwork { nearby, savings, storeReport }

class OnboardingSlideData {
  const OnboardingSlideData({
    required this.figmaId,
    required this.title,
    required this.description,
    required this.eyebrow,
    required this.eyebrowColor,
    required this.eyebrowBackgroundColor,
    required this.artwork,
    required this.primaryLabel,
  });

  final String figmaId;
  final String title;
  final String description;
  final String eyebrow;
  final Color eyebrowColor;
  final Color eyebrowBackgroundColor;
  final OnboardingArtwork artwork;
  final String primaryLabel;
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.slides,
    required this.onComplete,
    this.initialStep = 0,
    this.onSkipPressed,
  });

  final List<OnboardingSlideData> slides;
  final int initialStep;
  final VoidCallback onComplete;
  final VoidCallback? onSkipPressed;

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const track = Color(0xFFCBD5E1);
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
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  late int _step;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, widget.slides.length - 1);
    _pageController = PageController(initialPage: _step);
  }

  @override
  void didUpdateWidget(covariant OnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStep != widget.initialStep) {
      _step = widget.initialStep.clamp(0, widget.slides.length - 1);
      _pageController.jumpToPage(_step);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_step == widget.slides.length - 1) {
      widget.onComplete();
      return;
    }

    _pageController.animateToPage(
      _step + 1,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F9FF), // Very soft light blue at top
              Color(0xFFFFFFFF), // White at bottom
            ],
          ),
        ),
        child: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          itemCount: widget.slides.length,
          onPageChanged: (page) => setState(() => _step = page),
          itemBuilder: (context, index) {
            return _OnboardingSlideView(
              slide: widget.slides[index],
              step: index,
              totalSteps: widget.slides.length,
              onNext: _goNext,
              onSkip: widget.onSkipPressed,
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    required this.slide,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    this.onSkip,
  });

  final OnboardingSlideData slide;
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;
    final safeBottom = FigmaMobileCanvas.designSafePaddingOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          _ArtworkLayer(artwork: slide.artwork),
          const Spacer(flex: 2),
          _SlideCopy(slide: slide),
          const Spacer(flex: 2),
          _StepIndicator(step: step, totalSteps: totalSteps),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _PrimaryButton(label: slide.primaryLabel, onPressed: onNext),
          ),
          if (isLast && onSkip != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 18,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: OnboardingPage.muted,
                  textStyle: const TextStyle(
                    fontFamily: OnboardingPage.fontFamily,
                    fontFamilyFallback: OnboardingPage.fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                child: const Text('로그인 없이 둘러보기'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 30),
          ],
          SizedBox(height: safeBottom > 0 ? safeBottom / 2 : 20),
        ],
      ),
    );
  }
}

class _ArtworkLayer extends StatelessWidget {
  const _ArtworkLayer({required this.artwork});

  final OnboardingArtwork artwork;

  @override
  Widget build(BuildContext context) {
    return switch (artwork) {
      OnboardingArtwork.nearby => const SizedBox(
        width: 280,
        height: 320,
        child: _NearbyArtwork(),
      ),
      OnboardingArtwork.savings => const SizedBox(
        width: 280,
        height: 261.25,
        child: _SavingsArtwork(),
      ),
      OnboardingArtwork.storeReport => const SizedBox(
        width: 280,
        height: 260,
        child: _StoreReportArtwork(),
      ),
    };
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide});

  final OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Eyebrow(slide: slide),
        const SizedBox(height: 12),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: OnboardingPage.ink,
            fontFamily: OnboardingPage.fontFamily,
            fontFamilyFallback: OnboardingPage.fontFallback,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          slide.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: OnboardingPage.muted,
            fontFamily: OnboardingPage.fontFamily,
            fontFamilyFallback: OnboardingPage.fontFallback,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.slide});

  final OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: slide.eyebrowBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        slide.eyebrow,
        style: TextStyle(
          color: slide.eyebrowColor,
          fontFamily: OnboardingPage.fontFamily,
          fontFamilyFallback: OnboardingPage.fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.5,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final selected = index == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 21.988636016845703 : 5.994318008422852,
          height: 5.994318008422852,
          margin: const EdgeInsets.symmetric(horizontal: 2.997159004211426),
          decoration: BoxDecoration(
            color: selected ? OnboardingPage.blue : OnboardingPage.track,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OnboardingPage.blue,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      shadowColor: const Color(0x4D2563EB),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: OnboardingPage.fontFamily,
              fontFamilyFallback: OnboardingPage.fontFallback,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyArtwork extends StatelessWidget {
  const _NearbyArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8EEF6), Color(0xFFDDE6F0)],
            ),
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E0F172A),
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: const CustomPaint(
            painter: _FigmaMapPainter(),
            child: SizedBox.expand(),
          ),
        ),
        const Positioned(left: 15.99, top: 15.99, child: _MapLegendPill()),
        const Positioned(
          left: 57,
          top: 64,
          child: _Pin(color: OnboardingPage.blue),
        ),
        const Positioned(
          left: 207,
          top: 54,
          child: _Pin(color: OnboardingPage.orange),
        ),
        const Positioned(
          left: 47,
          top: 194,
          child: _Pin(color: OnboardingPage.orange),
        ),
        const Positioned(
          left: 187,
          top: 234,
          child: _Pin(color: OnboardingPage.blue),
        ),
        const Positioned(left: 130, top: 200, child: _MyLocationDot(size: 36)),
        const Positioned(left: 123, top: 100, child: _PriceBubble()),
      ],
    );
  }
}

class _SavingsArtwork extends StatelessWidget {
  const _SavingsArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: 280,
          height: 145.4545440673828,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF059669),
                  Color(0xFF10B981),
                  Color(0xFF34D399),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4010B981),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: -20,
                  top: -20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 110, height: 110),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 20,
                  child: Text(
                    '✧  이번 달 절약 금액',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 44.49,
                  child: Text(
                    '24,500',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
                const Positioned(
                  left: 131.75,
                  top: 68.13,
                  child: Text(
                    '원',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 102.47,
                  child: Container(
                    height: 22.982954025268555,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '↘  평균 외식비 대비 18% 절약',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: OnboardingPage.fontFamily,
                        fontFamilyFallback: OnboardingPage.fontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 157.44317626953125,
          width: 280,
          height: 103.80681610107422,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: .9),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 12,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const _SavingsBars(),
          ),
        ),
      ],
    );
  }
}

class _StoreReportArtwork extends StatelessWidget {
  const _StoreReportArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8EEF6), Color(0xFFDDE6F0)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F172A),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const CustomPaint(
            painter: _ReportMapPainter(),
            child: SizedBox.expand(),
          ),
        ),
        const Positioned(left: 78, top: 70, child: _PulsePin()),
        const Positioned(
          left: 125.13,
          top: 62,
          child: Text('✨', style: TextStyle(fontSize: 18, height: 1.5)),
        ),
        Positioned(
          left: 30,
          top: 144.73,
          width: 220,
          height: 97.27272033691406,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0x33F97316), width: .9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E0F172A),
                  blurRadius: 15,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: const [
                Positioned(left: 14, top: 14, child: _ReportBadge()),
                Positioned(
                  right: 15,
                  top: 16,
                  child: Text(
                    '방금 등록',
                    style: TextStyle(
                      color: OnboardingPage.muted,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 38.98,
                  child: Text(
                    '골목밥상',
                    style: TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 63.47,
                  child: Text(
                    '제육덮밥',
                    style: TextStyle(
                      color: OnboardingPage.muted,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 61.97,
                  child: Text(
                    '6,000원',
                    style: TextStyle(
                      color: OnboardingPage.orange,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapLegendPill extends StatelessWidget {
  const _MapLegendPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26.988636016845703,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Dot(color: OnboardingPage.blue),
          SizedBox(width: 8),
          Text(
            '정부 인증',
            style: TextStyle(
              color: Color(0xFF0A0A0A),
              fontFamily: OnboardingPage.fontFamily,
              fontFamilyFallback: OnboardingPage.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          SizedBox(width: 10),
          _Dot(color: OnboardingPage.orange),
          SizedBox(width: 8),
          Text(
            '사용자 제보',
            style: TextStyle(
              color: Color(0xFF0A0A0A),
              fontFamily: OnboardingPage.fontFamily,
              fontFamilyFallback: OnboardingPage.fontFallback,
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

class _PriceBubble extends StatelessWidget {
  const _PriceBubble();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 24,
          decoration: BoxDecoration(
            color: OnboardingPage.blue,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '●  5,500원',
            style: TextStyle(
              color: Colors.white,
              fontFamily: OnboardingPage.fontFamily,
              fontFamilyFallback: OnboardingPage.fontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(
          width: 9,
          height: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(color: OnboardingPage.blue),
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.727),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.place_rounded, color: Colors.white, size: 13),
    );
  }
}

class _PulsePin extends StatelessWidget {
  const _PulsePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: OnboardingPage.orange.withValues(alpha: .2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: OnboardingPage.orange,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3.636),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66F97316),
              blurRadius: 7,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.place_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OnboardingPage.blue.withValues(alpha: .2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * .39,
        height: size * .39,
        decoration: BoxDecoration(
          color: OnboardingPage.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.727),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox(
        width: 7.997159004211426,
        height: 7.997159004211426,
      ),
    );
  }
}

class _SavingsBars extends StatelessWidget {
  const _SavingsBars();

  @override
  Widget build(BuildContext context) {
    const bars = [
      (40.0, '1주', Color(0xFFBFDBFE)),
      (65.0, '2주', Color(0xFFBFDBFE)),
      (50.0, '3주', Color(0xFFBFDBFE)),
      (80.0, '4주', OnboardingPage.green),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.9, 16.9, 16.9, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: bars.map((bar) {
          return SizedBox(
            width: 43.99147415161133,
            height: 86,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 18,
                  width: 21.988636016845703,
                  height: bar.$1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bar.$3,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Text(
                    bar.$2,
                    style: const TextStyle(
                      color: OnboardingPage.muted,
                      fontFamily: OnboardingPage.fontFamily,
                      fontFamilyFallback: OnboardingPage.fontFallback,
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportBadge extends StatelessWidget {
  const _ReportBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20.99431800842285,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Dot(color: OnboardingPage.orange),
          SizedBox(width: 5),
          Text(
            '사용자 제보',
            style: TextStyle(
              color: OnboardingPage.orange,
              fontFamily: OnboardingPage.fontFamily,
              fontFamilyFallback: OnboardingPage.fontFallback,
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

class _FigmaMapPainter extends CustomPainter {
  const _FigmaMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.square;
    final park = Paint()..color = const Color(0xFFD8F0D7);

    canvas.drawLine(Offset(0, 116), Offset(size.width, 105), road);
    canvas.drawLine(Offset(0, 210), Offset(size.width, 194), road);
    canvas.drawLine(Offset(95, 0), Offset(86, size.height), road);
    canvas.drawLine(Offset(200, 0), Offset(215, size.height), road);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(140, 160, 80, 80),
        const Radius.circular(10),
      ),
      park,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportMapPainter extends CustomPainter {
  const _ReportMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(0, 96), Offset(size.width, 86), road);
    canvas.drawLine(Offset(100, 0), Offset(92, size.height), road);
    canvas.drawLine(Offset(0, 135), Offset(size.width, 124), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

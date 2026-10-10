import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:howmuch/shared/widgets/keep_all_text.dart';

class RecommendationRadiusButton extends ConsumerWidget {
  const RecommendationRadiusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = ref.watch(recommendationRadiusProvider);
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          // Stays inside the 430 app column on a wide browser window instead
          // of Material's 640 default, like the search filter sheet.
          constraints: const BoxConstraints(
            maxWidth: FigmaMobileCanvas.maxWebWidth,
          ),
          builder: (_) => RecommendationRadiusSheet(initialMeters: radius),
        );
        if (selected == null || selected == radius || !context.mounted) {
          return;
        }
        final notifier = ref.read(recommendationRadiusProvider.notifier);
        final saved = await notifier.setRadius(selected);
        if (saved || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          // The distance is in use; it just will not outlast this visit.
          HowmuchSnackBar(
            tone: HowmuchSnackBarTone.info,
            content: KeepAllText(
              notifier.accountId.isEmpty
                  // A guest has no account to keep the choice under.
                  ? '추천 거리를 이번 접속에 적용했어요.\n로그인하면 다음에도 유지돼요.'
                  : '추천 거리를 이번 접속에 적용했어요.\n기기 저장을 허용하면 다음에도 유지돼요.',
              style: const TextStyle(),
            ),
          ),
        );
      },
      icon: const Icon(Icons.near_me_outlined, size: 16),
      label: Text('${radius ~/ 1000}km 이내'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

/// Picks the recommendation distance by dragging a knob along a 1–15km
/// track. Closing the sheet without the button keeps the current distance.
class RecommendationRadiusSheet extends StatefulWidget {
  const RecommendationRadiusSheet({super.key, required this.initialMeters});

  final int initialMeters;

  static const minKm = 1;
  static const maxKm = 15;

  @override
  State<RecommendationRadiusSheet> createState() =>
      _RecommendationRadiusSheetState();
}

class _RecommendationRadiusSheetState extends State<RecommendationRadiusSheet> {
  late int _km = (widget.initialMeters ~/ 1000).clamp(
    RecommendationRadiusSheet.minKm,
    RecommendationRadiusSheet.maxKm,
  );

  void _onChanged(double value) {
    final km = value.round();
    if (km == _km) return;
    HapticFeedback.selectionClick();
    setState(() => _km = km);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        // Scrolls only when large text makes the sheet taller than the screen.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 14),
              const Text(
                '추천 거리',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const KeepAllText(
                'AI 채팅과 오늘의 픽에 함께 적용돼요. 기존 대화는 그대로 두고 다음 질문부터 적용해요.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              _DistanceReadout(km: _km),
              const SizedBox(height: 16),
              _DistanceSlider(km: _km, onChanged: _onChanged),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, _km * 1000),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text('${_km}km 이내로 적용하기', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderMedium,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The picked distance in large type, with what it means underneath.
class _DistanceReadout extends StatelessWidget {
  const _DistanceReadout({required this.km});

  final int km;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The slider reads the distance out; this is its large echo.
        ExcludeSemantics(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: AppColors.primary),
              children: [
                TextSpan(
                  text: '$km',
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -1.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const TextSpan(
                  text: 'km',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                const TextSpan(
                  text: ' 이내',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '반경 ${km}km 안의 매장을 추천해요',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// A 1km-step slider with a round knob and a 1·5·10·15km scale under it.
class _DistanceSlider extends StatelessWidget {
  const _DistanceSlider({required this.km, required this.onChanged});

  final int km;
  final ValueChanged<double> onChanged;

  static const _min = RecommendationRadiusSheet.minKm;
  static const _max = RecommendationRadiusSheet.maxKm;
  static const _trackHeight = 8.0;
  static const _knobRadius = 14.0;
  static const _overlayRadius = 24.0;
  static const _trackShape = RoundedRectSliderTrackShape();
  static const _scale = [1, 5, 10, 15];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: _trackHeight,
            trackShape: _trackShape,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: const Color(0xFFE8EDF5),
            activeTickMarkColor: AppColors.white.withValues(alpha: .6),
            inactiveTickMarkColor: const Color(0xFFC5CFDD),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.75),
            thumbShape: const _KnobShape(radius: _knobRadius),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: _overlayRadius,
            ),
            overlayColor: AppColors.primary.withValues(alpha: .12),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: km.toDouble(),
            min: _min.toDouble(),
            max: _max.toDouble(),
            divisions: _max - _min,
            label: '추천 거리',
            semanticFormatterCallback: (value) => '${value.round()}km 이내',
            onChanged: onChanged,
          ),
        ),
        ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The slider insets its track by the overlay radius, and a
              // rounded track keeps its stops half the track height further in.
              final inset =
                  _overlayRadius +
                  (_trackShape.isRounded ? _trackHeight / 2 : 0);
              final span = constraints.maxWidth - inset * 2;
              // Sits a little closer to the track than the slider's own
              // touch area would leave it.
              return Transform.translate(
                offset: const Offset(0, -6),
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(12) * 1.5,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final mark in _scale)
                        Positioned(
                          left: inset + span * (mark - _min) / (_max - _min),
                          // Centered on its stop at any text size.
                          child: FractionalTranslation(
                            translation: const Offset(-.5, 0),
                            child: Text(
                              '${mark}km',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: mark == km
                                    ? AppColors.primary
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: mark == km
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A white knob ringed in the brand blue that grows a little while held.
class _KnobShape extends SliderComponentShape {
  const _KnobShape({required this.radius});

  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final knobRadius = radius + 2 * activationAnimation.value;
    canvas
      ..drawCircle(
        center.translate(0, 1.5),
        knobRadius,
        Paint()
          ..color = const Color(0x330F172A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(center, knobRadius, Paint()..color = AppColors.white)
      ..drawCircle(
        center,
        knobRadius - 1.75,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
  }
}

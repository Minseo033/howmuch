import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/features/savings/presentation/state/savings_state.dart';

class SavingsGoalSettingScreen extends StatefulWidget {
  const SavingsGoalSettingScreen({super.key});

  @override
  State<SavingsGoalSettingScreen> createState() =>
      _SavingsGoalSettingScreenState();
}

class _SavingsGoalSettingScreenState extends State<SavingsGoalSettingScreen> {
  late TextEditingController _goalController;
  final SavingsGlobalState _state = SavingsGlobalState();

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: _state.monthlyGoal.value.toString(),
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _saveGoal() {
    final int newGoal =
        int.tryParse(_goalController.text.replaceAll(',', '')) ?? 30000;
    _state.monthlyGoal.value = newGoal;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          // Content Scroll
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topOffset + 48.878, // Below header
                bottom: 88.878 + bottomOffset, // Above bottom button
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSizes.itemSpacing),
                  // This Month's Goal Card
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.horizontalPadding,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 0.909,
                        ),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _state.currentSaved,
                        builder: (context, currentSaved, _) {
                          return ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _goalController,
                            builder: (context, textValue, _) {
                              final int currentGoal =
                                  int.tryParse(
                                    textValue.text.replaceAll(',', ''),
                                  ) ??
                                  1;
                              final double currentPercentage =
                                  (currentSaved / currentGoal * 100).clamp(
                                    0,
                                    100,
                                  );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '이번 달 절약 목표',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      height: 16.5 / 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FA),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF2563EB),
                                        width: 0.909,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _goalController,
                                            cursorColor: const Color(
                                              0xFF2563EB,
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontFamilyFallback: [
                                                'Noto Sans KR',
                                              ],
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              fontSize: 24,
                                              height: 36 / 24,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        const Text(
                                          '원',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontFamilyFallback: [
                                              'Noto Sans KR',
                                            ],
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                            height: 19.5 / 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.largeSpacing),
                  // Category Goals
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: Text(
                      '카테고리별 목표',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['Noto Sans KR'],
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        height: 16.5 / 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.smallSpacing),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        _buildCategoryGoal(
                          iconEmoji: '🍚',
                          category: '음식점',
                          current: '14,500원',
                          total: ' / 20,000원',
                          currentColor: const Color(0xFF2563EB),
                          barColor: const Color(0xFF2563EB),
                          percentage: 72.5,
                        ),
                        const SizedBox(height: 10),
                        _buildCategoryGoal(
                          iconEmoji: '☕',
                          category: '카페',
                          current: '6,500원',
                          total: ' / 8,000원',
                          currentColor: const Color(0xFFF97316),
                          barColor: const Color(0xFFF97316),
                          percentage: 81.25,
                        ),
                        const SizedBox(height: 10),
                        _buildCategoryGoal(
                          iconEmoji: '✂️',
                          category: '생활서비스',
                          current: '3,500원',
                          total: ' / 5,000원',
                          currentColor: const Color(0xFF10B981),
                          barColor: const Color(0xFF10B981),
                          percentage: 70.0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.largeSpacing),
                  // Info Box
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💡', style: TextStyle(fontSize: 14)),
                          SizedBox(width: AppSizes.smallSpacing),
                          Expanded(
                            child: Text(
                              '목표를 설정하면 달성률을 확인하고\n오늘의 픽 추천에도 반영돼요.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF065F46),
                                fontSize: 11,
                                height: 16.5 / 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Custom AppBar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: topOffset + 48.878,
              padding: EdgeInsets.only(top: topOffset),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: AppSizes.horizontalPadding,
                    top: 13.98,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        '절약 목표',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0A0A),
                          fontSize: 16,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: AppSizes.horizontalPadding,
                    top: 15.48,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        size: 24,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Fixed Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.horizontalPadding,
                    right: AppSizes.horizontalPadding,
                    top: 13,
                    bottom: 12,
                  ),
                  child: GestureDetector(
                    onTap: _saveGoal,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(16, 185, 129, 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '목표 저장하기',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15,
                              height: 22.5 / 15,
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

  Widget _buildCategoryGoal({
    required String iconEmoji,
    required String category,
    required String current,
    required String total,
    required Color currentColor,
    required Color barColor,
    required double percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.909),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(iconEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSizes.smallSpacing),
                  Text(
                    category,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: ['Noto Sans KR'],
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      height: 19.5 / 13,
                    ),
                  ),
                ],
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['Noto Sans KR'],
                    fontSize: 12,
                    height: 18 / 12,
                  ),
                  children: [
                    TextSpan(
                      text: current,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentColor,
                      ),
                    ),
                    TextSpan(
                      text: total,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (percentage * 10).toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1000 - (percentage * 10).toInt(),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

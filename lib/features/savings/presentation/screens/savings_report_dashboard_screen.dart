import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:howmuch/features/savings/presentation/state/savings_state.dart';

class SavingsReportDashboardScreen extends StatefulWidget {
  const SavingsReportDashboardScreen({super.key});

  @override
  State<SavingsReportDashboardScreen> createState() =>
      _SavingsReportDashboardScreenState();
}

class _SavingsReportDashboardScreenState
    extends State<SavingsReportDashboardScreen> {
  String _selectedTab = '이번 달';
  final SavingsGlobalState _state = SavingsGlobalState();

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final bottomNavHeight = HowmuchBottomNav.heightFor(bottomOffset);

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          Positioned.fill(child: const ColoredBox(color: Color(0xFFF4F6FA))),

          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom AppBar (Pinned)
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    top: topOffset + 11.98876953125,
                    bottom: 12,
                    left: AppSizes.horizontalPadding,
                    right: AppSizes.horizontalPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '절약 리포트',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: Color(0xFF0A0A0A),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push(AppRoutes.savingsGoalSetting),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    color: Color(0xFF10B981),
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '목표 설정',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.itemSpacing),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.notifications),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF0F172A),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs (Pinned)
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSizes.horizontalPadding,
                          right: AppSizes.horizontalPadding,
                          bottom: 12,
                        ),
                        child: Row(
                          children: [
                            _buildTab('이번 달'),
                            const SizedBox(width: AppSizes.smallSpacing),
                            _buildTab('지난 달'),
                            const SizedBox(width: AppSizes.smallSpacing),
                            _buildTab('올해'),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 0.909,
                        color: Color(0xFFE5E7EB),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomNavHeight + 20),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _state.currentSaved,
                      builder: (context, currentSavedValue, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _state.monthlyGoal,
                          builder: (context, goalValue, child) {
                            return _buildDynamicContent(
                              currentSavedValue,
                              goalValue,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Nav
          Positioned(
            left: 0,
            width: FigmaMobileCanvas.width,
            bottom: 0,
            height: bottomNavHeight,
            child: HowmuchBottomNav(
              activeTab: HowmuchBottomTab.report,
              safeBottom: bottomOffset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicContent(int currentSaved, int monthlyGoal) {
    String titlePrefix = '';
    int displayedSaved = 0;
    String chartTitle = '';
    String chartDate = '';
    List<Widget> chartBars = [];
    int visits = 0, favorites = 0, reports = 0;
    String recommendationSub = '';

    if (_selectedTab == '이번 달') {
      titlePrefix = '이번 달';
      displayedSaved = currentSaved;
      chartTitle = '주차별 절약 금액';
      chartDate = '2026.05';
      chartBars = [
        _buildBar(label: '1주', amount: '4,500원', height: 50, isMax: false),
        _buildBar(label: '2주', amount: '7,800원', height: 90, isMax: true),
        _buildBar(label: '3주', amount: '5,200원', height: 60, isMax: false),
        _buildBar(label: '4주', amount: '7,000원', height: 80, isMax: false),
      ];
      visits = 6;
      favorites = 12;
      reports = 2;
      recommendationSub = '한식 매장에서 더 아낄 수 있어요';
    } else if (_selectedTab == '지난 달') {
      titlePrefix = '지난 달';
      displayedSaved = 32000;
      chartTitle = '주차별 절약 금액';
      chartDate = '2026.04';
      chartBars = [
        _buildBar(label: '1주', amount: '6,000원', height: 60, isMax: false),
        _buildBar(label: '2주', amount: '8,000원', height: 80, isMax: false),
        _buildBar(label: '3주', amount: '9,000원', height: 100, isMax: true),
        _buildBar(label: '4주', amount: '9,000원', height: 100, isMax: true),
      ];
      visits = 8;
      favorites = 15;
      reports = 5;
      recommendationSub = '주말 카페 지출을 줄여보세요';
    } else {
      titlePrefix = '올해';
      displayedSaved = 154000;
      chartTitle = '월별 절약 금액';
      chartDate = '2026';
      chartBars = [
        _buildBar(label: '1월', amount: '3만', height: 60, isMax: false),
        _buildBar(label: '2월', amount: '2.5만', height: 50, isMax: false),
        _buildBar(label: '3월', amount: '3.5만', height: 70, isMax: false),
        _buildBar(label: '4월', amount: '4만', height: 100, isMax: true),
        _buildBar(label: '5월', amount: '2.4만', height: 40, isMax: false),
      ];
      visits = 45;
      favorites = 60;
      reports = 12;
      recommendationSub = '가장 많이 절약한 달은 4월이에요';
    }

    // Format the number
    final formattedSaved = displayedSaved.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Percentage relative to monthly goal (if applicable, else just a static mock)
    int percentage = 18; // Default mock
    if (_selectedTab == '이번 달' && monthlyGoal > 0) {
      percentage = ((displayedSaved / monthlyGoal) * 100).toInt();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.horizontalPadding),
          child: Column(
            children: [
              // Savings Card
              GestureDetector(
                onTap: () => context.push(AppRoutes.savingsDetail),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.horizontalPadding),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.savings_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$titlePrefix 절약 금액',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formattedSaved,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '원',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.largeSpacing),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedTab == '이번 달'
                              ? '목표 대비 $percentage% 달성'
                              : '평균 대비 $percentage% 절약',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.horizontalPadding,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Text('🍗', style: TextStyle(fontSize: 16)),
                            SizedBox(width: AppSizes.smallSpacing),
                            Text(
                              '치킨 한 마리 값에 가까워요',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.itemSpacing),

              // Chart Card
              GestureDetector(
                onTap: () => context.push(AppRoutes.savingsDetail),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.horizontalPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chartTitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF0A0A0A),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            chartDate,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chartBars,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.itemSpacing),

              // Stats Row
              Row(
                children: [
                  _buildStatCard('$visits', '방문 매장', const Color(0xFF2563EB)),
                  _buildStatCard(
                    '$favorites',
                    '찜한 매장',
                    const Color(0xFFF97316),
                  ),
                  _buildStatCard('$reports', '제보 매장', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: AppSizes.itemSpacing),

              // Recommendation Banner
              GestureDetector(
                onTap: () => context.push(AppRoutes.todaysPick),
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.horizontalPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Color(0xFFF97316),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '이번 주 추천',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF92400E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              recommendationSub,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF92400E)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String text) {
    final isSelected = _selectedTab == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.horizontalPadding,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Noto Sans KR'],
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required String amount,
    required double height,
    required bool isMax,
  }) {
    return Column(
      children: [
        if (isMax)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '최대',
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                color: Color(0xFF2563EB),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (isMax) const SizedBox(height: 4),
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: isMax ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: AppSizes.smallSpacing),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['Noto Sans KR'],
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Noto Sans KR'],
            color: isMax ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            fontSize: 11,
            fontWeight: isMax ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: const ['Noto Sans KR'],
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

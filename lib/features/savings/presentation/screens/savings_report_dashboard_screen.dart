import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

class SavingsReportDashboardScreen extends StatelessWidget {
  const SavingsReportDashboardScreen({super.key});

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
          // Background for body
          Positioned.fill(child: const ColoredBox(color: Color(0xFFF4F6FA))),

          // Scrollable Content
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                bottom: bottomNavHeight + 20,
              ),
              child: SizedBox(
                width: FigmaMobileCanvas.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Custom AppBar (now scrolls!)
                    Container(
                      width: FigmaMobileCanvas.width,
                      color: Colors.white,
                      padding: EdgeInsets.only(top: topOffset, bottom: 12, left: 20, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '절약 리포트',
                            style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                              color: Color(0xFF0A0A0A),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F8F1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.flag, color: Color(0xFF10B981), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      '목표 설정',
                                      style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                        color: Color(0xFF10B981),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_none, color: Color(0xFF0A0A0A), size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Main Content Body (Exactly 335.45 wide, perfectly centered -> 20px margins)
                    SizedBox(
                      width: 335.45452880859375,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tabs
                          Row(
                            children: [
                              _buildTab('이번 달', isSelected: true),
                              const SizedBox(width: 8),
                              _buildTab('지난 달', isSelected: false),
                              const SizedBox(width: 8),
                              _buildTab('올해', isSelected: false),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Savings Card
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.savingsDetail),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF059669), Color(0xFF34D399)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.savings_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '이번 달 절약 금액',
                                        style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '24,500',
                                        style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                          color: Colors.white,
                                          fontSize: 42,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1.2,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '원',
                                        style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '평균 외식비 대비 18% 절약',
                                      style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      children: [
                                        Text('🍗', style: TextStyle(fontSize: 16)),
                                        SizedBox(width: 8),
                                        Text(
                                          '치킨 한 마리 값에 가까워요',
                                          style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
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
                          const SizedBox(height: 16),

                          // Chart Card
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.savingsDetail),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '주차별 절약 금액',
                                        style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                          color: Color(0xFF0A0A0A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '2026.05',
                                        style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
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
                                    children: [
                                      _buildBar(label: '1주', amount: '8.4k', height: 40, isMax: false),
                                      _buildBar(label: '2주', amount: '12.1k', height: 60, isMax: false),
                                      _buildBar(label: '3주', amount: '24.5k', height: 100, isMax: true),
                                      _buildBar(label: '4주', amount: '-', height: 0, isMax: false),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stats Row
                          Row(
                            children: [
                              _buildStatCard('6', '방문 매장', const Color(0xFF0A0A0A)),
                              _buildStatCard('12', '아낀 횟수', const Color(0xFF0A0A0A)),
                              _buildStatCard('2', '제보 매장', const Color(0xFFF59E0B)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Recommendation Banner
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.todaysPick),
                            child: Container(
                              padding: const EdgeInsets.all(16),
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
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '이번 주 추천',
                                          style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                                            color: Color(0xFF92400E),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '한식 매장에서 더 아낄 수 있어요',
                                          style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
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
                ),
              ),
            ),
          ),
          
          // Bottom Nav
          Positioned(
            left: 0,
            width: FigmaMobileCanvas.width,
            bottom: 0,
            height: bottomNavHeight,
            child: HowmuchBottomNav(
              safeBottom: bottomOffset,
              activeTab: HowmuchBottomTab.savings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2563EB) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: isSelected ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
          color: isSelected ? Colors.white : const Color(0xFF475569),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
        Text(
          amount,
          style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
            color: isMax ? const Color(0xFF10B981) : const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: height,
          decoration: BoxDecoration(
            gradient: isMax
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Noto Sans KR'], 
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

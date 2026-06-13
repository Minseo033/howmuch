import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class PriceHistoryScreen extends StatelessWidget {
  const PriceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 가격 이력 데이터 연동
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: const CustomAppBar(title: '가격 이력'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentPriceCard(),
              const SizedBox(height: 24),
              const Text(
                '최근 12개월 추이',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildBarChart(),
              const SizedBox(height: 24),
              const Text(
                '변동 이력',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHistoryTimeline(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomButton(
        text: '가격 변동 제보하기',
        backgroundColor: AppColors.orangeTheme,
        onPressed: () {
          context.push('/home/price_report');
        },
      ),
    );
  }

  Widget _buildCurrentPriceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '착한분식 · 김치찌개',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  '현재 등록 가격',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Text(
            '5,500원',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    // 12개월 데이터: 앞 5개월은 5,000원(이전), 나머지 7개월은 5,500원(현재)
    final bars = List.generate(12, (i) => i >= 5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((isCurrent) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.success
                          : AppColors.tealLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    height: isCurrent ? 100 : 72,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '2025.06',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              Text(
                '현재',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '5,500원 (현재)',
                style: TextStyle(fontSize: 12, color: AppColors.textDark),
              ),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '5,000원 (이전)',
                style: TextStyle(fontSize: 12, color: AppColors.textDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTimeline() {
    final items = [
      {
        'price': '5,500원',
        'isGov': true,
        'desc': '공공데이터 업데이트',
        'date': '2026.05.10',
        'isActive': true,
        'diff': null,
      },
      {
        'price': '5,500원',
        'isGov': false,
        'desc': '사용자 제보 반영',
        'date': '2026.04.01',
        'isActive': false,
        'diff': null,
      },
      {
        'price': '5,500원',
        'isGov': true,
        'desc': '공공데이터 업데이트',
        'date': '2026.01.15',
        'isActive': false,
        'diff': '+500원',
      },
      {
        'price': '5,000원',
        'isGov': true,
        'desc': '최초 등록',
        'date': '2025.06.01',
        'isActive': false,
        'diff': null,
      },
    ];

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isActive = item['isActive'] as bool;
        final isGov = item['isGov'] as bool;
        final diff = item['diff'] as String?;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타임라인 dot + line
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i < items.length - 1)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // 내용 카드
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: i < items.length - 1 ? 10 : 0,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['price'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isGov
                                        ? AppColors.primarySubtle
                                        : AppColors.orangeLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: isGov
                                            ? AppColors.primary
                                            : AppColors.orangeTheme,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isGov ? '정부 인증' : '사용자 제보',
                                        style: TextStyle(
                                          color: isGov
                                              ? AppColors.primary
                                              : AppColors.orangeTheme,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item['desc'] as String,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['date'] as String,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (diff != null)
                        Text(
                          '↑ $diff',
                          style: const TextStyle(
                            color: AppColors.orangeTheme,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

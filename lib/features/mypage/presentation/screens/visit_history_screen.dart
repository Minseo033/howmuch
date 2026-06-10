import 'package:flutter/material.dart';
import 'package:howmuch/app/app_routes.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/status_badge.dart';

class VisitHistoryScreen extends StatelessWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 방문 기록 및 누적 절약 금액 연동
    final items = [
      {
        'isGov': true,
        'name': '착한분식',
        'menu': '김치찌개',
        'price': '5,500원',
        'saving': '2,000원 절약',
        'date': '2026.05.10',
        'icon': Icons.smart_toy_rounded,
      },
      {
        'isGov': false,
        'name': '동네카페',
        'menu': '아메리카노',
        'price': '2,000원',
        'saving': '2,300원 절약',
        'date': '2026.05.07',
        'icon': Icons.local_cafe_rounded,
      },
      {
        'isGov': true,
        'name': '착한칼국수',
        'menu': '칼국수',
        'price': '5,000원',
        'saving': '1,500원 절약',
        'date': '2026.05.04',
        'icon': Icons.smart_toy_rounded,
      },
      {
        'isGov': true,
        'name': '정다운식당',
        'menu': '백반',
        'price': '6,500원',
        'saving': '1,500원 절약',
        'date': '2026.04.28',
        'icon': Icons.smart_toy_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: '방문 기록',
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: RichText(
                text: const TextSpan(
                  text: '총 ',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '4',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '회'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSummaryCard(),
            Expanded(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _buildVisitCard(items[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: const [
                Text(
                  '6',
                  style: TextStyle(
                      color: Color(0xFF2ECA7F),
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('이번 달 방문',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          Container(
              width: 1, height: 44, color: Colors.green.shade200),
          Expanded(
            child: Column(
              children: const [
                Text(
                  '24,500원',
                  style: TextStyle(
                      color: Color(0xFF2ECA7F),
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('이번 달 절약',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> item) {
    final isGov = item['isGov'] as bool;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isGov
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: isGov
                  ? const Color(0xFF4A68F6)
                  : const Color(0xFFF27E22),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 배지 + 이름 + 날짜
                Row(
                  children: [
                    StatusBadge(
                        type: isGov
                            ? BadgeType.government
                            : BadgeType.user),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Text(
                      item['date'] as String,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // 메뉴 · 가격
                Text(
                  '${item['menu']} · ${item['price']}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 6),
                // 절약 금액
                Row(
                  children: [
                    const Text('🪙',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      item['saving'] as String,
                      style: const TextStyle(
                          color: Color(0xFF2ECA7F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

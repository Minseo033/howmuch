import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/status_badge.dart';

class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 내 리뷰 내역 및 총 개수, 평균 별점 연동
    final reviews = [
      {
        'isGov': true,
        'name': '착한분식',
        'date': '2026.05.10',
        'rating': 5,
        'visitedMenu': '김치찌개',
        'content': '가격이 저렴하고 양이 많아요. 재방문 의사 100%!',
        'likes': 24,
      },
      {
        'isGov': false,
        'name': '동네카페',
        'date': '2026.05.07',
        'rating': 4,
        'visitedMenu': '아메리카노',
        'content': '커피 맛있고 가격도 착해요. 다음에 또 갈게요.',
        'likes': 8,
      },
      {
        'isGov': true,
        'name': '착한미용실',
        'date': '2026.04.28',
        'rating': 5,
        'visitedMenu': '남성컷',
        'content': '실력도 좋고 가격도 착한 편이에요.',
        'likes': 15,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: '내 리뷰',
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: RichText(
                text: TextSpan(
                  text: '총 ',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '${reviews.length}',
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' 개'),
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
            _buildStatsHeader(reviews.length),
            Expanded(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: reviews.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildReviewCard(context, reviews[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      text: '$count',
                      style: const TextStyle(
                        color: Color(0xFF4A68F6),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      children: const [
                        TextSpan(
                          text: ' 개 작성',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 4),
                      Text(
                        '4.7',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '평균 별점',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, Map<String, dynamic> review) {
    final isGov = review['isGov'] as bool;
    final rating = review['rating'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(type: isGov ? BadgeType.government : BadgeType.user),
              Text(
                review['date'] as String,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review['name'] as String,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star_rounded,
                    color: index < rating ? Colors.orange : Colors.grey.shade300,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '방문: ${review['visitedMenu']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review['content'] as String,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Color(0xFF2ECA7F), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '도움이 돼요 ${review['likes']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      // TODO(박지환 BE): 리뷰 수정 API 연동
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '수정',
                      style: TextStyle(color: Color(0xFF4A68F6), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      // TODO(박지환 BE): 리뷰 삭제 API 연동
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '삭제',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

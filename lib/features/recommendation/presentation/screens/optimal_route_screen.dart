import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class OptimalRouteScreen extends StatelessWidget {
  const OptimalRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          // Header
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top: topOffset + 11.98876953125,
                bottom: 12,
                left: 8,
                right: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      '추천 루트',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),
          ),
          // Content
          Positioned.fill(
            top: topOffset + 50.96590805053711, // Below header
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 100 + bottomOffset),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '식사부터 카페까지 저렴한 동선을 추천해요',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    // Map Placeholder
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8EEF6), Color(0xFFDDE6F0)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.map,
                              color: Colors.black12,
                              size: 48,
                            ),
                          ),
                          // Mock markers
                          Positioned(
                            top: 40,
                            left: 60,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '1 착한분식',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 90,
                            right: 60,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '2 동네카페',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '추천 동선',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Route Steps
                    _buildRouteStep(
                      index: '1',
                      storeName: '착한분식',
                      details: '김치찌개 5,500원 · 320m',
                    ),
                    _buildConnection('도보 6분'),
                    _buildRouteStep(
                      index: '2',
                      storeName: '동네카페',
                      details: '아메리카노 2,000원 · 500m',
                    ),
                    const SizedBox(height: 16),
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '총 예상 비용',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '7,500원',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '예상 절약',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '약 4,300원',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: const Color(0xFF10B981).withOpacity(0.2),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(
                                Icons.directions_walk,
                                color: Color(0xFF64748B),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '총 820m',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                '예상 소요 12분',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sticky Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 16 + bottomOffset,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '이 루트로 길찾기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep({
    required String index,
    required String storeName,
    required String details,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              index,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnection(String timeText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.more_vert, color: Color(0xFFE5E7EB), size: 20),
          const SizedBox(width: 12),
          Text(
            timeText,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

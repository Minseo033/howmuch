import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';

class DirectionsExternalAppScreen extends StatefulWidget {
  const DirectionsExternalAppScreen({super.key});

  @override
  State<DirectionsExternalAppScreen> createState() =>
      _DirectionsExternalAppScreenState();
}

class _DirectionsExternalAppScreenState
    extends State<DirectionsExternalAppScreen> {
  int _selectedTransport = 0;

  final List<Map<String, dynamic>> _transports = [
    {'icon': Icons.directions_walk, 'label': '도보', 'time': '6분'},
    {'icon': Icons.directions_bus_rounded, 'label': '대중교통', 'time': '10분'},
    {'icon': Icons.directions_car_rounded, 'label': '자동차', 'time': '4분'},
  ];

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 실제 매장 위치 및 거리 연동
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(title: '길찾기'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreCard(),
              const SizedBox(height: 24),
              const Text('이동 방식',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTransportOptions(),
              const SizedBox(height: 24),
              const Text('외부 앱으로 열기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildAppButton(
                badge: 'N',
                color: const Color(0xFF03C75A),
                label: '네이버지도에서 열기',
                textColor: Colors.white,
              ),
              const SizedBox(height: 10),
              _buildAppButton(
                badge: 'K',
                color: const Color(0xFFFEE500),
                label: '카카오맵에서 열기',
                textColor: Colors.black87,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '외부 지도 앱으로 이동해 경로를 확인할 수 있어요.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomButton(
        text: '길찾기 시작',
        backgroundColor: const Color(0xFF4A68F6),
        onPressed: () {
          // TODO: 외부 지도 앱 실행 (url_launcher)
        },
      ),
    );
  }

  Widget _buildStoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF4A68F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('착한분식',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('서울시 강남구 역삼동',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('320m',
                      style: TextStyle(
                          color: Color(0xFF4A68F6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportOptions() {
    return Row(
      children: List.generate(_transports.length, (i) {
        final selected = _selectedTransport == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTransport = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                  right: i < _transports.length - 1 ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEEF2FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF4A68F6)
                      : Colors.grey.shade200,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _transports[i]['icon'] as IconData,
                    color: selected
                        ? const Color(0xFF4A68F6)
                        : Colors.grey.shade500,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _transports[i]['label'] as String,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF4A68F6)
                          : Colors.black87,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _transports[i]['time'] as String,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF4A68F6)
                          : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAppButton({
    required String badge,
    required Color color,
    required String label,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () {
        // TODO: url_launcher로 외부 앱 실행
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

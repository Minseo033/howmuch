import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';

class VisitVerificationScreen extends StatefulWidget {
  const VisitVerificationScreen({super.key});

  @override
  State<VisitVerificationScreen> createState() =>
      _VisitVerificationScreenState();
}

class _VisitVerificationScreenState extends State<VisitVerificationScreen> {
  // 0: 위치 인증, 1: 영수증 인증
  int _selectedMethod = 0;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 매장 위치/거리 연동, 인증 API 연동
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: const CustomAppBar(title: '방문 인증'),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 매장 카드
                _buildStoreCard(),
                const SizedBox(height: 24),
                const Text(
                  '인증 방식 선택',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // 위치 인증 카드
                _buildVerifyCard(
                  index: 0,
                  iconBgColor: const Color(0xFF4A68F6),
                  icon: Icons.location_on_rounded,
                  title: '위치로 인증하기',
                  desc: '매장 근처에 있을 때 인증할 수 있어요. 현재 거리: 320m',
                  extra: null,
                ),
                const SizedBox(height: 12),
                // 영수증 인증 카드
                _buildVerifyCard(
                  index: 1,
                  iconBgColor: const Color(0xFFF27E22),
                  icon: Icons.receipt_long_rounded,
                  title: '영수증 사진으로 인증하기',
                  desc: '영수증을 촬영해서 결제 금액을 등록할 수 있어요.',
                  extra: _selectedMethod == 1
                      ? _buildReceiptInput()
                      : null,
                ),
                const SizedBox(height: 24),
                // 예상 절약 금액 카드
                _buildSavingsCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '방문 인증하기',
          backgroundColor: const Color(0xFF4A68F6),
          onPressed: () {
            // TODO: 방문 인증 요청 및 2-8로 이동
          },
        ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('착한분식',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('김치찌개 5,500원',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '320m',
              style: TextStyle(
                  color: Color(0xFF4A68F6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyCard({
    required int index,
    required Color iconBgColor,
    required IconData icon,
    required String title,
    required String desc,
    required Widget? extra,
  }) {
    final selected = _selectedMethod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF4A68F6) : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(desc,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? const Color(0xFF4A68F6)
                      : Colors.grey.shade300,
                  size: 22,
                ),
              ],
            ),
            if (extra != null) ...[
              const SizedBox(height: 14),
              extra,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptInput() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            // TODO: 영수증 사진 촬영
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined,
                    color: Colors.grey.shade400, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '결제 금액 입력',
              hintStyle: const TextStyle(color: Colors.grey),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4A68F6)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFF2ECA7F), size: 18),
              SizedBox(width: 6),
              Text('인증 후 예상 절약 금액',
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '약 2,000원 절약',
            style: TextStyle(
                color: Color(0xFF2ECA7F),
                fontSize: 26,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text('주변 평균 메뉴 가격 대비 산정',
              style: TextStyle(color: Colors.black45, fontSize: 12)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';

class PriceChangeReportScreen extends StatefulWidget {
  const PriceChangeReportScreen({super.key});

  @override
  State<PriceChangeReportScreen> createState() =>
      _PriceChangeReportScreenState();
}

class _PriceChangeReportScreenState extends State<PriceChangeReportScreen> {
  // 0: 가격 인상, 1: 가격 인하, 2: 메뉴 삭제, 3: 신규 메뉴
  int _selectedType = 0;
  bool _isConfirmed = true;

  final _menuController = TextEditingController(text: '아메리카노');
  final _priceController = TextEditingController(text: '2,500');
  final _descController = TextEditingController();

  final List<Map<String, String>> _changeTypes = [
    {'label': '↗  가격 인상', 'value': 'rise'},
    {'label': '↘  가격 인하', 'value': 'drop'},
    {'label': '메뉴 삭제', 'value': 'delete'},
    {'label': '신규 메뉴', 'value': 'new'},
  ];

  @override
  void dispose() {
    _menuController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 가격 변동 제보 API 연동
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const CustomAppBar(title: '가격 변동 제보'),
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

                // 변동 유형
                const Text('변동 유형',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildTypeGrid(),
                const SizedBox(height: 24),

                // 변경된 메뉴
                const Text('변경된 메뉴',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildTextField(_menuController, '아메리카노'),
                const SizedBox(height: 20),

                // 변경된 가격 (삭제 유형 제외)
                if (_selectedType != 2) ...[
                  const Text('변경된 가격',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildPriceField(),
                  const SizedBox(height: 20),
                ],

                // 메뉴판 사진
                const Text('메뉴판 사진',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildPhotoButton(),
                const SizedBox(height: 20),

                // 설명
                const Text('설명',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDescField(),
                const SizedBox(height: 16),

                // 확인 체크박스
                _buildCheckbox(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '가격 변동 제보하기',
          backgroundColor: const Color(0xFFF27E22),
          onPressed: () {
            // TODO: 가격 변동 제보 제출
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('동네카페',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('기존 가격',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 2),
                Text('아메리카노',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const Text('2,000원',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTypeGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 3,
      children: List.generate(_changeTypes.length, (i) {
        final selected = _selectedType == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFF0E6)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFFF27E22)
                    : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              _changeTypes[i]['label']!,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFF27E22)
                    : Colors.black87,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF27E22)),
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFFF27E22)),
      decoration: InputDecoration(
        suffixText: '원',
        suffixStyle: const TextStyle(color: Colors.grey),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF27E22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF27E22), width: 2),
        ),
      ),
    );
  }

  Widget _buildPhotoButton() {
    return GestureDetector(
      onTap: () {
        // TODO: 사진 촬영/선택
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined,
                color: Colors.grey.shade400, size: 28),
            const SizedBox(height: 4),
            Text('0/3',
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDescField() {
    return TextField(
      controller: _descController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: '변동 내용을 간단히 알려주세요.',
        hintStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF27E22)),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isConfirmed,
          onChanged: (v) => setState(() => _isConfirmed = v ?? false),
          activeColor: const Color(0xFF4A68F6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        const Text('직접 메뉴판 가격을 확인했어요',
            style: TextStyle(fontSize: 14)),
      ],
    );
  }
}

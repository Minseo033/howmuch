import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';

class StoreInfoReportScreen extends StatefulWidget {
  const StoreInfoReportScreen({super.key});

  @override
  State<StoreInfoReportScreen> createState() => _StoreInfoReportScreenState();
}

class _StoreInfoReportScreenState extends State<StoreInfoReportScreen> {
  int _selectedTypeIndex = 1; // 기본: '가격이 달라요'

  final _priceController = TextEditingController(text: '6,000');
  final _descController = TextEditingController(
    text: '어제 방문했을 때 메뉴판에 6,000원으로 표기되어 있었어요.',
  );

  final List<Map<String, String>> _types = [
    {'title': '폐업됐어요', 'desc': '매장이 문을 닫은 것 같아요'},
    {'title': '가격이 달라요', 'desc': '등록된 가격과 실제 가격이 달라요'},
    {'title': '위치 정보가 틀려요', 'desc': '지도 위치가 잘못 표시돼요'},
    {'title': '기타', 'desc': '직접 내용을 작성할게요'},
  ];

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 매장 정보 신고 등록 API 연동
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const CustomAppBar(
          title: '정보 신고',
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 20),
              child: Icon(Icons.flag_outlined, color: Colors.grey),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreCard(),
                const SizedBox(height: 24),

                // 신고 유형 선택
                RichText(
                  text: const TextSpan(
                    text: '신고 유형 선택 ',
                    style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                    children: [TextSpan(text: '*', style: TextStyle(color: Color(0xFFF27E22)))],
                  ),
                ),
                const SizedBox(height: 12),
                _buildTypeList(),
                const SizedBox(height: 24),

                // 실제 가격 (가격이 달라요 선택 시)
                if (_selectedTypeIndex == 1) ...[
                  const Text('실제 가격 선택', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _buildPriceField(),
                  const SizedBox(height: 20),
                ],

                // 추가 설명
                const Text('추가 설명 선택', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _buildDescField(),
                const SizedBox(height: 20),

                _buildWarningBox(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '신고 접수하기',
          backgroundColor: const Color(0xFFF27E22),
          onPressed: () {
            // TODO: 신고 접수 요청
          },
        ),
      ),
    );
  }

  Widget _buildStoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.location_on_outlined, color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('착한분식', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('서울 강남구 역삼동 123-4 · 김치찌개 5,500원', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(_types.length, (i) {
          final selected = _selectedTypeIndex == i;
          return Column(
            children: [
              InkWell(
                onTap: () => setState(() => _selectedTypeIndex = i),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : i == _types.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(16))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: selected ? const Color(0xFF4A68F6) : Colors.grey.shade400,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_types[i]['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(_types[i]['desc']!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < _types.length - 1) Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        suffixText: '원',
        suffixStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4A68F6))),
      ),
    );
  }

  Widget _buildDescField() {
    return TextField(
      controller: _descController,
      maxLines: 3,
      decoration: InputDecoration(
        hintStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4A68F6))),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('신고는 운영팀이 확인 후 처리돼요.', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('허위 신고 시 이용이 제한될 수 있어요.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

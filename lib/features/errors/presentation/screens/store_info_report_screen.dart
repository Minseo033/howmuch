import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class StoreInfoReportScreen extends ConsumerStatefulWidget {
  const StoreInfoReportScreen({super.key, this.store});

  final Store? store;

  @override
  ConsumerState<StoreInfoReportScreen> createState() =>
      _StoreInfoReportScreenState();
}

class _StoreInfoReportScreenState extends ConsumerState<StoreInfoReportScreen> {
  int _selectedTypeIndex = 1; // 기본: '가격이 달라요'
  bool _isSubmitting = false;

  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  final List<Map<String, String>> _types = [
    {'title': '폐업됐어요', 'desc': '매장이 문을 닫은 것 같아요', 'value': 'closed'},
    {
      'title': '가격이 달라요',
      'desc': '등록된 가격과 실제 가격이 달라요',
      'value': 'price_mismatch',
    },
    {
      'title': '위치 정보가 틀려요',
      'desc': '지도 위치가 잘못 표시돼요',
      'value': 'location_wrong',
    },
    {'title': '기타', 'desc': '직접 내용을 작성할게요', 'value': 'other'},
  ];

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!ApiClient.isAuthenticated) {
      _showMessage('정보 신고는 로그인 후 이용할 수 있어요.');
      return;
    }
    final description = _descController.text.trim();
    final price = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (widget.store == null) {
      _showMessage('매장 정보가 없어 신고할 수 없어요.');
      return;
    }
    if (_selectedTypeIndex == 1 &&
        (price.isEmpty || int.tryParse(price) == 0)) {
      _showMessage('실제 가격을 입력해주세요.');
      return;
    }
    if (description.isEmpty) {
      _showMessage('신고 내용을 입력해주세요.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final store = widget.store!;
      await ref
          .read(reportServiceProvider)
          .submitReport(
            UserReport(
              storeId: store.id,
              storeName: store.storeName,
              industry: store.industry,
              address: store.address,
              phoneNumber: store.phoneNumber,
              menu1: store.menu1,
              price1: _selectedTypeIndex == 1 ? price : store.price1,
              latitude: store.latitude,
              longitude: store.longitude,
              imageUrls: const [],
              reporterId: '',
              visitedRecently: false,
              checkedMenuPrice: _selectedTypeIndex == 1,
              changeType: _types[_selectedTypeIndex]['value'],
              reportType: 'STORE_INFO',
              description: description,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정보 신고가 접수되었습니다. 관리자 확인 후 반영됩니다.')),
      );
      context.pop();
    } on ReportServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      debugPrint('매장 정보 신고 오류: $error');
      if (mounted) _showMessage('신고를 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: GestureDetector(
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
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: Color(0xFFF27E22)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTypeList(),
                  const SizedBox(height: 24),

                  // 실제 가격 (가격이 달라요 선택 시)
                  if (_selectedTypeIndex == 1) ...[
                    const Text(
                      '실제 가격 선택',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPriceField(),
                    const SizedBox(height: 20),
                  ],

                  // 추가 설명
                  const Text(
                    '추가 설명 선택',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
            text: _isSubmitting ? '접수 중...' : '신고 접수하기',
            backgroundColor: const Color(0xFFF27E22),
            onPressed: _isSubmitting ? null : _submit,
          ),
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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store?.storeName ?? '매장 정보 없음',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  widget.store?.address ?? '매장 주소 정보 없음',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? const Color(0xFF4A68F6)
                            : Colors.grey.shade400,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _types[i]['title']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _types[i]['desc']!,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < _types.length - 1)
                Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          borderSide: const BorderSide(color: Color(0xFF4A68F6)),
        ),
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
          borderSide: const BorderSide(color: Color(0xFF4A68F6)),
        ),
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
                Text(
                  '신고는 운영팀이 확인 후 처리돼요.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '허위 신고 시 이용이 제한될 수 있어요.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

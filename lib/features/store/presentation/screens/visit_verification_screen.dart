import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class VisitVerificationScreen extends StatefulWidget {
  final String storeName;

  const VisitVerificationScreen({
    super.key,
    this.storeName = '매장 정보 없음',
  });

  @override
  State<VisitVerificationScreen> createState() =>
      _VisitVerificationScreenState();
}

class _VisitVerificationScreenState extends State<VisitVerificationScreen> {
  int _selectedMethod = 0;
  final _amountController = TextEditingController();
  final _menuController = TextEditingController();
  bool _isSubmitting = false;

  XFile? _receiptImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _receiptImage = image;
        });
      }
    } catch (e) {
      debugPrint('영수증 촬영 오류: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 매장 위치/거리 연동, 인증 API 연동
    return FigmaMobileCanvas(
      child: GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
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
                  iconBgColor: AppColors.primary,
                  icon: Icons.location_on_rounded,
                  title: '위치로 인증하기',
                  desc: '매장 근처에 있을 때 인증할 수 있어요. 현재 거리: 320m',
                  extra: null,
                ),
                const SizedBox(height: 12),
                // 영수증 인증 카드
                _buildVerifyCard(
                  index: 1,
                  iconBgColor: AppColors.orangeTheme,
                  icon: Icons.receipt_long_rounded,
                  title: '영수증 사진으로 인증하기',
                  desc: '영수증을 촬영해서 결제 금액을 등록할 수 있어요.',
                  extra: _selectedMethod == 1 ? _buildReceiptInput() : null,
                ),
                const SizedBox(height: 24),
                // 메뉴 · 결제 금액 입력
                _buildMenuPriceSection(),
                const SizedBox(height: 16),
                // 예상 절약 금액 카드
                _buildSavingsCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: _isSubmitting ? '기록 중…' : '방문 인증하기',
          backgroundColor: AppColors.primary,
          onPressed: _isSubmitting ? () {} : _submit,
        ),
      ),
    ),
    );
  }

  Widget _buildStoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '가격 정보 확인 가능',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '320m',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
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
    return FigmaMobileCanvas(
      child: GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySubtle : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade200,
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
                  child: Icon(icon, color: AppColors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.primary
                      : Colors.grey.shade300,
                  size: 22,
                ),
              ],
            ),
            if (extra != null) ...[const SizedBox(height: 14), extra],
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildReceiptInput() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickReceiptImage,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              image: _receiptImage != null
                  ? DecorationImage(
                      image: kIsWeb
                          ? NetworkImage(_receiptImage!.path) as ImageProvider
                          : FileImage(File(_receiptImage!.path)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _receiptImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '영수증 사진은 참고용으로만 사용돼요.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// 메뉴 · 결제 금액 입력 (방문 인증 시 절약 금액 계산에 사용)
  Widget _buildMenuPriceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '메뉴 · 결제 금액',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _menuController,
            decoration: _inputDecoration('메뉴명 입력 (예: 김치찌개)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('결제 금액 입력 (원)'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
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
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  /// 예상 절약 금액 미리보기 (v1 간이 룰: 평균가 10,000원 − 결제가. 최종 값은 서버가 업종 반영해 계산)
  int? get _estimatedSaved {
    final price = int.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^\d]'), '')) ??
        0;
    if (price <= 0) return null;
    return (10000 - price).clamp(0, 10000);
  }

  String _formatWon(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// 방문 인증 생성 (POST /api/visits) — 절약 금액은 서버 룰로 계산됨
  Future<void> _submit() async {
    final price = int.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^\d]'), '')) ??
        0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 금액을 입력해주세요.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final response = await http
          .post(
            ApiClient.uri('/api/visits'),
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({
              'storeName': widget.storeName,
              'menu': _menuController.text.trim(),
              'price': price,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        context.push(AppRoutes.visitVerificationComplete, extra: {
          'savedAmount': (data['savedAmount'] as num?)?.toInt() ?? 0,
          'storeName': widget.storeName,
          'menu': _menuController.text.trim(),
          'price': price,
        });
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요한 기능입니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방문 기록에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSavingsCard() {
    final estimated = _estimatedSaved;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                '인증 후 예상 절약 금액',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            estimated == null
                ? '금액 입력 시 자동 계산'
                : '약 ${_formatWon(estimated)}원 절약 예상',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '업종 평균가 대비 산정 (서버에서 최종 계산)',
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

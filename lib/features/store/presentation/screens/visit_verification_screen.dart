import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class VisitVerificationScreen extends StatefulWidget {
  const VisitVerificationScreen({super.key});

  @override
  State<VisitVerificationScreen> createState() =>
      _VisitVerificationScreenState();
}

class _VisitVerificationScreenState extends State<VisitVerificationScreen> {
  int _selectedMethod = 0;
  final _amountController = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(박지환 BE): 매장 위치/거리 연동, 인증 API 연동
    return GestureDetector(
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
                // 예상 절약 금액 카드
                _buildSavingsCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '방문 인증하기',
          backgroundColor: AppColors.primary,
          onPressed: () {
            context.push('/home/visit_complete');
          },
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '착한분식',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '김치찌개 5,500원',
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
    return GestureDetector(
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
        Expanded(
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '결제 금액 입력',
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
        color: AppColors.successSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
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
          SizedBox(height: 10),
          Text(
            '약 2,000원 절약',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '주변 평균 메뉴 가격 대비 산정',
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

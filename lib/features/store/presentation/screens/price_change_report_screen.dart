import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/constants/feature_flags.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class PriceChangeReportScreen extends ConsumerStatefulWidget {
  final String storeName;
  final Store? store;

  const PriceChangeReportScreen({
    super.key,
    this.storeName = '매장 정보 없음',
    this.store,
  });

  @override
  ConsumerState<PriceChangeReportScreen> createState() =>
      _PriceChangeReportScreenState();
}

class _PriceChangeReportScreenState
    extends ConsumerState<PriceChangeReportScreen> {
  // 0: 가격 인상, 1: 가격 인하, 2: 메뉴 삭제, 3: 신규 메뉴
  int _selectedType = 0;
  bool _isConfirmed = false;
  bool _isSubmitting = false;

  final _menuController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  final List<Map<String, String>> _changeTypes = [
    {'label': '↗  가격 인상', 'value': 'rise'},
    {'label': '↘  가격 인하', 'value': 'drop'},
    {'label': '메뉴 삭제', 'value': 'delete'},
    {'label': '신규 메뉴', 'value': 'new'},
  ];

  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  String get _changeType => _changeTypes[_selectedType]['value']!;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final menu = _menuController.text.trim();
    final price = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final description = _descController.text.trim();
    if (!ApiClient.isAuthenticated) {
      _showMessage('가격 변동 제보는 로그인 후 이용할 수 있어요.');
      return;
    }
    if (menu.isEmpty) {
      _showMessage('변경된 메뉴를 입력해주세요.');
      return;
    }
    if (_selectedType != 2 && (price.isEmpty || int.tryParse(price) == 0)) {
      _showMessage('변경된 가격을 입력해주세요.');
      return;
    }
    if (!_isConfirmed) {
      _showMessage('메뉴판 가격을 직접 확인했다는 항목을 체크해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    var uploadedImageUrls = <String>[];
    try {
      final reportService = ref.read(reportServiceProvider);
      if (FeatureFlags.reportImageUploadEnabled && _selectedImages.isNotEmpty) {
        uploadedImageUrls = await reportService.uploadReportImages(
          _selectedImages,
        );
      }
      final store = widget.store;
      final report = UserReport(
        storeId: store?.id ?? '',
        storeName: store?.storeName ?? widget.storeName,
        industry: store?.industry ?? '',
        address: store?.address ?? '',
        phoneNumber: store?.phoneNumber ?? '',
        menu1: menu,
        price1: _selectedType == 2 ? '' : price,
        imageUrls: uploadedImageUrls,
        reporterId: '',
        visitedRecently: true,
        checkedMenuPrice: true,
        changeType: _changeType,
        description: description,
        latitude: store?.latitude ?? 0,
        longitude: store?.longitude ?? 0,
      );
      await reportService.submitReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가격 변동 제보가 접수되었습니다. 관리자 확인 후 반영됩니다.')),
      );
      context.pop();
    } on ReportServiceException catch (error) {
      if (uploadedImageUrls.isNotEmpty) {
        await ref
            .read(reportServiceProvider)
            .cleanupReportImages(uploadedImageUrls);
      }
      if (mounted) _showMessage(error.message);
    } catch (error) {
      debugPrint('가격 변동 제보 오류: $error');
      if (uploadedImageUrls.isNotEmpty) {
        await ref
            .read(reportServiceProvider)
            .cleanupReportImages(uploadedImageUrls);
      }
      if (mounted) _showMessage('제보를 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 3) return;
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.take(3 - _selectedImages.length));
        });
      }
    } catch (e) {
      debugPrint('사진 첨부 오류: $e');
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
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
          backgroundColor: AppColors.white,
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
                  const Text(
                    '변동 유형',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTypeGrid(),
                  const SizedBox(height: 24),

                  // 변경된 메뉴
                  const Text(
                    '변경된 메뉴',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(_menuController, '아메리카노'),
                  const SizedBox(height: 20),

                  // 변경된 가격 (삭제 유형 제외)
                  if (_selectedType != 2) ...[
                    const Text(
                      '변경된 가격',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPriceField(),
                    const SizedBox(height: 20),
                  ],

                  // 메뉴판 사진
                  const Text(
                    '메뉴판 사진',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildPhotoButton(),
                  const SizedBox(height: 20),

                  // 설명
                  const Text(
                    '설명',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
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
            text: _isSubmitting ? '제보 저장 중...' : '가격 변동 제보하기',
            backgroundColor: AppColors.orangeTheme,
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store?.storeName ?? widget.storeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '가격 변동 제보',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                const Text(
                  '메뉴 정보 기입',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Text(
            '-',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
        return FigmaMobileCanvas(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.orangeLight : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.orangeTheme
                      : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                _changeTypes[i]['label']!,
                style: TextStyle(
                  color: selected ? AppColors.orangeTheme : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
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
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
          borderSide: const BorderSide(color: AppColors.orangeTheme),
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
        color: AppColors.orangeTheme,
      ),
      decoration: InputDecoration(
        suffixText: '원',
        suffixStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orangeTheme),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orangeTheme, width: 2),
        ),
      ),
    );
  }

  Widget _buildPhotoButton() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.grey.shade400,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedImages.length}/3',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          ..._selectedImages.map((image) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    image: DecorationImage(
                      image: kIsWeb
                          ? NetworkImage(image.path) as ImageProvider
                          : FileImage(File(image.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImages.remove(image);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDescField() {
    return TextField(
      controller: _descController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: '변동 내용을 간단히 알려주세요.',
        hintStyle: const TextStyle(color: AppColors.muted),
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
          borderSide: const BorderSide(color: AppColors.orangeTheme),
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
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        const Text('직접 메뉴판 가격을 확인했어요', style: TextStyle(fontSize: 14)),
      ],
    );
  }
}

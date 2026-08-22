import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/presentation/state/review_form_validator.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';

class ReviewWriteScreen extends ConsumerStatefulWidget {
  final Store? store;

  const ReviewWriteScreen({super.key, this.store});

  @override
  ConsumerState<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends ConsumerState<ReviewWriteScreen> {
  final _formKey = GlobalKey<FormState>();

  int _starRating = 0;
  bool _isVisitedRecently = false;
  bool _isPriceChecked = false;
  bool _isSubmitting = false;
  bool _showValidationErrors = false;

  late final TextEditingController _menuController;
  late final TextEditingController _priceController;
  final _contentController = TextEditingController();

  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

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
  void initState() {
    super.initState();
    _menuController = TextEditingController();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _menuController.dispose();
    _priceController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    FocusManager.instance.primaryFocus?.unfocus();

    // 공공데이터 매장은 별도 id가 없으므로 매장명을 storeId로 사용합니다.
    final storeName = widget.store?.storeName.trim() ?? '';
    if (storeName.isEmpty) {
      _showSnackBar('매장 정보가 없어 리뷰를 등록할 수 없습니다.');
      return;
    }
    if (!ApiClient.isAuthenticated) {
      _showSnackBar('리뷰를 등록하려면 로그인이 필요합니다.');
      return;
    }

    setState(() => _showValidationErrors = true);
    final textFieldsValid = _formKey.currentState?.validate() ?? false;
    final ratingError = ReviewFormValidator.validateRating(_starRating);
    final confirmationError = ReviewFormValidator.validateConfirmations(
      visitedRecently: _isVisitedRecently,
      priceChecked: _isPriceChecked,
    );
    if (!textFieldsValid || ratingError != null || confirmationError != null) {
      _showSnackBar('필수 항목을 확인해주세요.');
      return;
    }

    final price = ReviewFormValidator.parsePrice(_priceController.text);
    if (price == null) {
      _showSnackBar('실제 결제 가격을 확인해주세요.');
      return;
    }

    final nickname = ref.read(userProfileProvider).nickname;
    final review = Review(
      storeId: storeName,
      storeName: storeName,
      authorName: nickname.trim().isNotEmpty ? nickname.trim() : '사용자',
      stars: _starRating,
      menu: _menuController.text.trim(),
      price: price,
      content: _contentController.text.trim(),
    );

    setState(() => _isSubmitting = true);
    late final bool success;
    try {
      success = await ref.read(storeReviewProvider.notifier).addReview(review);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;

    if (success) {
      // 내 리뷰 화면 캐시 무효화 — 다음 진입 시 최신 목록/개수/평균 별점이 갱신됩니다.
      ref.read(myReviewsProvider.notifier).invalidate();
      _showSnackBar('리뷰가 성공적으로 등록되었습니다.');
      context.pop();
    } else {
      _showSnackBar('리뷰 등록에 실패했습니다. 로그인 상태를 확인해주세요.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: const CustomAppBar(title: '리뷰 작성'),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: _showValidationErrors
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 매장 정보 카드
                    _buildStoreCard(),
                    const SizedBox(height: 24),

                    // 별점
                    const Text(
                      '별점',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStarRating(),
                    const SizedBox(height: 24),

                    // 방문 메뉴
                    const Text(
                      '방문 메뉴',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _menuController,
                      widget.store?.menu1.isNotEmpty == true
                          ? '${widget.store!.menu1} 등 방문 메뉴'
                          : '방문 메뉴',
                    ),
                    const SizedBox(height: 20),

                    // 실제 결제 가격
                    const Text(
                      '실제 결제 가격',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPriceField(),
                    const SizedBox(height: 20),

                    // 리뷰 내용
                    const Text(
                      '리뷰 내용',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReviewContentField(),
                    const SizedBox(height: 20),

                    // 사진 첨부
                    const Text(
                      '사진 첨부 (선택)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoAttach(),
                    const SizedBox(height: 20),

                    // 체크박스
                    _buildCheckbox('최근 1개월 이내 방문했어요', _isVisitedRecently, (v) {
                      setState(() => _isVisitedRecently = v ?? false);
                    }),
                    const SizedBox(height: 10),
                    _buildCheckbox('가격 정보를 직접 확인했어요', _isPriceChecked, (v) {
                      setState(() => _isPriceChecked = v ?? false);
                    }),
                    if (_showValidationErrors &&
                        ReviewFormValidator.validateConfirmations(
                              visitedRecently: _isVisitedRecently,
                              priceChecked: _isPriceChecked,
                            ) !=
                            null) ...[
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          '방문 및 가격 확인 항목에 동의해주세요.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomButton(
            text: _isSubmitting ? '등록 중...' : '리뷰 등록하기',
            backgroundColor: AppColors.primary,
            onPressed: _isSubmitting ? null : _submitReview,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.store?.storeName ?? '매장 정보 없음',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            widget.store?.address ?? '주소 정보 없음',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    final ratingError = _showValidationErrors
        ? ReviewFormValidator.validateRating(_starRating)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ratingError == null ? Colors.grey.shade200 : Colors.red,
            ),
          ),
          child: Row(
            children: [
              ...List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _starRating = i + 1),
                  child: Icon(
                    Icons.star_rounded,
                    size: 36,
                    color: i < _starRating
                        ? AppColors.star
                        : Colors.grey.shade300,
                  ),
                );
              }),
              const SizedBox(width: 12),
              Text(
                _starRating == 0 ? '선택 전' : '$_starRating.0',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (ratingError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              ratingError,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      maxLength: 100,
      validator: ReviewFormValidator.validateMenu,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        counterText: '',
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    final storePrice = widget.store?.price1 ?? '';
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
      validator: ReviewFormValidator.validatePrice,
      decoration: InputDecoration(
        hintText: storePrice.isEmpty ? '실제 결제 가격' : '$storePrice 참고',
        hintStyle: const TextStyle(color: AppColors.muted),
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
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildReviewContentField() {
    return TextFormField(
      controller: _contentController,
      maxLines: 4,
      maxLength: 2000,
      validator: ReviewFormValidator.validateContent,
      decoration: InputDecoration(
        hintText: '맛, 양, 가격에 대한 솔직한 후기를 남겨주세요.',
        hintStyle: const TextStyle(color: AppColors.muted),
        counterText: '',
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildPhotoAttach() {
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
                border: Border.all(color: Colors.grey.shade200),
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

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }
}

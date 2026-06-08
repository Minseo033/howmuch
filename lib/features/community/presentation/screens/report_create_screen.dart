import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:image_picker/image_picker.dart';

class ReportCreateScreen extends StatefulWidget {
  const ReportCreateScreen({super.key, this.id});

  final String? id;

  @override
  State<ReportCreateScreen> createState() => _ReportCreateScreenState();
}

class _ReportCreateScreenState extends State<ReportCreateScreen> {
  static const _priceSectionOffset = 354.46;
  static const _baseConfirmSectionOffset = 490.23;
  static const _basePriceCardHeight = 91.776;
  static const _storeOptions = ['골목밥상', '동네카페', '착한분식', '우리식당'];
  static const _categoryOptions = [
    '음식점 · 한식',
    '음식점 · 카페',
    '음식점 · 분식',
    '서비스 · 미용',
    '기타 · 기타',
  ];
  static const _addressOptions = [
    '서울시 마포구 합정동',
    '서울시 강남구 역삼동',
    '서울시 송파구 잠실동',
    '서울시 성동구 성수동',
  ];

  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late final TextEditingController _storeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _addressController;
  bool _visitedRecently = true;
  bool _checkedMenuPrice = true;
  int _activeStep = 1;
  final List<XFile> _photos = [];
  final List<_MenuPriceControllers> _menuPrices = [];

  @override
  void initState() {
    super.initState();
    _storeController = TextEditingController(text: _storeOptions.first);
    _categoryController = TextEditingController(text: _categoryOptions.first);
    _addressController = TextEditingController(text: _addressOptions.first);
    _storeController.addListener(_onFormChanged);
    _categoryController.addListener(_onFormChanged);
    _addressController.addListener(_onFormChanged);
    _addInitialMenuPrice(menu: '제육덮밥', price: '6000');
    _scrollController.addListener(_syncStepWithScroll);
  }

  @override
  void dispose() {
    _storeController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    for (final menuPrice in _menuPrices) {
      menuPrice.dispose();
    }
    _scrollController
      ..removeListener(_syncStepWithScroll)
      ..dispose();
    super.dispose();
  }

  void _syncStepWithScroll() {
    final offset = _scrollController.offset;
    final nextStep = offset >= _confirmSectionOffset - 36
        ? 3
        : offset >= _priceSectionOffset - 36
        ? 2
        : 1;

    if (nextStep != _activeStep) {
      setState(() => _activeStep = nextStep);
    }
  }

  double get _confirmSectionOffset {
    return _baseConfirmSectionOffset +
        (_priceInfoCardHeight(_menuPrices.length) - _basePriceCardHeight);
  }

  bool get _basicInfoComplete {
    return _storeController.text.trim().isNotEmpty &&
        _categoryController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty;
  }

  bool get _priceInfoComplete {
    return _menuPrices.isNotEmpty &&
        _menuPrices.every(
          (menuPrice) =>
              menuPrice.menu.text.trim().isNotEmpty &&
              menuPrice.price.text.trim().isNotEmpty,
        );
  }

  bool get _confirmInfoComplete {
    return _visitedRecently && _checkedMenuPrice;
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _addInitialMenuPrice({required String menu, required String price}) {
    final menuPrice = _MenuPriceControllers(menu: menu, price: price);
    menuPrice.addListener(_onFormChanged);
    _menuPrices.add(menuPrice);
  }

  void _addMenuPrice() {
    setState(() {
      _addInitialMenuPrice(menu: '', price: '');
    });
  }

  void _removeMenuPrice(int index) {
    if (_menuPrices.length <= 1) {
      _showSnack('대표 메뉴는 최소 1개가 필요해요.');
      return;
    }

    setState(() {
      final removed = _menuPrices.removeAt(index);
      removed.dispose();
    });
  }

  void _goToStep(int step) {
    final target = switch (step) {
      1 => 0.0,
      2 => _priceSectionOffset,
      _ => _confirmSectionOffset,
    };

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    // TODO(박지환 BE): 제보 등록 API와 이미지 업로드 API가 붙으면 이 로컬 완료 처리를 교체하세요.
    context.push(AppRoutes.reportComplete);
  }

  Future<void> _pickCategory() async {
    final selected = await _showOptionPicker(
      title: '업종 선택',
      options: _categoryOptions,
      initialValue: _categoryController.text,
    );
    if (selected != null) {
      _categoryController.text = selected;
      setState(() {});
    }
  }

  Future<String?> _showOptionPicker({
    required String title,
    required List<String> options,
    required String initialValue,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ReportCreateStyle.ink,
                fontFamily: ReportCreateStyle.fontFamily,
                fontFamilyFallback: ReportCreateStyle.fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: ReportCreateStyle.border),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option,
                      style: const TextStyle(
                        color: ReportCreateStyle.ink,
                        fontFamily: ReportCreateStyle.fontFamily,
                        fontFamilyFallback: ReportCreateStyle.fontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    trailing: option == initialValue
                        ? const Icon(
                            Icons.check_rounded,
                            color: ReportCreateStyle.blue,
                            size: 18,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 3) {
      _showSnack('사진은 최대 3장까지 첨부할 수 있어요.');
      return;
    }

    try {
      final pickedImages = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || pickedImages.isEmpty) {
        return;
      }

      final remainingCount = 3 - _photos.length;
      final imagesToAdd = pickedImages.take(remainingCount).toList();
      setState(() => _photos.addAll(imagesToAdd));

      if (pickedImages.length > remainingCount) {
        _showSnack('사진은 최대 3장까지 첨부할 수 있어요.');
      }
    } on PlatformException {
      if (!mounted) {
        return;
      }
      _showSnack('사진 접근 권한을 확인해주세요.');
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photos.length) {
      return;
    }

    setState(() => _photos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: FigmaMobileCanvas(
        backgroundColor: const Color(0xFFF4F6FA),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: FigmaMobileCanvas.width,
              height: topOffset + 107.46,
              child: const ColoredBox(color: Colors.white),
            ),
            Positioned(
              left: 0,
              top: topOffset,
              width: FigmaMobileCanvas.width,
              height: 46.477,
              child: const _Header(),
            ),
            Positioned(
              left: 0,
              top: topOffset + 46.477,
              width: FigmaMobileCanvas.width,
              height: 60.98,
              child: _StepProgress(
                activeStep: _activeStep,
                basicComplete: _basicInfoComplete,
                priceComplete: _priceInfoComplete,
                confirmComplete: _confirmInfoComplete,
                onTap: _goToStep,
              ),
            ),
            Positioned(
              left: 0,
              top: topOffset + 107.46,
              width: FigmaMobileCanvas.width,
              height: FigmaMobileCanvas.height - topOffset - 107.46,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  15.994,
                  20,
                  safePadding.bottom + 24,
                ),
                children: [
                  const _TipBox(),
                  const SizedBox(height: 11.989),
                  const _SectionLabel(title: '기본 정보', required: true),
                  const SizedBox(height: 10),
                  _BasicInfoCard(
                    storeController: _storeController,
                    categoryController: _categoryController,
                    addressController: _addressController,
                    onCategoryTap: _pickCategory,
                  ),
                  const SizedBox(height: 15.994),
                  const _SectionLabel(title: '가격 정보', required: true),
                  const SizedBox(height: 10),
                  _PriceInfoCard(
                    menuPrices: _menuPrices,
                    onAdd: _addMenuPrice,
                    onRemove: _removeMenuPrice,
                  ),
                  const SizedBox(height: 15.994),
                  const _SectionLabel(title: '사진 및 확인', optional: true),
                  const SizedBox(height: 10),
                  _PhotoConfirmCard(
                    photos: _photos,
                    visitedRecently: _visitedRecently,
                    checkedMenuPrice: _checkedMenuPrice,
                    onPhotoTap: _pickPhotos,
                    onPhotoRemove: _removePhoto,
                    onVisitedChanged: (value) =>
                        setState(() => _visitedRecently = value),
                    onCheckedChanged: (value) =>
                        setState(() => _checkedMenuPrice = value),
                  ),
                  const SizedBox(height: 15.994),
                  _SubmitFooter(onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCreateStyle {
  const ReportCreateStyle._();

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFE53935);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const line = Color(0xFFE2E8F0);
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];
}

double _priceInfoCardHeight(int menuCount) {
  final rowCount = menuCount < 1 ? 1 : menuCount;
  return 12.898 + (rowCount * 65.98) + ((rowCount - 1) * 10) + 10 + 34 + 12.898;
}

double _photoConfirmCardHeight(int photoCount) {
  return 151.378 + (photoCount > 0 ? 103.885 : 0);
}

class _MenuPriceControllers {
  _MenuPriceControllers({required String menu, required String price})
    : menu = TextEditingController(text: menu),
      price = TextEditingController(text: price);

  final TextEditingController menu;
  final TextEditingController price;

  void addListener(VoidCallback listener) {
    menu.addListener(listener);
    price.addListener(listener);
  }

  void dispose() {
    menu.dispose();
    price.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 3,
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(AppRoutes.communityFeed);
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              color: ReportCreateStyle.ink,
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 12,
            child: Center(
              child: Text(
                '가성비 매장 제보',
                style: TextStyle(
                  color: ReportCreateStyle.black,
                  fontFamily: ReportCreateStyle.fontFamily,
                  fontFamilyFallback: ReportCreateStyle.fontFallback,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.activeStep,
    required this.basicComplete,
    required this.priceComplete,
    required this.confirmComplete,
    required this.onTap,
  });

  final int activeStep;
  final bool basicComplete;
  final bool priceComplete;
  final bool confirmComplete;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _StepItem(
              number: '1',
              label: '기본 정보',
              active: activeStep == 1,
              complete: basicComplete,
              onTap: () => onTap(1),
            ),
            Expanded(child: _StepLine(active: basicComplete)),
            _StepItem(
              number: '2',
              label: '가격 정보',
              active: activeStep == 2,
              complete: priceComplete,
              onTap: () => onTap(2),
            ),
            Expanded(child: _StepLine(active: basicComplete && priceComplete)),
            _StepItem(
              number: '3',
              label: '확인',
              active: activeStep == 3,
              complete: confirmComplete,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.number,
    required this.label,
    required this.onTap,
    this.active = false,
    this.complete = false,
  });

  final String number;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 25.994,
              height: 25.994,
              decoration: BoxDecoration(
                color: complete
                    ? ReportCreateStyle.orange
                    : ReportCreateStyle.line,
                shape: BoxShape.circle,
                border: Border.all(
                  color: complete
                      ? ReportCreateStyle.orange
                      : ReportCreateStyle.line,
                  width: 0,
                ),
              ),
              alignment: Alignment.center,
              child: complete
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    )
                  : Text(
                      number,
                      style: const TextStyle(
                        color: ReportCreateStyle.muted,
                        fontFamily: ReportCreateStyle.fontFamily,
                        fontFamilyFallback: ReportCreateStyle.fontFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
            ),
            const SizedBox(height: 3.992),
            Text(
              label,
              style: TextStyle(
                color: complete
                    ? ReportCreateStyle.orange
                    : ReportCreateStyle.muted,
                fontFamily: ReportCreateStyle.fontFamily,
                fontFamilyFallback: ReportCreateStyle.fontFallback,
                fontSize: 11,
                fontWeight: complete ? FontWeight.w600 : FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    const circleSize = 25.994;
    const lineHeight = 1.989;
    const stepHeight = 44.986;
    const lineTop = (circleSize - lineHeight) / 2;

    return SizedBox(
      height: stepHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: lineTop,
            height: lineHeight,
            child: ColoredBox(
              color: active ? ReportCreateStyle.orange : ReportCreateStyle.line,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54.744,
      padding: const EdgeInsets.fromLTRB(12, 11.989, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          '동네의 좋은 가격 정보를 함께 나눠주세요.\n검토 후 지도에 표시됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9A3412),
            fontFamily: ReportCreateStyle.fontFamily,
            fontFamilyFallback: ReportCreateStyle.fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.required = false,
    this.optional = false,
  });

  final String title;
  final bool required;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ReportCreateStyle.ink,
            fontFamily: ReportCreateStyle.fontFamily,
            fontFamilyFallback: ReportCreateStyle.fontFallback,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(width: 6),
        if (required)
          const Text(
            '* 필수',
            style: TextStyle(
              color: ReportCreateStyle.orange,
              fontFamily: ReportCreateStyle.fontFamily,
              fontFamilyFallback: ReportCreateStyle.fontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        if (optional)
          const Text(
            '선택',
            style: TextStyle(
              color: ReportCreateStyle.muted,
              fontFamily: ReportCreateStyle.fontFamily,
              fontFamilyFallback: ReportCreateStyle.fontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
      ],
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({
    required this.storeController,
    required this.categoryController,
    required this.addressController,
    required this.onCategoryTap,
  });

  final TextEditingController storeController;
  final TextEditingController categoryController;
  final TextEditingController addressController;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.898, 12.898, 12.898, .909),
      decoration: _cardDecoration,
      child: Column(
        children: [
          _EditableFormRow(label: '매장명 *', controller: storeController),
          const SizedBox(height: 10),
          _EditableFormRow(
            label: '업종 *',
            controller: categoryController,
            readOnly: true,
            onTap: onCategoryTap,
            trailing: _SuffixAction(
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: onCategoryTap,
            ),
          ),
          const SizedBox(height: 10),
          _EditableFormRow(label: '주소 *', controller: addressController),
        ],
      ),
    );
  }
}

class _PriceInfoCard extends StatelessWidget {
  const _PriceInfoCard({
    required this.menuPrices,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_MenuPriceControllers> menuPrices;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.898, 12.898, 12.898, .909),
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var index = 0; index < menuPrices.length; index++) ...[
            _MenuPriceRow(
              menuPrice: menuPrices[index],
              showRemove: menuPrices.length > 1,
              onRemove: () => onRemove(index),
            ),
            if (index != menuPrices.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('메뉴 추가'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ReportCreateStyle.orange,
                side: const BorderSide(color: Color(0xFFFFD7BD), width: .909),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: ReportCreateStyle.fontFamily,
                  fontFamilyFallback: ReportCreateStyle.fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuPriceRow extends StatelessWidget {
  const _MenuPriceRow({
    required this.menuPrice,
    required this.showRemove,
    required this.onRemove,
  });

  final _MenuPriceControllers menuPrice;
  final bool showRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _EditableFormRow(
              label: '대표 메뉴 *',
              controller: menuPrice.menu,
            ),
          ),
          const SizedBox(width: 7.997),
          Expanded(
            child: _EditableFormRow(
              label: '가격 *',
              controller: menuPrice.price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              trailing: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  '원',
                  style: TextStyle(
                    color: ReportCreateStyle.muted,
                    fontFamily: ReportCreateStyle.fontFamily,
                    fontFamilyFallback: ReportCreateStyle.fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (showRemove) ...[
            const SizedBox(width: 7.997),
            SizedBox(
              width: 34,
                      child: Column(
                children: [
                  const SizedBox(height: 25.494),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      child: InkWell(
                        onTap: onRemove,
                        borderRadius: BorderRadius.circular(99),
                        child: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: ReportCreateStyle.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditableFormRow extends StatelessWidget {
  const _EditableFormRow({
    required this.label,
    required this.controller,
    this.trailing,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ReportCreateStyle.muted,
              fontFamily: ReportCreateStyle.fontFamily,
              fontFamilyFallback: ReportCreateStyle.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 5.994),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ReportCreateStyle.border, width: .909),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    readOnly: readOnly,
                    showCursor: !readOnly,
                    enableInteractiveSelection: !readOnly,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    cursorColor: ReportCreateStyle.blue,
                    textAlignVertical: TextAlignVertical.center,
                    onTap: onTap,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    style: const TextStyle(
                      color: ReportCreateStyle.ink,
                      fontFamily: ReportCreateStyle.fontFamily,
                      fontFamilyFallback: ReportCreateStyle.fontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
                ...(trailing != null ? [trailing!] : const <Widget>[]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuffixAction extends StatelessWidget {
  const _SuffixAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(icon, size: 18, color: ReportCreateStyle.muted),
      ),
    );
  }
}

class _PhotoConfirmCard extends StatelessWidget {
  const _PhotoConfirmCard({
    required this.photos,
    required this.visitedRecently,
    required this.checkedMenuPrice,
    required this.onPhotoTap,
    required this.onPhotoRemove,
    required this.onVisitedChanged,
    required this.onCheckedChanged,
  });

  final List<XFile> photos;
  final bool visitedRecently;
  final bool checkedMenuPrice;
  final VoidCallback onPhotoTap;
  final ValueChanged<int> onPhotoRemove;
  final ValueChanged<bool> onVisitedChanged;
  final ValueChanged<bool> onCheckedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.898, 12.898, 12.898, .909),
      decoration: _cardDecoration,
      child: Column(
        children: [
          _PhotoUploadBox(photos: photos, onTap: onPhotoTap),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 7.997),
            _PhotoThumbnailStrip(photos: photos, onRemove: onPhotoRemove),
            const SizedBox(height: 9.989),
          ] else
            const SizedBox(height: 11.989),
          _CheckLine(
            label: '최근 1개월 이내 방문했어요',
            value: visitedRecently,
            onChanged: onVisitedChanged,
          ),
          const SizedBox(height: 5.994),
          _CheckLine(
            label: '메뉴판 가격을 직접 확인했어요',
            value: checkedMenuPrice,
            onChanged: onCheckedChanged,
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadBox extends StatelessWidget {
  const _PhotoUploadBox({required this.photos, required this.onTap});

  final List<XFile> photos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoCount = photos.length;
    final hasPhotos = photos.isNotEmpty;
    final title = hasPhotos ? '사진 $photoCount장 첨부됨' : '메뉴판 사진 첨부';
    final subtitle = hasPhotos
        ? photos.first.name
        : '가격 확인을 위해 권장해요 · $photoCount/3';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 71.605,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1.818,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 11.989),
            const _PhotoIconBox(),
            const SizedBox(width: 11.989),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ReportCreateStyle.ink,
                      fontFamily: ReportCreateStyle.fontFamily,
                      fontFamilyFallback: ReportCreateStyle.fontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: .994),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ReportCreateStyle.muted,
                      fontFamily: ReportCreateStyle.fontFamily,
                      fontFamilyFallback: ReportCreateStyle.fontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.image_outlined,
              color: ReportCreateStyle.muted,
              size: 16,
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnailStrip extends StatelessWidget {
  const _PhotoThumbnailStrip({required this.photos, required this.onRemove});

  final List<XFile> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 7.997;
        final slotSize = (constraints.maxWidth - (gap * 2)) / 3;

        return SizedBox(
          height: slotSize,
          child: Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                SizedBox(
                  width: slotSize,
                  height: slotSize,
                  child: _PhotoThumbnailSlot(
                    photo: index < photos.length ? photos[index] : null,
                    index: index,
                    onRemove: onRemove,
                  ),
                ),
                if (index != 2) const SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PhotoThumbnailSlot extends StatelessWidget {
  const _PhotoThumbnailSlot({
    required this.photo,
    required this.index,
    required this.onRemove,
  });

  final XFile? photo;
  final int index;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: photo == null ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1), width: .909),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              FutureBuilder<Uint8List>(
                future: photo.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                  }

                  return const ColoredBox(
                    color: Color(0xFFFFF3EA),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ReportCreateStyle.orange,
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: ReportCreateStyle.muted,
                    fontFamily: ReportCreateStyle.fontFamily,
                    fontFamilyFallback: ReportCreateStyle.fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: photo == null ? Colors.white : const Color(0xCC0F172A),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: photo == null
                        ? ReportCreateStyle.muted
                        : Colors.white,
                    fontFamily: ReportCreateStyle.fontFamily,
                    fontFamilyFallback: ReportCreateStyle.fontFallback,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
            if (photo != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xE60F172A),
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoIconBox extends StatelessWidget {
  const _PhotoIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43.991,
      height: 43.991,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: ReportCreateStyle.orange,
        size: 20,
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 17.997,
            height: 17.997,
            decoration: BoxDecoration(
              color: value ? ReportCreateStyle.blue : Colors.white,
              border: Border.all(
                color: value
                    ? ReportCreateStyle.blue
                    : ReportCreateStyle.border,
                width: .909,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : null,
          ),
          const SizedBox(width: 7.997),
          Text(
            label,
            style: const TextStyle(
              color: ReportCreateStyle.ink,
              fontFamily: ReportCreateStyle.fontFamily,
              fontFamilyFallback: ReportCreateStyle.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitFooter extends StatelessWidget {
  const _SubmitFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ReportCreateStyle.blue,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x4D2563EB),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          '제보 제출하기',
          style: TextStyle(
            color: Colors.white,
            fontFamily: ReportCreateStyle.fontFamily,
            fontFamilyFallback: ReportCreateStyle.fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  border: Border.all(color: ReportCreateStyle.border, width: .909),
  borderRadius: BorderRadius.circular(16),
);

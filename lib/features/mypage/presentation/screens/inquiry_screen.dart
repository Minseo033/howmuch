import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:image_picker/image_picker.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  static const blue = AppColors.primary;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const disabled = AppColors.disabled;
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _types = const ['매장 정보 오류', '제보 검토 문의', '계정/로그인 문제', '기타'];
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final _imagePicker = ImagePicker();
  final List<XFile> _attachments = [];
  int _selectedType = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController()
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final remainingCount = 3 - _attachments.length;
    if (remainingCount <= 0) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('사진은 최대 3장까지 첨부할 수 있어요.')));
      return;
    }

    try {
      final pickedImages = await _imagePicker.pickMultiImage(imageQuality: 85);

      if (!mounted || pickedImages.isEmpty) {
        return;
      }

      final imagesToAdd = pickedImages.take(remainingCount).toList();
      setState(() => _attachments.addAll(imagesToAdd));

      if (pickedImages.length > remainingCount) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('사진은 최대 3장까지 첨부할 수 있어요.')),
          );
      }
    } on PlatformException {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('사진 접근 권한을 확인해주세요.')));
    }
  }

  void _removePhoto(int index) {
    setState(() => _attachments.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(userProfileProvider).email;
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyButton.heightFor(bottomOffset);
    final scrollContentHeight = 592.8974609375 + topOffset + footerHeight + 24;

    return FigmaMobileCanvas(
      backgroundColor: InquiryScreen.surface,
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          cursorColor: InquiryScreen.blue,
          selectionColor: InquiryScreen.blue.withValues(alpha: .18),
          selectionHandleColor: InquiryScreen.blue,
        ),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: scrollContentHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          top: 64.8720703125 + topOffset,
                          child: const Text('문의 유형', style: _labelText),
                        ),
                        Positioned(
                          left: 20,
                          top: 90.8662109375 + topOffset,
                          child: _InquiryChip(
                            text: _types[0],
                            selected: _selectedType == 0,
                            onTap: () => setState(() => _selectedType = 0),
                          ),
                        ),
                        Positioned(
                          left: 191.71875,
                          top: 90.8662109375 + topOffset,
                          child: _InquiryChip(
                            text: _types[1],
                            selected: _selectedType == 1,
                            onTap: () => setState(() => _selectedType = 1),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: 140.66748046875 + topOffset,
                          child: _InquiryChip(
                            text: _types[2],
                            selected: _selectedType == 2,
                            onTap: () => setState(() => _selectedType = 2),
                          ),
                        ),
                        Positioned(
                          left: 191.71875,
                          top: 140.66748046875 + topOffset,
                          child: _InquiryChip(
                            text: _types[3],
                            selected: _selectedType == 3,
                            onTap: () => setState(() => _selectedType = 3),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: 202.4716796875 + topOffset,
                          right: 20,
                          height: 72.4,
                          child: _TitleField(controller: _titleController),
                        ),
                        Positioned(
                          left: 20,
                          top: 290.45458984375 + topOffset,
                          right: 20,
                          height: 136.4,
                          child: _BodyField(controller: _bodyController),
                        ),
                        Positioned(
                          left: 20,
                          top: 442.44287109375 + topOffset,
                          right: 20,
                          height: 90.4,
                          child: _PhotoAttachBox(
                            attachments: _attachments,
                            onAdd: _pickPhotos,
                            onRemove: _removePhoto,
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: 552.4287109375 + topOffset,
                          right: 20,
                          height: 40.46875,
                          child: _EmailBox(email: email),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _Header(
                topOffset: topOffset,
                title: '문의하기',
                onBack: () => context.go(AppRoutes.mypage),
                onHistory: () => context.push(AppRoutes.inquiryHistory),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                height: footerHeight,
                child: _StickyButton(
                  safeBottom: bottomOffset,
                  label: '문의 보내기',
                  isBusy: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitInquiry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitInquiry() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final content = _bodyController.text.trim();
    final category = _types[_selectedType];

    if (title.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }
    if (content.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
      return;
    }

    setState(() => _isSubmitting = true);
    final reportService = ref.read(reportServiceProvider);
    var uploadedUrls = const <String>[];
    try {
      if (_attachments.isNotEmpty) {
        uploadedUrls = await reportService.uploadReportImages(_attachments);
      }
      final result = await ref
          .read(inquiryServiceProvider)
          .createInquiry(
            title: title,
            content: content,
            category: category,
            imageUrls: uploadedUrls,
          );

      if (result['error'] == true) {
        if (result['cleanupUploadedImages'] == true) {
          await reportService.cleanupReportImages(uploadedUrls);
        }
        if (!mounted) return;
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? '문의 등록에 실패했습니다.'),
            ),
          );
        return;
      }

      if (!mounted) return;
      messenger.clearSnackBars();
      ref.invalidate(myInquiriesProvider);
      context.go(AppRoutes.mypage);
      messenger.showSnackBar(const SnackBar(content: Text('문의가 접수되었어요.')));
    } on ReportServiceException catch (error) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('문의 등록에 실패했습니다. 다시 시도해주세요.')),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.topOffset,
    required this.title,
    required this.onBack,
    required this.onHistory,
  });

  final double topOffset;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: InquiryScreen.border, width: .909),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 72,
              height: 48.877838134765625,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: InquiryScreen.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 11.98876953125 + topOffset,
              child: IgnorePointer(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _headerTitleText,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: topOffset,
              width: 48,
              height: 48.877838134765625,
              child: Tooltip(
                message: '내 문의 내역',
                child: IconButton(
                  onPressed: onHistory,
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                    color: InquiryScreen.ink,
                    size: 22,
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

class _InquiryChip extends StatelessWidget {
  const _InquiryChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: text == '제보 검토 문의' || text == '기타'
            ? 163.7357940673828
            : 163.72158813476562,
        height: 41.80397415161133,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.white,
          border: Border.all(
            color: selected ? InquiryScreen.blue : InquiryScreen.border,
            width: .909,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: selected ? InquiryScreen.blue : InquiryScreen.ink,
            fontFamily: InquiryScreen.fontFamily,
            fontFamilyFallback: InquiryScreen.fontFallback,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('제목', style: _labelText),
        const SizedBox(height: 7.997),
        _InputShell(
          height: 45.99431610107422,
          child: TextField(
            controller: controller,
            cursorColor: InquiryScreen.blue,
            enableSuggestions: false,
            autocorrect: false,
            maxLines: 1,
            maxLength: 100,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: _inputText,
            decoration: const InputDecoration(
              isCollapsed: true,
              filled: false,
              fillColor: AppColors.transparent,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.only(
                left: 12.9091796875,
                right: 12.9091796875,
                top: 13.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BodyField extends StatelessWidget {
  const _BodyField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.text.characters.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('문의 내용', style: _labelText),
            const Spacer(),
            Text('$count / 500', style: _countText),
          ],
        ),
        const SizedBox(height: 7.997),
        _InputShell(
          height: 109.99999237060547,
          child: TextField(
            controller: controller,
            cursorColor: InquiryScreen.blue,
            enableSuggestions: false,
            autocorrect: false,
            maxLines: 4,
            maxLength: 500,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: _bodyText,
            decoration: const InputDecoration(
              isCollapsed: true,
              filled: false,
              fillColor: AppColors.transparent,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(
                12.897705078125,
                11.806640625,
                12.897705078125,
                0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: InquiryScreen.border, width: .909),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _PhotoAttachBox extends StatelessWidget {
  const _PhotoAttachBox({
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> attachments;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final canAddMore = attachments.length < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: _labelText,
            children: [
              const TextSpan(text: '사진 첨부 '),
              TextSpan(
                text: '선택 · ${attachments.length}/3',
                style: const TextStyle(
                  color: InquiryScreen.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7.997),
        SizedBox(
          height: 63.99147415161133,
          child: Row(
            children: [
              if (canAddMore) _AddPhotoButton(onTap: onAdd),
              for (var index = 0; index < attachments.length; index++) ...[
                if (canAddMore || index > 0) const SizedBox(width: 7.997),
                _PhotoThumbnail(
                  image: attachments[index],
                  onRemove: () => onRemove(index),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 63.99147415161133,
          height: 63.99147415161133,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(
                color: InquiryScreen.disabled,
                width: 1.818,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Stack(
              children: [
                Positioned(
                  left: 21.18,
                  top: 12.68,
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    size: 18,
                    color: InquiryScreen.muted,
                  ),
                ),
                Positioned(
                  left: 20.17,
                  top: 32.67,
                  child: Text('추가', style: _photoText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 63.99147415161133,
      height: 63.99147415161133,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: InquiryScreen.border, width: .909),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FutureBuilder<Uint8List>(
                  future: image.readAsBytes(),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    return Image.memory(bytes, fit: BoxFit.cover);
                  },
                ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            top: -5,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: InquiryScreen.ink,
                  border: Border.all(color: AppColors.white, width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailBox extends StatelessWidget {
  const _EmailBox({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final displayEmail =
        email.trim().isEmpty || email.trim().toLowerCase() == 'unknown'
        ? '이메일 정보 없음'
        : email.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11.988525390625, 12, 12, 12),
        child: Row(
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              size: 14,
              color: InquiryScreen.blue,
            ),
            const SizedBox(width: 7.997),
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                text: TextSpan(
                  style: _emailText,
                  children: [
                    const TextSpan(text: '답변 받을 이메일 · '),
                    TextSpan(
                      text: displayEmail,
                      style: const TextStyle(
                        color: InquiryScreen.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.safeBottom,
    required this.label,
    required this.onPressed,
    required this.isBusy,
  });

  static const buttonHeight = 51.9886360168457;
  static const topGap = 12.89794921875;
  static const bottomGap = 26.0;
  static const minimumSafeBottom = 34.0;

  final double safeBottom;
  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  static double effectiveSafeBottom(double safeBottom) {
    return safeBottom > minimumSafeBottom ? safeBottom : minimumSafeBottom;
  }

  static double heightFor(double safeBottom) {
    return topGap + buttonHeight + bottomGap + effectiveSafeBottom(safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottom = effectiveSafeBottom(safeBottom);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: InquiryScreen.border, width: .909),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: effectiveBottom + bottomGap,
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: InquiryScreen.blue,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: InquiryScreen.fontFamily,
                  fontFamilyFallback: InquiryScreen.fontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              onPressed: onPressed,
              child: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

const _headerTitleText = TextStyle(
  color: InquiryScreen.black,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _labelText = TextStyle(
  color: InquiryScreen.ink,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _inputText = TextStyle(
  color: InquiryScreen.ink,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _bodyText = TextStyle(
  color: InquiryScreen.ink,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _countText = TextStyle(
  color: InquiryScreen.muted,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _photoText = TextStyle(
  color: InquiryScreen.muted,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _emailText = TextStyle(
  color: InquiryScreen.muted,
  fontFamily: InquiryScreen.fontFamily,
  fontFamilyFallback: InquiryScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

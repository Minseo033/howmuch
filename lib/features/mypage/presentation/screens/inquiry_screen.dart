import 'dart:async';

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:image_picker/image_picker.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';

class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  static const blue = AppColors.primary;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const disabled = AppColors.disabled;
  static const fontFamily = 'Noto Sans KR';
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
  // Read each picked photo once; rebuilding on every keystroke used to read
  // and decode the originals again.
  final Map<XFile, Future<Uint8List>> _thumbnailBytes = {};
  late final ReportService _reportService;

  /// Photos already uploaded for the current selection. A retry reuses them
  /// instead of uploading the same files again.
  List<String> _uploadedUrls = const [];

  /// Set after a timeout or network failure: the server may have stored the
  /// inquiry, so its photos must not be deleted and a retry checks first.
  ({String title, String content})? _unconfirmedAttempt;
  int _selectedType = 0;
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _reportService = ref.read(reportServiceProvider);
    _titleController = TextEditingController()
      ..addListener(() => setState(() {}));
    _bodyController = TextEditingController()
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Leaving without sending: remove photos that no inquiry refers to.
    if (!_submitted && _unconfirmedAttempt == null) {
      _discardUploads();
    }
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _titleController.text.trim().isNotEmpty ||
      _bodyController.text.trim().isNotEmpty ||
      _attachments.isNotEmpty;

  /// The selection changed or the screen is closing, so uploaded copies are
  /// stale. Photos that a possibly stored inquiry uses are only forgotten.
  void _discardUploads() {
    final urls = _uploadedUrls;
    _uploadedUrls = const [];
    if (urls.isEmpty || _unconfirmedAttempt != null) return;
    unawaited(_reportService.cleanupReportImages(urls));
  }

  Future<void> _pickPhotos() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final messenger = ScaffoldMessenger.of(context);
    final remainingCount = 3 - _attachments.length;
    if (remainingCount <= 0) {
      _showFormNotice(messenger, '사진은 최대 3장까지 첨부할 수 있어요.');
      return;
    }

    try {
      final pickedImages = await _imagePicker.pickMultiImage(imageQuality: 85);

      if (!mounted || pickedImages.isEmpty) {
        return;
      }

      final imagesToAdd = pickedImages.take(remainingCount).toList();
      _discardUploads();
      setState(() {
        _attachments.addAll(imagesToAdd);
        for (final image in imagesToAdd) {
          _thumbnailBytes[image] = image.readAsBytes();
        }
      });

      if (pickedImages.length > remainingCount) {
        _showFormNotice(messenger, '사진은 최대 3장까지 첨부할 수 있어요.');
      }
    } on PlatformException {
      if (!mounted) {
        return;
      }
      _showFormNotice(messenger, '사진 접근 권한을 확인해주세요.');
    }
  }

  void _removePhoto(int index) {
    _discardUploads();
    setState(() => _thumbnailBytes.remove(_attachments.removeAt(index)));
  }

  Future<void> _leave() async {
    if (_isSubmitting || _isLeaving) return;
    if (_hasDraft && !_submitted) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => HowmuchDialog(
          title: '작성 중인 문의를 나갈까요?',
          description: '입력한 내용과 첨부한 사진은 저장되지 않아요.',
          cancelLabel: '계속 작성',
          confirmLabel: '나가기',
          cancelFlex: 1,
          confirmFlex: 1,
          onConfirm: () => Navigator.pop(dialogContext, true),
        ),
      );
      if (!mounted || discard != true) return;
    }
    if (!context.canPop()) {
      context.go(AppRoutes.mypage);
      return;
    }
    setState(() => _isLeaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(userProfileProvider).email;
    final isGuest = !ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyButton.heightFor(bottomOffset);
    final scrollContentHeight = 592.8974609375 + topOffset + footerHeight + 24;
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop:
          canPop && !_isSubmitting && (_isLeaving || _submitted || !_hasDraft),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: FigmaMobileCanvas(
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
                            right: 20,
                            top: 90.8662109375 + topOffset,
                            height: 91.60794830322266,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _InquiryChip(
                                        text: _types[0],
                                        selected: _selectedType == 0,
                                        onTap: () =>
                                            setState(() => _selectedType = 0),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _InquiryChip(
                                        text: _types[1],
                                        selected: _selectedType == 1,
                                        onTap: () =>
                                            setState(() => _selectedType = 1),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _InquiryChip(
                                        text: _types[2],
                                        selected: _selectedType == 2,
                                        onTap: () =>
                                            setState(() => _selectedType = 2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _InquiryChip(
                                        text: _types[3],
                                        selected: _selectedType == 3,
                                        onTap: () =>
                                            setState(() => _selectedType = 3),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                              thumbnailBytes: _thumbnailBytes,
                              onAdd: _pickPhotos,
                              onRemove: _removePhoto,
                            ),
                          ),
                          Positioned(
                            left: 20,
                            top: 552.4287109375 + topOffset,
                            right: 20,
                            height: 40.46875,
                            child: _EmailBox(email: email, isGuest: isGuest),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _Header(
                  topOffset: topOffset,
                  title: '문의하기',
                  onBack: _leave,
                  onHistory: _openHistory,
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
      ),
    );
  }

  /// Past inquiries belong to an account, so a guest logs in before the list
  /// opens. The draft on this screen stays as it is.
  Future<void> _openHistory() async {
    if (!await requireLogin(context, message: '로그인하면 보낸 문의와 답변을 볼 수 있어요.')) {
      return;
    }
    if (mounted) context.push(AppRoutes.inquiryHistory);
  }

  Future<void> _submitInquiry() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final content = _bodyController.text.trim();
    final category = _types[_selectedType];

    if (title.isEmpty) {
      _showFormNotice(messenger, '제목을 입력해주세요.');
      return;
    }
    if (content.isEmpty) {
      _showFormNotice(messenger, '내용을 입력해주세요.');
      return;
    }
    // Answers go to an account, so a guest logs in here. Login opens on top
    // of this form, which is then sent as written, photos included.
    if (!await requireLogin(context, message: '로그인하면 작성한 문의가 바로 접수돼요.')) {
      return;
    }
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    final reportService = _reportService;
    try {
      // After a timeout the first attempt may already be stored. Check before
      // sending the same inquiry again so a retry cannot duplicate it.
      final unconfirmed = _unconfirmedAttempt;
      if (unconfirmed != null &&
          unconfirmed.title == title &&
          unconfirmed.content == content &&
          await _wasStored(title, content)) {
        if (!mounted) return;
        _finishSubmitted(messenger);
        return;
      }
      if (_attachments.isNotEmpty && _uploadedUrls.isEmpty) {
        _uploadedUrls = await reportService.uploadReportImages(_attachments);
      }
      final result = await ref
          .read(inquiryServiceProvider)
          .createInquiry(
            title: title,
            content: content,
            category: category,
            imageUrls: _uploadedUrls,
          );

      if (result['error'] == true) {
        // Only an HTTP answer proves nothing was stored; a timeout or network
        // failure leaves that open.
        final answeredByServer = result['statusCode'] is int;
        _unconfirmedAttempt = answeredByServer
            ? null
            : (title: title, content: content);
        if (result['cleanupUploadedImages'] == true) {
          final urls = _uploadedUrls;
          _uploadedUrls = const [];
          await reportService.cleanupReportImages(urls);
        }
        if (!mounted) return;
        _showFormNotice(
          messenger,
          result['message']?.toString() ?? '문의 등록에 실패했습니다.',
        );
        return;
      }

      if (!mounted) return;
      _finishSubmitted(messenger);
    } on ReportServiceException catch (error) {
      if (!mounted) return;
      _showFormNotice(messenger, error.message);
    } catch (_) {
      if (!mounted) return;
      _showFormNotice(messenger, '문의 등록에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// A notice for the form that stays open. It replaces the one on screen at
  /// once and floats above the send button, so the button can be tapped again
  /// while it shows (QA #37).
  void _showFormNotice(ScaffoldMessengerState messenger, String message) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        HowmuchSnackBar(content: Text(message), aboveNavigation: true),
      );
  }

  Future<bool> _wasStored(String title, String content) async {
    try {
      final mine = await ref.read(inquiryServiceProvider).getMyInquiries();
      return mine.any(
        (inquiry) =>
            inquiry.title.trim() == title && inquiry.content.trim() == content,
      );
    } catch (_) {
      return false;
    }
  }

  void _finishSubmitted(ScaffoldMessengerState messenger) {
    _submitted = true;
    _uploadedUrls = const [];
    _unconfirmedAttempt = null;
    messenger.clearSnackBars();
    ref.invalidate(myInquiriesProvider);
    context.go(AppRoutes.mypage);
    messenger.showSnackBar(HowmuchSnackBar(content: Text('문의가 접수되었어요.')));
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
              left: 8,
              top: topOffset,
              width: 48,
              height: 48.877838134765625,
              // The bare arrow had no name (QA 10/7 #50).
              child: Semantics(
                button: true,
                label: '뒤로가기',
                child: Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    hoverColor: AppColors.primaryLight,
                    onTap: onBack,
                    child: const Padding(
                      padding: EdgeInsets.zero,
                      child: Align(
                        alignment: Alignment.center,
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
              // A Tooltip around the button named a separate node and left
              // the button itself unnamed (QA 10/7 #50).
              child: IconButton(
                tooltip: '내 문의 내역',
                onPressed: onHistory,
                icon: const Icon(
                  Icons.receipt_long_outlined,
                  color: InquiryScreen.ink,
                  size: 22,
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
    // Hand-drawn chips: announce which type is selected like radio buttons.
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: ValueKey('inquiry-type-$text'),
          width: double.infinity,
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
          // iOS read the field without a name (QA 10/7 #50).
          child: Semantics(
            label: '제목',
            child: TextField(
              controller: controller,
              cursorColor: InquiryScreen.blue,
              enableSuggestions: false,
              autocorrect: false,
              maxLines: 1,
              maxLength: 100,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
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
          child: Semantics(
            label: '문의 내용',
            child: TextField(
              controller: controller,
              cursorColor: InquiryScreen.blue,
              enableSuggestions: false,
              autocorrect: false,
              maxLines: 4,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
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
    required this.thumbnailBytes,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> attachments;
  final Map<XFile, Future<Uint8List>> thumbnailBytes;
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
                  bytes: thumbnailBytes[attachments[index]],
                  label: '첨부 사진 ${index + 1}',
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
          key: const ValueKey('inquiry-add-photo-button'),
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
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    key: ValueKey('inquiry-add-photo-icon'),
                    size: 18,
                    color: InquiryScreen.muted,
                  ),
                  SizedBox(height: 2),
                  Text('추가', style: _photoText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.image,
    required this.bytes,
    required this.label,
    required this.onRemove,
  });

  final XFile image;
  final Future<Uint8List>? bytes;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (64 * MediaQuery.devicePixelRatioOf(context)).round();
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
                  future: bytes ?? image.readAsBytes(),
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

                    // Decode at thumbnail size, not the camera resolution.
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                      gaplessPlayback: true,
                    );
                  },
                ),
              ),
            ),
          ),
          // A hit area inside the thumbnail: taps outside the 64px box never
          // reached the old corner button, which left about 15px to press.
          Positioned(
            right: 0,
            top: 0,
            width: 40,
            height: 40,
            child: Semantics(
              button: true,
              label: '$label 삭제',
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('inquiry-photo-remove-$label'),
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: InquiryScreen.ink,
                          border: Border.all(
                            color: AppColors.white,
                            width: 1.5,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
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
  const _EmailBox({required this.email, required this.isGuest});

  final String email;

  /// A guest has no account email yet, so the box says where answers go
  /// once they log in.
  final bool isGuest;

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
                text: isGuest
                    ? const TextSpan(
                        text: '로그인하면 계정 이메일로 답변을 받아요',
                        style: _emailText,
                      )
                    : TextSpan(
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
  static const topGap = 8.0;
  static const bottomGap = 8.0;

  final double safeBottom;
  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  static double effectiveSafeBottom(double safeBottom) {
    return safeBottom > 0 ? safeBottom : 0;
  }

  static double heightFor(double safeBottom) {
    return topGap + buttonHeight + bottomGap + effectiveSafeBottom(safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottom = effectiveSafeBottom(safeBottom);

    return DecoratedBox(
      key: const ValueKey('inquiry-sticky-footer'),
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
              key: const ValueKey('inquiry-submit-button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InquiryScreen.blue,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
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

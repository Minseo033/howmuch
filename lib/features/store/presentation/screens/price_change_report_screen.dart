import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/constants/feature_flags.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';
import 'package:howmuch/core/utils/price_formatter.dart';

/// 등록 가격이 범위나 여러 값이면 서버가 인상·인하 방향을 비교할 수 없습니다.
const priceChangeMultiPriceMessage =
    '이 메뉴는 가격이 하나로 정해져 있지 않아 가격 변동 제보를 할 수 없어요. '
    "정보 신고의 '가격이 달라요'로 알려주세요.";

/// 수정할 때는 대상 매장과 변동 유형을 바꾸지 않습니다(서버도 변경 요청을 거절).
const priceChangeLockedNotice =
    '변동 유형과 메뉴는 수정할 수 없어요. 바꾸려면 제보를 삭제하고 다시 제보해주세요.';

bool hasInexactRegisteredPrice(String rawPrice) {
  final parsed = parsePriceValue(rawPrice);
  return parsed != null && !parsed.isExact;
}

String? validatePriceChange({
  required String changeType,
  required String menu,
  required String price,
  required List<({String menu, String price})> registeredMenus,
  bool free = false,
  bool editing = false,
}) {
  final existing = registeredMenus.where((item) => item.menu == menu.trim());
  final parsedNewPrice = parsePriceValue(price);
  final newPrice = parsedNewPrice != null && parsedNewPrice.isExact
      ? parsedNewPrice.minimum
      : null;
  if (changeType == 'new') {
    if (existing.isNotEmpty) {
      return editing
          ? '이미 등록된 메뉴가 됐어요. 제보를 삭제하고 기존 메뉴의 가격 변동으로 다시 제보해주세요.'
          : '이미 등록된 메뉴예요. 기존 메뉴의 가격 변동을 선택해주세요.';
    }
    return null;
  }
  if (existing.isEmpty) {
    return editing
        ? '제보한 메뉴를 현재 매장 정보에서 찾을 수 없어요. 제보를 삭제하고 다시 제보해주세요.'
        : '등록된 메뉴를 선택해주세요. 새 메뉴라면 신규 메뉴를 선택해주세요.';
  }
  if (changeType == 'delete') return null;
  if (hasInexactRegisteredPrice(existing.first.price)) {
    return priceChangeMultiPriceMessage;
  }
  final currentPrice = minimumMenuPrice(existing.first.price);
  if (currentPrice == null || currentPrice <= 0) {
    return '현재 가격을 확인할 수 없어 가격 변동을 제보할 수 없어요.';
  }
  if (free &&
      (parsedNewPrice == null || !parsedNewPrice.isExact || newPrice != 0)) {
    return '무료 메뉴는 정확히 0원으로 입력해주세요.';
  }
  if (!free &&
      (parsedNewPrice == null ||
          !parsedNewPrice.isExact ||
          newPrice == null ||
          newPrice <= 0)) {
    return '새 가격은 0보다 큰 정확한 금액으로 입력해주세요.';
  }
  if (newPrice == currentPrice) return '기존 가격과 새 가격이 같아요.';
  if (changeType == 'rise' && newPrice != null && newPrice < currentPrice) {
    return editing
        ? '기존 가격보다 낮아요. 변동 유형을 바꾸려면 제보를 삭제하고 다시 제보해주세요.'
        : '기존 가격보다 낮아요. 가격 인하를 선택해주세요.';
  }
  if (changeType == 'drop' && newPrice != null && newPrice > currentPrice) {
    return editing
        ? '기존 가격보다 높아요. 변동 유형을 바꾸려면 제보를 삭제하고 다시 제보해주세요.'
        : '기존 가격보다 높아요. 가격 인상을 선택해주세요.';
  }
  return null;
}

class PriceChangeReportTarget {
  const PriceChangeReportTarget({required this.store, required this.menuIndex});
  final Store store;
  final int menuIndex;
}

class PriceChangeReportScreen extends ConsumerStatefulWidget {
  final String storeName;
  final Store? store;
  final int? initialMenuIndex;

  /// 기존 가격 변동 제보를 수정할 때 전달합니다. 같은 ID로 저장하며
  /// 대상 매장(storeId)과 변동 유형(changeType)은 바꾸지 않습니다.
  final UserReportStatus? initialReport;

  const PriceChangeReportScreen({
    super.key,
    this.storeName = '매장 정보 없음',
    this.store,
    this.initialMenuIndex,
    this.initialReport,
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
  bool _isFree = false;
  bool _isSubmitting = false;
  bool _saved = false;
  bool _leaving = false;
  int? _selectedMenuIndex;
  Store? _loadedStore;
  bool _loadingStore = false;

  /// The form as it opened, so leaving without changes does not ask (QA #35).
  late final String _initialSnapshot;

  /// Whether the last build asked [PopScope] to stop the back gesture.
  bool _blocksPop = false;

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
  final _uploads = ReportUploadSession();

  bool get _isEditing => widget.initialReport != null;

  /// 화면에 넘어온 매장, 없으면 수정 대상 제보의 매장을 새로 조회한 값입니다.
  Store? get _store => widget.store ?? _loadedStore;

  List<({int slot, String menu, String price})> get _registeredMenuSlots {
    final s = _store;
    if (s == null) return const [];
    return [
      for (var slot = 1; slot <= 4; slot++)
        if (s.menuAt(slot).trim().isNotEmpty)
          (
            slot: slot,
            menu: s.menuAt(slot).trim(),
            price: s.priceAt(slot).trim(),
          ),
    ];
  }

  List<({String menu, String price})> get _registeredMenus => [
    for (final item in _registeredMenuSlots)
      (menu: item.menu, price: item.price),
  ];

  String get _changeType {
    final lockedType = widget.initialReport?.changeType.trim() ?? '';
    if (lockedType.isNotEmpty) return lockedType;
    return _changeTypes[_selectedType]['value']!;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _saved) return;
    final initial = widget.initialReport;
    if (initial != null && initial.isApproved) {
      _showMessage('승인된 제보는 수정할 수 없어요.');
      return;
    }
    final changeType = _changeType;
    final isDelete = changeType == 'delete';
    final menu = _menuController.text.trim();
    final price = _priceController.text.trim();
    final description = _descController.text.trim();
    if (!ApiClient.isAuthenticated) {
      _showMessage('가격 변동 제보는 로그인 후 이용할 수 있어요.');
      return;
    }
    if (menu.isEmpty) {
      _showMessage('변경된 메뉴를 입력해주세요.');
      return;
    }
    final parsedPrice = parsePriceValue(price);
    if (!isDelete &&
        (parsedPrice == null ||
            !parsedPrice.isExact ||
            (_isFree ? parsedPrice.minimum != 0 : parsedPrice.minimum <= 0))) {
      _showMessage('변경된 가격을 입력해주세요.');
      return;
    }
    // 수정 중 대상 매장을 불러오지 못했다면 서버가 현재 가격과 방향을 다시 검증합니다.
    final priceError = _isEditing && _store == null
        ? null
        : validatePriceChange(
            changeType: changeType,
            menu: menu,
            price: price,
            registeredMenus: _selectedMenuIndex == null
                ? _registeredMenus
                : [
                    for (final item in _registeredMenuSlots)
                      if (item.slot == _selectedMenuIndex)
                        (menu: item.menu, price: item.price),
                  ],
            free: _isFree,
            editing: _isEditing,
          );
    if (priceError != null) {
      _showMessage(priceError);
      return;
    }
    if (!_isConfirmed) {
      _showMessage('메뉴판 가격을 직접 확인했다는 항목을 체크해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    final reportService = ref.read(reportServiceProvider);
    final store = _store;
    UserReport? request;
    var saveRequestSent = false;
    try {
      final imageUrls = await _uploads.resolveImageUrls(
        reportService,
        _selectedImages,
        uploadEnabled: FeatureFlags.reportImageUploadEnabled,
      );
      request = UserReport(
        storeId: initial?.storeId ?? store?.id ?? '',
        storeName: store?.storeName ?? initial?.store ?? widget.storeName,
        industry: store?.industry ?? initial?.category ?? '',
        address: store?.address ?? initial?.address ?? '',
        phoneNumber: store?.phoneNumber ?? '',
        menu1: menu,
        price1: isDelete ? '' : price,
        free1: !isDelete && _isFree,
        imageUrls: imageUrls,
        reporterId: '',
        visitedRecently: initial?.visitedRecently ?? false,
        checkedMenuPrice: true,
        changeType: changeType,
        description: description,
        latitude: store?.latitude ?? initial?.latitude ?? 0,
        longitude: store?.longitude ?? initial?.longitude ?? 0,
      );
      // 이전 시도가 응답 없이 끝났다면, 다시 보내기 전에 이미 저장됐는지 확인합니다.
      if (_uploads.saveOutcomeUnknown &&
          await _finishIfAlreadySaved(reportService, request)) {
        return;
      }
      saveRequestSent = true;
      if (initial == null) {
        await reportService.submitReport(request);
      } else {
        await reportService.updateReport(initial.id, request);
      }
      await _finishSaved(reportService);
    } on ReportServiceException catch (error) {
      // 서버가 거절했으므로 저장되지 않았습니다.
      if (error.cleanupUploadedImages) {
        await _uploads.discardUnsaved(reportService);
      }
      if (mounted) _showMessage(error.message);
    } catch (error) {
      debugPrint('가격 변동 제보 오류: $error');
      if (saveRequestSent && request != null) {
        // 시간 초과나 연결 끊김은 서버에 저장됐을 수 있어 사진을 지우지 않습니다.
        _uploads.saveOutcomeUnknown = true;
        if (await _finishIfAlreadySaved(reportService, request)) return;
        if (mounted) _showMessage(reportSaveOutcomeUnknownMessage);
      } else {
        await _uploads.discardUnsaved(reportService);
        if (mounted) _showMessage('제보를 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _finishIfAlreadySaved(
    ReportService service,
    UserReport request,
  ) async {
    final reports = await service.fetchMyReports();
    if (reports == null ||
        matchSavedReport(
              reports,
              request,
              reportId: widget.initialReport?.id,
            ) ==
            null) {
      return false;
    }
    await _finishSaved(service, latestReports: reports);
    return true;
  }

  Future<void> _finishSaved(
    ReportService service, {
    List<UserReportStatus>? latestReports,
  }) async {
    _uploads.markSaved();
    _saved = true;
    final editing = _isEditing;
    if (editing) {
      // 상세 화면이 수정된 내용과 '검토 중' 상태를 바로 보여주도록 갱신합니다.
      final reports = latestReports ?? await service.fetchMyReports();
      if (!mounted) return;
      if (reports != null) {
        ref.read(userReportsProvider.notifier).mergeFetchedReports(reports);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      HowmuchSnackBar(
        content: Text(
          editing
              ? '가격 변동 제보를 수정했어요. 관리자 확인 후 반영됩니다.'
              : '가격 변동 제보가 접수되었습니다. 관리자 확인 후 반영됩니다.',
        ),
      ),
    );
    _closeForm();
  }

  void _showMessage(String message) {
    // Replaces the notice on screen at once and floats above the submit
    // button, so the button can be tapped again while it shows (QA #37).
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        HowmuchSnackBar(content: Text(message), aboveNavigation: true),
      );
  }

  String _formSnapshot() => [
    _selectedType,
    _menuController.text.trim(),
    _priceController.text.trim(),
    _isFree,
    _descController.text.trim(),
    _isConfirmed,
    for (final image in _selectedImages) image.path,
  ].join('\n');

  bool get _hasUnsavedChanges =>
      !_saved && !_leaving && _formSnapshot() != _initialSnapshot;

  void _onDraftEdited() {
    if (mounted && _hasUnsavedChanges != _blocksPop) setState(() {});
  }

  void _closeForm() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_isEditing ? AppRoutes.myReportsV2 : AppRoutes.home);
    }
  }

  void _handleBack() {
    if (_isSubmitting) return;
    if (_hasUnsavedChanges) {
      _confirmLeave();
      return;
    }
    _closeForm();
  }

  Future<void> _confirmLeave() async {
    final editing = _isEditing;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => HowmuchDialog(
        title: editing ? '수정 중인 제보를 나갈까요?' : '작성 중인 제보를 나갈까요?',
        description: editing
            ? '수정한 내용은 저장되지 않아요.'
            : '입력한 내용과 첨부한 사진은 저장되지 않아요.',
        cancelLabel: editing ? '계속 수정' : '계속 작성',
        confirmLabel: '나가기',
        cancelFlex: 1,
        confirmFlex: 1,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (leave != true || !mounted || _isSubmitting) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _closeForm();
  }

  Future<void> _pickImages() async {
    final remaining = ReportService.maxImageCount - _selectedImages.length;
    if (remaining <= 0) {
      _showMessage('사진은 최대 3장까지 첨부할 수 있어요.');
      return;
    }
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 70);
      if (images.isEmpty) return;
      // 제출할 때가 아니라 고르는 즉시 용량과 장수를 확인하고 이유를 알립니다.
      final selection = await selectReportPhotos(images, remaining: remaining);
      if (!mounted) return;
      if (selection.accepted.isNotEmpty) {
        setState(() => _selectedImages.addAll(selection.accepted));
      }
      final notice = reportPhotoSelectionNotice(
        oversized: selection.oversized,
        overLimit: selection.overLimit,
      );
      if (notice != null) _showMessage(notice);
    } catch (e) {
      debugPrint('사진 첨부 오류: $e');
      if (mounted) _showMessage('사진을 불러오지 못했어요. 사진 접근 권한을 확인해주세요.');
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReport;
    if (initial != null) {
      _restoreInitialReport(initial);
    } else {
      final menus = _registeredMenuSlots.where(
        (item) =>
            widget.initialMenuIndex == null ||
            item.slot == widget.initialMenuIndex,
      );
      if (menus.isNotEmpty) {
        _selectedMenuIndex = menus.first.slot;
        _menuController.text = menus.first.menu;
      }
    }
    _initialSnapshot = _formSnapshot();
    _menuController.addListener(_onMenuChanged);
    _priceController.addListener(_onDraftEdited);
    _descController.addListener(_onDraftEdited);
    if (initial != null &&
        widget.store == null &&
        initial.storeId.trim().isNotEmpty) {
      Future.microtask(_loadTargetStore);
    }
  }

  void _restoreInitialReport(UserReportStatus initial) {
    final typeIndex = _changeTypes.indexWhere(
      (type) => type['value'] == initial.changeType.trim(),
    );
    if (typeIndex >= 0) _selectedType = typeIndex;
    final first = initial.menuPrices.isEmpty ? null : initial.menuPrices.first;
    _menuController.text = first?.menu.trim() ?? '';
    if (initial.changeType.trim() != 'delete' && first != null) {
      _priceController.text = first.price.trim();
      _isFree = first.free;
    }
    _descController.text = initial.description;
    _isConfirmed = initial.checkedMenuPrice;
    _selectedImages.addAll(
      initial.imageUrls.where(isRemoteReportImage).map(XFile.new),
    );
    _syncSelectedMenuSlot();
  }

  Future<void> _loadTargetStore() async {
    final storeId = widget.initialReport?.storeId.trim() ?? '';
    if (storeId.isEmpty || !mounted) return;
    setState(() => _loadingStore = true);
    final store = await ref.read(reportServiceProvider).fetchStore(storeId);
    if (!mounted) return;
    setState(() {
      _loadedStore = store;
      _loadingStore = false;
      _syncSelectedMenuSlot();
    });
  }

  void _syncSelectedMenuSlot() {
    final menu = _menuController.text.trim();
    final matches = _registeredMenuSlots.where((item) => item.menu == menu);
    _selectedMenuIndex = matches.isEmpty ? null : matches.first.slot;
  }

  void _onMenuChanged() {
    final index = _selectedMenuIndex;
    if (index != null &&
        _store?.menuAt(index).trim() != _menuController.text.trim()) {
      _selectedMenuIndex = null;
    }
    if (mounted) setState(() {});
  }

  void _onTypeSelected(int i) {
    if (_isEditing || _selectedType == i) return;
    setState(() {
      final prev = _selectedType;
      _selectedType = i;
      _priceController.clear();
      _isFree = false;
      if (i == 3) {
        if (_registeredMenus.any(
          (m) => m.menu == _menuController.text.trim(),
        )) {
          _menuController.clear();
          _priceController.clear();
        }
      } else if (prev == 3 && _menuController.text.trim().isEmpty) {
        final menus = _registeredMenuSlots;
        if (menus.isNotEmpty) {
          _selectedMenuIndex = menus.first.slot;
          _menuController.text = menus.first.menu;
        }
      }
    });
  }

  String _formatWon(String raw) {
    return formatWon(raw, fallback: raw);
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
    final selectedMenus = _registeredMenuSlots.where(
      (item) =>
          item.slot == _selectedMenuIndex &&
          item.menu == _menuController.text.trim(),
    );
    final selectedMenu = selectedMenus.isEmpty ? null : selectedMenus.first;
    final showMultiPriceNotice =
        selectedMenu != null &&
        (_selectedType == 0 || _selectedType == 1) &&
        hasInexactRegisteredPrice(selectedMenu.price);
    final submitLocked =
        _isSubmitting || _saved || (widget.initialReport?.isApproved ?? false);
    final form = FigmaMobileCanvas(
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: CustomAppBar(title: _isEditing ? '가격 변동 제보 수정' : '가격 변동 제보'),
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
                  if (_isEditing) ...[
                    const SizedBox(height: 8),
                    const Text(
                      priceChangeLockedNotice,
                      key: ValueKey('price-report-locked-notice'),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 변경된 메뉴
                  const Text(
                    '변경된 메뉴',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_registeredMenus.isNotEmpty && !_isEditing) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final item in _registeredMenuSlots) ...[
                            ChoiceChip(
                              key: ValueKey(
                                _registeredMenuSlots
                                            .where((m) => m.menu == item.menu)
                                            .length >
                                        1
                                    ? 'price-report-menu-chip-slot-${item.slot}'
                                    : 'price-report-menu-chip-${item.menu}',
                              ),
                              label: Text(
                                item.price.isNotEmpty
                                    ? '${item.menu} (${_formatWon(item.price)})'
                                    : item.menu,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedMenuIndex == item.slot
                                      ? AppColors.white
                                      : AppColors.ink,
                                  fontWeight: _selectedMenuIndex == item.slot
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: _selectedMenuIndex == item.slot,
                              selectedColor: AppColors.orangeTheme,
                              backgroundColor: AppColors.surface,
                              side: BorderSide(
                                color: _selectedMenuIndex == item.slot
                                    ? AppColors.orangeTheme
                                    : Colors.grey.shade300,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedMenuIndex = item.slot;
                                    _menuController.text = item.menu;
                                    _priceController.clear();
                                  } else {
                                    _menuController.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          ActionChip(
                            key: const ValueKey(
                              'price-report-manual-menu-chip',
                            ),
                            avatar: const Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppColors.muted,
                            ),
                            label: const Text(
                              '직접 입력',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            backgroundColor: AppColors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            onPressed: () {
                              setState(() {
                                _menuController.clear();
                                _priceController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildTextField(
                    _menuController,
                    _registeredMenus.isNotEmpty
                        ? '메뉴 이름 직접 입력 (예: ${_registeredMenus.first.menu})'
                        : '메뉴 이름 직접 입력',
                    readOnly: _isEditing,
                  ),
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
                    if (_selectedType != 3 &&
                        selectedMenu != null &&
                        selectedMenu.price.isNotEmpty) ...[
                      Text(
                        '기존 가격 ${_formatWon(selectedMenu.price)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (showMultiPriceNotice) ...[
                      _buildMultiPriceNotice(),
                      const SizedBox(height: 10),
                    ],
                    _buildPriceField(),
                    Semantics(
                      label: '무료 메뉴 여부',
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('무료 (정확히 0원)'),
                        value: _isFree,
                        onChanged: (value) =>
                            setState(() => _isFree = value ?? false),
                      ),
                    ),
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
            text: _isSubmitting
                ? '제보 저장 중...'
                : (_isEditing ? '제보 수정하기' : '가격 변동 제보하기'),
            backgroundColor: AppColors.orangeTheme,
            onPressed: submitLocked ? null : _submit,
          ),
        ),
      ),
    );
    _blocksPop = _hasUnsavedChanges;
    return PopScope(
      canPop: !_isSubmitting && !_blocksPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: form,
    );
  }

  Widget _buildStoreCard() {
    final s = _store;
    final initial = widget.initialReport;
    final primaryMenu = s != null && s.menu1.trim().isNotEmpty
        ? s.menu1.trim()
        : null;
    final fallbackCategory = initial != null && initial.category.isNotEmpty
        ? initial.category
        : '메뉴 정보 기입';
    final subtitle = primaryMenu != null
        ? '대표 메뉴: $primaryMenu'
        : _loadingStore
        ? '매장 정보를 불러오고 있어요'
        : (s?.industry ?? fallbackCategory);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
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
                  s?.storeName ?? initial?.store ?? widget.storeName,
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
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            s != null && s.price1.trim().isNotEmpty
                ? _formatWon(s.price1)
                : '-',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiPriceNotice() {
    final store = _store;
    return Container(
      key: const ValueKey('price-report-multi-price-notice'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            priceChangeMultiPriceMessage,
            style: TextStyle(color: AppColors.ink, fontSize: 12, height: 1.5),
          ),
          if (store != null && store.id.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    context.push(AppRoutes.storeInfoReport, extra: store),
                child: const Text('정보 신고로 알리기'),
              ),
            )
          else
            const SizedBox(height: 6),
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
        final locked = _isEditing && !selected;
        return GestureDetector(
          onTap: locked ? null : () => _onTypeSelected(i),
          child: Opacity(
            opacity: locked ? .45 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.orangeLight : AppColors.white,
                borderRadius: BorderRadius.circular(16),
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

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: '변경된 메뉴',
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
        labelText: '변경된 가격',
        hintText: '새 가격을 입력해주세요',
        suffixText: '원',
        suffixStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.orangeTheme),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.orangeTheme, width: 2),
        ),
      ),
    );
  }

  ImageProvider _thumbnailImage(XFile image) {
    final ImageProvider source = isRemoteReportImage(image.path) || kIsWeb
        ? NetworkImage(image.path)
        : FileImage(File(image.path));
    // 72px 썸네일을 원본 해상도로 디코딩하지 않도록 줄여서 읽습니다.
    return ResizeImage.resizeIfNeeded(216, null, source);
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
                borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    image: DecorationImage(
                      image: _thumbnailImage(image),
                      fit: BoxFit.cover,
                      // 지워진 원격 사진도 화면 오류 없이 빈 칸으로 둡니다.
                      onError: (_, _) {},
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    tooltip: '첨부 사진 ${_selectedImages.indexOf(image) + 1} 제거',
                    onPressed: () {
                      setState(() {
                        _selectedImages.remove(image);
                      });
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
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
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.orangeTheme),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    // One node: the check box alone read only its value (QA 10/7 #53).
    return MergeSemantics(
      child: Row(
        children: [
          Checkbox(
            value: _isConfirmed,
            onChanged: (v) => setState(() => _isConfirmed = v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          const Text('직접 메뉴판 가격을 확인했어요', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

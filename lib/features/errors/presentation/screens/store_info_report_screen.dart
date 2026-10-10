import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';
import 'package:howmuch/core/utils/price_formatter.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

class StoreInfoReportTarget {
  const StoreInfoReportTarget({this.store, this.initialReport});
  final Store? store;
  final UserReportStatus? initialReport;
}

class StoreInfoReportScreen extends ConsumerStatefulWidget {
  const StoreInfoReportScreen({super.key, this.store, this.initialReport});

  final Store? store;
  final UserReportStatus? initialReport;

  @override
  ConsumerState<StoreInfoReportScreen> createState() =>
      _StoreInfoReportScreenState();
}

class _StoreInfoReportScreenState extends ConsumerState<StoreInfoReportScreen> {
  int _selectedTypeIndex = 1; // 기본: '가격이 달라요'
  bool _isSubmitting = false;
  bool _saved = false;
  bool _leaving = false;
  bool _isFree = false;
  int? _selectedMenuSlot;
  String? _priceError;
  String? _descriptionError;
  final _firstInvalidFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  /// The form as it opened, so leaving without changes does not ask (QA #35).
  late final String _initialSnapshot;

  /// Whether the last build asked [PopScope] to stop the back gesture.
  bool _blocksPop = false;

  Store? get _store {
    if (widget.store != null) return widget.store;
    final initial = widget.initialReport;
    if (initial == null || initial.storeId.isEmpty) return null;
    final menus = initial.menuPrices;
    return Store.fromJson({
      'storeId': initial.storeId,
      'storeName': initial.store,
      'industry': initial.category,
      'address': initial.address,
      'latitude': initial.latitude,
      'longitude': initial.longitude,
      for (var i = 0; i < menus.length && i < 4; i++) ...{
        'menu${i + 1}': menus[i].menu,
        'price${i + 1}': menus[i].price,
        'free${i + 1}': menus[i].free,
      },
    });
  }

  List<({int slot, String menu, String price})> get _registeredMenuSlots {
    final store = _store;
    if (store == null) return const [];
    return [
      for (var slot = 1; slot <= 4; slot++)
        if (store.menuAt(slot).trim().isNotEmpty)
          (
            slot: slot,
            menu: store.menuAt(slot).trim(),
            price: store.priceAt(slot).trim(),
          ),
    ];
  }

  @override
  void initState() {
    super.initState();
    final slots = _registeredMenuSlots;
    _selectedMenuSlot = slots.isEmpty ? null : slots.first.slot;
    final initial = widget.initialReport;
    if (initial != null) {
      _selectedTypeIndex = _types.indexWhere(
        (type) => type['value'] == initial.changeType,
      );
      _descController.text = initial.description;
      if (initial.menuPrices.isNotEmpty &&
          initial.changeType == 'price_mismatch') {
        _priceController.text = initial.menuPrices.first.price;
        _isFree = initial.menuPrices.first.free;
        final reportedMenu = initial.menuPrices.first.menu.trim();
        final matching = slots.where((item) => item.menu == reportedMenu);
        if (matching.isNotEmpty) _selectedMenuSlot = matching.first.slot;
      }
    }
    _initialSnapshot = _formSnapshot();
    _priceController.addListener(_onDraftEdited);
    _descController.addListener(_onDraftEdited);
  }

  String _formSnapshot() => [
    _selectedTypeIndex,
    _selectedMenuSlot,
    _priceController.text.trim(),
    _isFree,
    _descController.text.trim(),
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
      context.go(
        widget.initialReport == null ? AppRoutes.home : AppRoutes.myReportsV2,
      );
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
    final editing = widget.initialReport != null;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => HowmuchDialog(
        title: editing ? '수정 중인 신고를 나갈까요?' : '작성 중인 신고를 나갈까요?',
        description: editing ? '수정한 내용은 저장되지 않아요.' : '입력한 신고 내용은 저장되지 않아요.',
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
    if (widget.initialReport?.isApproved == true) {
      _showMessage('승인된 제보는 수정할 수 없어요.');
      return;
    }
    if (_selectedTypeIndex < 0) {
      _showMessage('신고 유형을 선택해주세요.');
      return;
    }
    final description = _descController.text.trim();
    final price = _priceController.text.trim();
    setState(() {
      _priceError = null;
      _descriptionError = null;
    });
    if (_store == null) {
      _showMessage('매장 정보가 없어 신고할 수 없어요.');
      return;
    }
    final parsedPrice = parsePriceValue(price);
    if (_selectedTypeIndex == 1 &&
        (parsedPrice == null ||
            !parsedPrice.isExact ||
            (_isFree ? parsedPrice.minimum != 0 : parsedPrice.minimum <= 0))) {
      setState(
        () => _priceError = _isFree
            ? '무료 메뉴는 정확히 0원으로 입력해주세요.'
            : '실제 가격은 0보다 큰 정확한 금액을 입력해주세요.',
      );
      _firstInvalidFocus.requestFocus();
      return;
    }
    if (description.isEmpty) {
      setState(() => _descriptionError = '신고 내용을 입력해주세요.');
      _descriptionFocus.requestFocus();
      return;
    }
    // A guest is asked once the report is complete. The form stays as written
    // beneath the login screens and is sent right after. Logged-in visitors
    // go on without waiting, so a quick second tap finds the form submitting.
    if (!ApiClient.isAuthenticated) {
      final loggedIn = await requireLogin(
        context,
        message: '로그인하면 작성한 신고가 바로 접수돼요.',
      );
      if (!loggedIn || !mounted) return;
    }
    setState(() => _isSubmitting = true);
    try {
      final store = _store!;
      final initial = widget.initialReport;
      final service = ref.read(reportServiceProvider);
      final isPriceMismatch = _selectedTypeIndex == 1;
      // '가격이 달라요'는 사용자가 고른 메뉴를 첫 번째 칸에 담아 보냅니다.
      // 서버와 관리자 검토 화면은 첫 번째 칸을 신고 대상 메뉴로 읽습니다.
      final targetSlot = _selectedMenuSlot ?? 1;
      final request = isPriceMismatch
          ? UserReport(
              storeId: store.id,
              storeName: store.storeName,
              industry: store.industry,
              address: store.address,
              phoneNumber: store.phoneNumber,
              menu1: store.menuAt(targetSlot),
              price1: price,
              free1: _isFree,
              latitude: store.latitude,
              longitude: store.longitude,
              imageUrls: initial?.imageUrls ?? const [],
              reporterId: '',
              visitedRecently: false,
              checkedMenuPrice: true,
              changeType: _types[_selectedTypeIndex]['value'],
              reportType: 'STORE_INFO',
              description: description,
            )
          : UserReport(
              storeId: store.id,
              storeName: store.storeName,
              industry: store.industry,
              address: store.address,
              phoneNumber: store.phoneNumber,
              menu1: store.menu1,
              price1: store.price1,
              free1: store.free1,
              menu2: store.menu2,
              price2: store.price2,
              free2: store.free2,
              menu3: store.menu3,
              price3: store.price3,
              free3: store.free3,
              menu4: store.menu4,
              price4: store.price4,
              free4: store.free4,
              latitude: store.latitude,
              longitude: store.longitude,
              imageUrls: initial?.imageUrls ?? const [],
              reporterId: '',
              visitedRecently: false,
              checkedMenuPrice: false,
              changeType: _types[_selectedTypeIndex]['value'],
              reportType: 'STORE_INFO',
              description: description,
            );
      if (initial == null) {
        await service.submitReport(request);
      } else {
        await service.updateReport(initial.id, request);
      }
      final reports = await service.fetchMyReports();
      if (!mounted) return;
      if (reports != null) {
        ref.read(userReportsProvider.notifier).setReports(reports);
      }
      _saved = true;
      ScaffoldMessenger.of(context).showSnackBar(
        HowmuchSnackBar(
          content: Text(
            initial == null
                ? '정보 신고가 접수되었습니다. 관리자 확인 후 반영됩니다.'
                : '정보 신고 수정이 저장됐어요.',
          ),
        ),
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
    // Replaces the notice on screen at once and floats above the submit
    // button, so the button can be tapped again while it shows (QA #37).
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        HowmuchSnackBar(content: Text(message), aboveNavigation: true),
      );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    _firstInvalidFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = FigmaMobileCanvas(
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: const CustomAppBar(title: '정보 신고'),
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
                  const Text.rich(
                    TextSpan(
                      text: '신고 유형 선택 ',
                      children: [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: AppColors.reportAccent),
                        ),
                      ],
                    ),
                    style: _sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  _buildTypeList(),
                  const SizedBox(height: 24),

                  // 실제 가격 (가격이 달라요 선택 시)
                  if (_selectedTypeIndex == 1) ...[
                    const Text('실제 가격 (필수)', style: _sectionTitleStyle),
                    const SizedBox(height: 8),
                    if (_registeredMenuSlots.isNotEmpty) ...[
                      const Text(
                        '가격이 다른 메뉴를 골라주세요',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final item in _registeredMenuSlots)
                            _buildMenuChip(item),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    _buildPriceField(),
                    if (_priceError != null) _inlineError(_priceError!),
                    const SizedBox(height: 4),
                    _ReportCheckRow(
                      label: '무료 (정확히 0원)',
                      value: _isFree,
                      onChanged: (value) => setState(() {
                        _isFree = value;
                        if (_isFree) _priceController.text = '0';
                        _priceError = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 추가 설명
                  const Text('신고 내용 (필수)', style: _sectionTitleStyle),
                  const SizedBox(height: 8),
                  _buildDescField(),
                  if (_descriptionError != null)
                    _inlineError(_descriptionError!),
                  const SizedBox(height: 20),

                  _buildWarningBox(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomButton(
            text: _isSubmitting ? '접수 중...' : '신고 접수하기',
            backgroundColor: AppColors.reportAccent,
            onPressed: _isSubmitting || widget.initialReport?.isApproved == true
                ? null
                : _submit,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _store?.storeName ?? '매장 정보 없음',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _store?.address ?? '매장 주소 정보 없음',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeList() {
    return Column(
      children: [
        for (var i = 0; i < _types.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _TypeCard(
            title: _types[i]['title']!,
            description: _types[i]['desc']!,
            selected: _selectedTypeIndex == i,
            onTap: () => setState(() => _selectedTypeIndex = i),
          ),
        ],
      ],
    );
  }

  Widget _buildMenuChip(({int slot, String menu, String price}) item) {
    final selected = _selectedMenuSlot == item.slot;
    return ChoiceChip(
      key: ValueKey('info-report-menu-${item.slot}'),
      label: Text(
        item.price.isEmpty
            ? item.menu
            : '${item.menu} (${formatWon(item.price, fallback: item.price)})',
        style: TextStyle(
          fontSize: 12,
          color: selected ? AppColors.white : AppColors.ink,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.reportAccent,
      backgroundColor: AppColors.white,
      side: BorderSide(
        color: selected ? AppColors.reportAccent : AppColors.borderMedium,
      ),
      onSelected: (_) => setState(() {
        _selectedMenuSlot = item.slot;
        _priceError = null;
      }),
    );
  }

  /// Hint-only field on a white fill, with the form's accent on focus and a
  /// red outline while the field has an error.
  InputDecoration _fieldDecoration({
    required String hint,
    required bool hasError,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
  }) {
    OutlineInputBorder outline(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: contentPadding,
      border: outline(AppColors.border),
      enabledBorder: outline(hasError ? AppColors.errorText : AppColors.border),
      focusedBorder: outline(
        hasError ? AppColors.errorText : AppColors.reportAccent,
        width: 1.5,
      ),
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _priceController,
      focusNode: _firstInvalidFocus,
      keyboardType: TextInputType.number,
      // An error about the old value goes away once it is being fixed.
      onChanged: (_) {
        if (_priceError != null) setState(() => _priceError = null);
      },
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration:
          _fieldDecoration(
            hint: '실제 가격을 입력해주세요',
            hasError: _priceError != null,
          ).copyWith(
            suffixText: '원',
            suffixStyle: const TextStyle(color: AppColors.muted),
          ),
    );
  }

  Widget _buildDescField() {
    return TextField(
      controller: _descController,
      focusNode: _descriptionFocus,
      maxLines: 3,
      // QA #36: '신고 내용을 입력해주세요' disappears as soon as there is text.
      onChanged: (value) {
        if (_descriptionError != null && value.trim().isNotEmpty) {
          setState(() => _descriptionError = null);
        }
      },
      decoration: _fieldDecoration(
        hint: '신고할 내용을 알려주세요.',
        hasError: _descriptionError != null,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _inlineError(String message) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.errorText, fontSize: 12),
    ),
  );

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '신고는 운영팀이 확인 후 처리돼요.',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '허위 신고 시 이용이 제한될 수 있어요.',
                  style: TextStyle(color: AppColors.textBody, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _sectionTitleStyle = TextStyle(
  color: AppColors.ink,
  fontSize: 14,
  fontWeight: FontWeight.bold,
);

/// One report type as a selectable card: the chosen one gets the report
/// accent outline and fill plus a check mark.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.input);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.orangeLight : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? AppColors.reportAccent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: AppMotion.fast,
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.reportAccent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A check box with its label to the right. The whole row toggles it, as in
/// the review form.
class _ReportCheckRow extends StatelessWidget {
  const _ReportCheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // One node: the check box alone read only its value and the text had no
    // checked state (QA 10/7 #53).
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (checked) => onChanged(checked ?? false),
                activeColor: AppColors.reportAccent,
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textBody,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

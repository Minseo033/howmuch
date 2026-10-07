import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
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
    if (!ApiClient.isAuthenticated) {
      _showMessage('정보 신고는 로그인 후 이용할 수 있어요.');
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
          backgroundColor: const Color(0xFFF4F6FA),
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
                          style: TextStyle(color: Color(0xFFF97316)),
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
                      '실제 가격 (필수)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_registeredMenuSlots.isNotEmpty) ...[
                      const Text(
                        '가격이 다른 메뉴를 골라주세요',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in _registeredMenuSlots)
                            ChoiceChip(
                              key: ValueKey('info-report-menu-${item.slot}'),
                              label: Text(
                                item.price.isEmpty
                                    ? item.menu
                                    : '${item.menu} (${formatWon(item.price, fallback: item.price)})',
                              ),
                              selected: _selectedMenuSlot == item.slot,
                              onSelected: (_) => setState(() {
                                _selectedMenuSlot = item.slot;
                                _priceError = null;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildPriceField(),
                    Semantics(
                      label: '무료 메뉴 여부',
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('무료 (정확히 0원)'),
                        value: _isFree,
                        onChanged: (value) => setState(() {
                          _isFree = value ?? false;
                          if (_isFree) _priceController.text = '0';
                          _priceError = null;
                        }),
                      ),
                    ),
                    if (_priceError != null) _inlineError(_priceError!),
                    const SizedBox(height: 20),
                  ],

                  // 추가 설명
                  const Text(
                    '신고 내용 (필수)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
            backgroundColor: const Color(0xFFF97316),
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
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
                  _store?.storeName ?? '매장 정보 없음',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  _store?.address ?? '매장 주소 정보 없음',
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
        borderRadius: BorderRadius.circular(22),
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
                            ? const Color(0xFF10B981)
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
      focusNode: _firstInvalidFocus,
      keyboardType: TextInputType.number,
      // An error about the old value goes away once it is being fixed.
      onChanged: (_) {
        if (_priceError != null) setState(() => _priceError = null);
      },
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: '실제 가격 (필수)',
        suffixText: '원',
        suffixStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
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
          borderSide: const BorderSide(color: Color(0xFF10B981)),
        ),
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
      decoration: InputDecoration(
        labelText: '신고 내용 (필수)',
        hintStyle: const TextStyle(color: Colors.grey),
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
          borderSide: const BorderSide(color: Color(0xFF10B981)),
        ),
      ),
    );
  }

  Widget _inlineError(String message) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      message,
      style: const TextStyle(color: Colors.red, fontSize: 12),
    ),
  );

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(16),
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

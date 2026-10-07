import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:howmuch/core/constants/feature_flags.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:howmuch/core/location/browser_location.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart'
    show HomeMapScreen, isFreshHomeLocation;
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/core/utils/price_formatter.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';
import 'package:howmuch/shared/widgets/login_required_dialog.dart';

class ReportPlaceSuggestion {
  const ReportPlaceSuggestion({
    required this.name,
    required this.address,
    this.category = '',
    this.distanceMeters = -1,
  });

  final String name;
  final String address;
  final String category;
  final int distanceMeters;
}

/// 카카오 업종을 먼저 보고, 업종으로 판단하지 못할 때만 매장명 단어를 씁니다.
/// (예: '김밥천국 고속버스터미널점'이 매장명의 '버스' 때문에 교통으로 분류되지 않게)
String? normalizeReportIndustry(String rawCategory, {String placeName = ''}) {
  final fromCategory = _industryFromText(rawCategory);
  final fromName = _industryFromText(placeName);
  if (fromCategory == null) return fromName;
  // '음식점'처럼 넓은 업종이면 매장명이 같은 먹거리 업종 안에서 더 구체적일 때만 씁니다.
  if (fromCategory == '음식점 · 기타' &&
      fromName != null &&
      (fromName.startsWith('음식점 ·') || fromName.startsWith('카페·디저트 ·'))) {
    return fromName;
  }
  return fromCategory;
}

String? _industryFromText(String raw) {
  final value = raw.toLowerCase().replaceAll(' ', '');
  if (value.isEmpty) return null;

  if (_containsCategory(value, const [
    '주차장',
    '주차타워',
    '주차시설',
    '주차서비스',
    'parking',
  ])) {
    return '교통·주차 · 주차장';
  }
  if (_containsCategory(value, const ['버스', '지하철', '택시', '교통'])) {
    return '교통·주차 · 교통서비스';
  }

  if (_containsCategory(value, const ['베이커리', '제과', '빵집', '제빵'])) {
    return '카페·디저트 · 베이커리';
  }
  if (_containsCategory(value, const ['디저트', '아이스크림', '빙수', '도넛', '떡집'])) {
    return '카페·디저트 · 디저트·아이스크림';
  }
  if (_containsCategory(value, const ['카페', '커피', 'coffee'])) {
    return '카페·디저트 · 카페·커피';
  }
  if (_containsCategory(value, const ['치킨', '닭강정'])) return '음식점 · 치킨';
  if (_containsCategory(value, const ['패스트푸드', '햄버거'])) {
    return '음식점 · 패스트푸드';
  }
  if (_containsCategory(value, const ['육류', '고기', '갈비', '구이'])) {
    return '음식점 · 고기·구이';
  }
  if (_containsCategory(value, const ['한식'])) return '음식점 · 한식';
  if (_containsCategory(value, const ['중식', '중화요리'])) return '음식점 · 중식';
  if (_containsCategory(value, const ['일식', '초밥', '스시'])) return '음식점 · 일식';
  if (_containsCategory(value, const ['양식'])) return '음식점 · 양식';
  if (_containsCategory(value, const ['분식'])) return '음식점 · 분식';
  if (_containsCategory(value, const ['미용실', '미용업', '헤어샵'])) {
    return '생활서비스 · 미용실';
  }
  if (_containsCategory(value, const ['이발소', '이용원', '이용업'])) {
    return '생활서비스 · 이발소';
  }
  if (_containsCategory(value, const ['세탁'])) return '생활서비스 · 세탁소';
  if (_containsCategory(value, const ['수선', '수리'])) {
    return '생활서비스 · 수선·수리';
  }
  if (_containsCategory(value, const ['목욕', '사우나'])) {
    return '생활서비스 · 목욕·사우나';
  }
  if (_containsCategory(value, const ['펜션', '게스트하우스', '민박'])) {
    return '숙박 · 펜션·게스트하우스';
  }
  if (_containsCategory(value, const ['호텔', '모텔', '숙박'])) {
    return '숙박 · 호텔·모텔';
  }
  if (_containsCategory(value, const ['음식점', '요식업', '술집'])) {
    return '음식점 · 기타';
  }
  if (_containsCategory(value, const ['서비스', '비요식업'])) {
    return '기타 · 생활서비스';
  }
  return null;
}

bool _containsCategory(String value, List<String> candidates) {
  return candidates.any(value.contains);
}

typedef PlaceSearch =
    Future<List<ReportPlaceSuggestion>> Function(
      String query,
      double? latitude,
      double? longitude,
    );
typedef LocationLookup =
    Future<({double latitude, double longitude})?> Function();

/// Why the store search cannot use the current position at all.
enum ReportLocationIssue { permissionDenied, serviceDisabled }

/// Thrown by a [LocationLookup] when the position cannot be used at all. A
/// lookup that only failed to get a fix in time returns null instead, so the
/// search does not blame a permission the user granted (QA #34).
class ReportLocationUnavailable implements Exception {
  const ReportLocationUnavailable(this.issue);

  final ReportLocationIssue issue;
}

/// The current position for the store search.
///
/// Uses the home map's position when it is recent. Otherwise it takes the
/// same steps as the home map and search: on the web the shared browser
/// request (reuses a fix up to two minutes old and does not count the time
/// spent on the permission prompt); in the app the location service,
/// permission, a recent fix, then a fresh one.
Future<({double latitude, double longitude})?> lookUpReportLocation() async {
  final known = HomeMapScreen.globalUserPosition;
  if (known != null && isFreshHomeLocation(known.timestamp, DateTime.now())) {
    return (latitude: known.latitude, longitude: known.longitude);
  }
  try {
    final position = await _currentReportPosition();
    return (latitude: position.latitude, longitude: position.longitude);
  } on ReportLocationUnavailable {
    rethrow;
  } on PermissionDeniedException {
    throw const ReportLocationUnavailable(ReportLocationIssue.permissionDenied);
  } on LocationServiceDisabledException {
    throw const ReportLocationUnavailable(ReportLocationIssue.serviceDisabled);
  } catch (_) {
    // A slow or failed fix: the permission may well be granted.
    return null;
  }
}

Future<Position> _currentReportPosition() async {
  if (kIsWeb) return requestBrowserLocation();
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ReportLocationUnavailable(ReportLocationIssue.serviceDisabled);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const ReportLocationUnavailable(ReportLocationIssue.permissionDenied);
  }
  final cached = await Geolocator.getLastKnownPosition();
  if (cached != null && isFreshHomeLocation(cached.timestamp, DateTime.now())) {
    return cached;
  }
  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.medium,
    timeLimit: const Duration(seconds: 8),
  ).timeout(const Duration(seconds: 10));
}

const maxReportMenuCount = 4;

enum ReportPlaceSelectionMode { store, address }

String? validateReportMenuCount(int count) => count < 1
    ? '대표 메뉴는 최소 1개가 필요해요.'
    : count > maxReportMenuCount
    ? '메뉴는 최대 4개까지 저장할 수 있어요. 초과 메뉴를 제거해주세요.'
    : null;

/// 게스트가 제출하려다 로그인하러 갈 때 작성 중이던 새 제보를 잠시 보관합니다.
/// 로그인 뒤 홈으로 이동해도 제보 화면을 다시 열면 이어서 쓸 수 있습니다.
/// 앱이 실행 중인 동안에만 유지합니다.
class ReportDraftStash {
  ReportDraftStash._();

  static ReportDraft? _pending;

  static void save(ReportDraft draft) => _pending = draft;

  static ReportDraft? take() {
    final draft = _pending;
    _pending = null;
    return draft;
  }

  static void discard() => _pending = null;
}

class ReportDraft {
  const ReportDraft({
    required this.store,
    required this.category,
    required this.address,
    required this.menus,
    required this.photos,
    required this.visitedRecently,
    required this.checkedMenuPrice,
  });

  final String store;
  final String category;
  final String address;
  final List<({String menu, String price, bool free})> menus;
  final List<XFile> photos;
  final bool visitedRecently;
  final bool checkedMenuPrice;

  bool get isEmpty =>
      store.isEmpty &&
      category.isEmpty &&
      address.isEmpty &&
      photos.isEmpty &&
      menus.every((item) => item.menu.isEmpty && item.price.isEmpty);
}

class ReportCreateScreen extends ConsumerStatefulWidget {
  const ReportCreateScreen({
    super.key,
    this.initialReport,
    this.placeSearch,
    this.locationLookup,
  });

  final UserReportStatus? initialReport;
  final PlaceSearch? placeSearch;
  final LocationLookup? locationLookup;

  @override
  ConsumerState<ReportCreateScreen> createState() => _ReportCreateScreenState();
}

class _ReportCreateScreenState extends ConsumerState<ReportCreateScreen> {
  static const _priceSectionOffset = 354.46;
  static const _baseConfirmSectionOffset = 490.23;
  static const _basePriceCardHeight = 91.776;
  static const _categoryOptions = [
    '음식점 · 한식',
    '음식점 · 중식',
    '음식점 · 일식',
    '음식점 · 양식',
    '음식점 · 분식',
    '음식점 · 고기·구이',
    '음식점 · 치킨',
    '음식점 · 패스트푸드',
    '음식점 · 기타',
    '카페·디저트 · 카페·커피',
    '카페·디저트 · 베이커리',
    '카페·디저트 · 디저트·아이스크림',
    '생활서비스 · 미용실',
    '생활서비스 · 이발소',
    '생활서비스 · 세탁소',
    '생활서비스 · 수선·수리',
    '생활서비스 · 목욕·사우나',
    '숙박 · 호텔·모텔',
    '숙박 · 펜션·게스트하우스',
    '교통·주차 · 주차장',
    '교통·주차 · 교통서비스',
    '기타 · 생활서비스',
  ];
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late final TextEditingController _storeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _addressController;
  bool _visitedRecently = false;
  bool _checkedMenuPrice = false;
  int _activeStep = 1;
  bool _isSubmitting = false;
  bool _saved = false;
  bool _leaving = false;
  final List<XFile> _photos = [];
  final List<_MenuPriceControllers> _menuPrices = [];
  final Map<String, Future<Uint8List>> _photoBytes = {};
  final _uploads = ReportUploadSession();
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final initialReport = widget.initialReport;
    final draft = initialReport == null ? ReportDraftStash.take() : null;
    _storeController = TextEditingController(text: initialReport?.store ?? '');
    _categoryController = TextEditingController(
      text: initialReport?.category ?? '',
    );
    _addressController = TextEditingController(
      text: initialReport?.address ?? '',
    );
    _visitedRecently = initialReport?.visitedRecently ?? false;
    _checkedMenuPrice = initialReport?.checkedMenuPrice ?? false;
    _photos.addAll(
      (initialReport?.imageUrls ?? const []).map((path) => XFile(path)),
    );
    _storeController.addListener(_onFormChanged);
    _categoryController.addListener(_onFormChanged);
    _addressController.addListener(_onFormChanged);
    final initialMenus = initialReport?.menuPrices ?? const [];
    if (initialMenus.isEmpty) {
      final initialMenu = _splitMenuText(initialReport?.menu ?? '');
      _addInitialMenuPrice(menu: initialMenu.$1, price: initialMenu.$2);
    } else {
      for (final menuPrice in initialMenus) {
        _addInitialMenuPrice(
          menu: menuPrice.menu,
          price: menuPrice.price,
          free: menuPrice.free,
        );
      }
    }
    _scrollController.addListener(_syncStepWithScroll);
    _initialSnapshot = _formSnapshot();
    if (draft != null && !draft.isEmpty) {
      _restoreDraft(draft);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnack('로그인 전에 작성하던 제보를 불러왔어요.');
      });
    }
  }

  void _restoreDraft(ReportDraft draft) {
    _storeController.text = draft.store;
    _categoryController.text = draft.category;
    _addressController.text = draft.address;
    for (final menuPrice in _menuPrices) {
      menuPrice.dispose();
    }
    _menuPrices.clear();
    for (final item in draft.menus.take(maxReportMenuCount)) {
      _addInitialMenuPrice(menu: item.menu, price: item.price, free: item.free);
    }
    if (_menuPrices.isEmpty) _addInitialMenuPrice(menu: '', price: '');
    _photos.addAll(draft.photos.take(ReportService.maxImageCount));
    _visitedRecently = draft.visitedRecently;
    _checkedMenuPrice = draft.checkedMenuPrice;
  }

  void _stashDraftForLogin() {
    if (widget.initialReport != null) return;
    final draft = ReportDraft(
      store: _storeController.text.trim(),
      category: _categoryController.text.trim(),
      address: _addressController.text.trim(),
      menus: [
        for (final menuPrice in _menuPrices)
          (
            menu: menuPrice.menu.text.trim(),
            price: menuPrice.price.text.trim(),
            free: menuPrice.free,
          ),
      ],
      photos: List.of(_photos),
      visitedRecently: _visitedRecently,
      checkedMenuPrice: _checkedMenuPrice,
    );
    if (!draft.isEmpty) ReportDraftStash.save(draft);
  }

  Future<void> _openLoginKeepingDraft() async {
    _stashDraftForLogin();
    await context.push(AppRoutes.login);
  }

  /// 작성 중 이탈 여부를 판단하기 위한 입력값 요약입니다.
  String _formSnapshot() => [
    _storeController.text.trim(),
    _categoryController.text.trim(),
    _addressController.text.trim(),
    for (final menuPrice in _menuPrices)
      '${menuPrice.menu.text.trim()}|${menuPrice.price.text.trim()}|${menuPrice.free}',
    for (final photo in _photos) photo.path,
    '$_visitedRecently|$_checkedMenuPrice',
  ].join('\n');

  bool get _hasUnsavedChanges =>
      !_saved && !_leaving && _formSnapshot() != _initialSnapshot;

  void _closeForm() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.communityFeed);
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
    if (_isSubmitting) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => HowmuchDialog(
        title: '작성을 그만두고 나갈까요?',
        description: '입력한 제보 내용은 저장되지 않아요.',
        cancelLabel: '계속 작성',
        confirmLabel: '나가기',
        cancelFlex: 1,
        confirmFlex: 1,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (leave != true || !mounted) return;
    if (widget.initialReport == null) ReportDraftStash.discard();
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _closeForm();
  }

  (String, String) _splitMenuText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return ('', '');
    final lastSpace = trimmed.lastIndexOf(' ');
    if (lastSpace == -1) return (trimmed, '');
    final menu = trimmed.substring(0, lastSpace).trim();
    final price = trimmed.substring(lastSpace + 1).replaceAll('원', '').trim();
    return (menu, price);
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
        _menuPrices.every((menuPrice) {
          if (menuPrice.menu.text.trim().isEmpty) return false;
          final parsed = parsePriceValue(menuPrice.price.text);
          return parsed != null &&
              parsed.isExact &&
              (menuPrice.free ? parsed.minimum == 0 : parsed.minimum > 0);
        });
  }

  bool get _confirmInfoComplete {
    return _basicInfoComplete &&
        _priceInfoComplete &&
        _visitedRecently &&
        _checkedMenuPrice;
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _addInitialMenuPrice({
    required String menu,
    required String price,
    bool free = false,
  }) {
    final menuPrice = _MenuPriceControllers(menu: menu, price: price);
    menuPrice.free = free;
    menuPrice.addListener(_onFormChanged);
    _menuPrices.add(menuPrice);
  }

  void _addMenuPrice() {
    if (_menuPrices.length >= maxReportMenuCount) return;
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
      ..showSnackBar(HowmuchSnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_isSubmitting || _saved) return;
    final initialReport = widget.initialReport;
    if (initialReport != null && initialReport.isExistingStoreReport) {
      // 가격 변동·정보 신고를 이 화면에서 저장하면 유형과 대상 매장이 사라집니다.
      _showSnack('가격 변동 제보와 정보 신고는 제보 상세의 수정하기에서 고쳐주세요.');
      return;
    }
    final menuCountError = validateReportMenuCount(_menuPrices.length);
    if (menuCountError != null) {
      _showSnack(menuCountError);
      return;
    }

    final auth = ref.read(authStateProvider);
    if (!auth.isLoggedIn) {
      final shouldLogin = await showLoginRequiredDialog(
        context,
        message:
            '제보하려면 카카오 로그인이 필요해요. 로그인한 뒤 제보 화면을 다시 열면 작성한 내용을 이어서 쓸 수 있어요.',
      );
      if (shouldLogin && mounted) {
        await _openLoginKeepingDraft();
      }
      return;
    }

    if (!_basicInfoComplete || !_priceInfoComplete) {
      _showSnack('필수 정보를 모두 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    final reportService = ref.read(reportServiceProvider);
    UserReport? backendReport;
    var saveRequestSent = false;

    try {
      String menuAt(int index) =>
          _menuPrices.length > index ? _menuPrices[index].menu.text.trim() : '';
      String priceAt(int index) => _menuPrices.length > index
          ? _menuPrices[index].price.text.trim()
          : '';
      bool freeAt(int index) =>
          _menuPrices.length > index && _menuPrices[index].free;
      final reportImageUrls = await _uploads.resolveImageUrls(
        reportService,
        _photos,
        uploadEnabled: FeatureFlags.reportImageUploadEnabled,
      );

      backendReport = UserReport(
        cityProvince: '',
        cityDistrict: '',
        storeName: _storeController.text.trim(),
        industry: _categoryController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: '',
        menu1: menuAt(0),
        price1: priceAt(0),
        menu2: menuAt(1),
        price2: priceAt(1),
        menu3: menuAt(2),
        price3: priceAt(2),
        menu4: menuAt(3),
        price4: priceAt(3),
        free1: freeAt(0),
        free2: freeAt(1),
        free3: freeAt(2),
        free4: freeAt(3),
        imageUrls: reportImageUrls,
        // 서버는 제보자를 로그인 세션으로만 판단하므로 계정 정보를 보내지 않습니다.
        reporterId: '',
        visitedRecently: _visitedRecently,
        checkedMenuPrice: _checkedMenuPrice,
        latitude: 0.0,
        longitude: 0.0,
      );

      // 이전 시도가 응답 없이 끝났다면, 다시 보내기 전에 이미 저장됐는지 확인합니다.
      String? reportId = _uploads.saveOutcomeUnknown
          ? await _findSavedReportId(reportService, backendReport)
          : null;
      if (reportId == null) {
        saveRequestSent = true;
        if (initialReport == null) {
          reportId = await reportService.submitReport(backendReport);
        } else {
          await reportService.updateReport(initialReport.id, backendReport);
          reportId = initialReport.id;
        }
      }
      await _completeSaved(reportService, reportId);
    } on ReportServiceException catch (error) {
      // 서버가 거절했으므로 저장되지 않았습니다.
      if (error.cleanupUploadedImages) {
        await _uploads.discardUnsaved(reportService);
      }
      if (mounted) _showSnack(error.message);
    } catch (error) {
      debugPrint('제보 저장 중 예외: $error');
      if (saveRequestSent && backendReport != null) {
        // 시간 초과나 연결 끊김은 서버에 저장됐을 수 있어 사진을 지우지 않고 확인합니다.
        _uploads.saveOutcomeUnknown = true;
        final savedId = await _findSavedReportId(reportService, backendReport);
        if (savedId != null) {
          await _completeSaved(reportService, savedId);
        } else if (mounted) {
          _showSnack(reportSaveOutcomeUnknownMessage);
        }
      } else {
        await _uploads.discardUnsaved(reportService);
        if (mounted) _showSnack('제보 저장 중 오류가 발생했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _findSavedReportId(
    ReportService reportService,
    UserReport report,
  ) async {
    final reports = await reportService.fetchMyReports();
    if (reports == null) return null;
    return matchSavedReport(
      reports,
      report,
      reportId: widget.initialReport?.id,
    )?.id;
  }

  Future<void> _completeSaved(
    ReportService reportService,
    String reportId,
  ) async {
    _uploads.markSaved();
    if (widget.initialReport == null) ReportDraftStash.discard();
    // 저장된 뒤에는 같은 폼으로 다시 제출할 수 없게 잠급니다.
    _saved = true;
    // Never show an optimistic draft as if the server saved every field.
    final savedReports = await reportService.fetchMyReports();
    if (!mounted) return;
    if (savedReports == null ||
        !savedReports.any((item) => item.id == reportId)) {
      _showSnack('제보는 저장됐어요. 저장 내용을 다시 확인해주세요.');
      context.go(AppRoutes.myReportsV2);
      return;
    }
    ref.read(userReportsProvider.notifier).setReports(savedReports);
    final profile = ref.read(userProfileProvider);
    ref.read(userProfileProvider.notifier).state = profile.copyWith(
      reportCount: savedReports.length,
    );
    if (widget.initialReport == null) {
      // 완료 화면이 작성 화면을 대신해, 뒤로 가도 입력이 남은 폼으로 돌아가지 않습니다.
      context.pushReplacement(
        '${AppRoutes.reportComplete}?id=${Uri.encodeQueryComponent(reportId)}',
      );
    } else {
      context.go('${AppRoutes.reportDetailV2}?id=$reportId');
    }
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

  Future<List<ReportPlaceSuggestion>> _searchPlaces(
    String query,
    double? latitude,
    double? longitude,
  ) async {
    final injectedSearch = widget.placeSearch;
    if (injectedSearch != null) {
      return injectedSearch(query, latitude, longitude);
    }

    final queryParameters = <String, String>{'q': query};
    if (latitude != null && longitude != null) {
      queryParameters
        ..['lat'] = latitude.toString()
        ..['lng'] = longitude.toString();
    }

    final response = await ApiClient.get(
      ApiClient.uri('/api/locations/places', queryParameters),
      headers: ApiClient.authHeaders(),
    ).timeout(ApiClient.defaultTimeout);
    if (response.statusCode != 200) {
      throw const FormatException('매장 검색에 실패했습니다.');
    }

    final data = ApiClient.decodeJson(response);
    final places = data['places'] as List? ?? const [];
    final results = places
        .whereType<Map>()
        .map((place) {
          final distance = place['distanceMeters'];
          return ReportPlaceSuggestion(
            name: place['name']?.toString().trim() ?? '',
            address: place['address']?.toString().trim() ?? '',
            category: place['category']?.toString().trim() ?? '',
            distanceMeters: distance is num
                ? distance.toInt()
                : int.tryParse(distance?.toString() ?? '') ?? -1,
          );
        })
        .where((place) => place.name.isNotEmpty && place.address.isNotEmpty)
        .toList(growable: false);
    if (results.isNotEmpty) return results;

    final addressResponse = await ApiClient.get(
      ApiClient.uri('/api/locations/addresses', {'q': query}),
      headers: ApiClient.authHeaders(),
    ).timeout(ApiClient.defaultTimeout);
    if (addressResponse.statusCode != 200) return const [];
    final addressData = ApiClient.decodeJson(addressResponse);
    final addresses = addressData['addresses'] as List? ?? const [];
    return addresses
        .map(
          (value) =>
              ReportPlaceSuggestion(name: '', address: value.toString().trim()),
        )
        .where((place) => place.address.isNotEmpty)
        .toList(growable: false);
  }

  Future<({double latitude, double longitude})?> _lookupLocation() async {
    final injectedLookup = widget.locationLookup;
    if (injectedLookup != null) return injectedLookup();
    if (widget.placeSearch != null) return null;
    return lookUpReportLocation();
  }

  Future<void> _pickPlace({
    required ReportPlaceSelectionMode mode,
    String initialQuery = '',
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final mediaQuery = MediaQuery.of(context);
    final selected = await showModalBottomSheet<ReportPlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF4F6FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      constraints: BoxConstraints(
        maxWidth: math.min(
          FigmaMobileCanvas.maxWebWidth,
          mediaQuery.size.width,
        ),
        maxHeight: math.max(
          0,
          mediaQuery.size.height - mediaQuery.padding.top - 8,
        ),
      ),
      builder: (context) => _AddressSearchSheet(
        search: _searchPlaces,
        locate: _lookupLocation,
        initialQuery: initialQuery,
      ),
    );
    if (selected != null && mounted) {
      _addressController.text = selected.address;
      if (mode == ReportPlaceSelectionMode.store && selected.name.isNotEmpty) {
        _storeController.text = selected.name;
        final industry = normalizeReportIndustry(
          selected.category,
          placeName: selected.name,
        );
        _categoryController.text = industry ?? '';
      }
    }
  }

  Future<void> _pickStore() => _pickPlace(
    mode: ReportPlaceSelectionMode.store,
    initialQuery: _storeController.text.trim(),
  );

  Future<void> _pickAddress() => _pickPlace(
    mode: ReportPlaceSelectionMode.address,
    initialQuery: _addressController.text.trim(),
  );

  Future<String?> _showOptionPicker({
    required String title,
    required List<String> options,
    required String initialValue,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final mediaQuery = MediaQuery.of(context);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFF4F6FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      constraints: BoxConstraints(
        maxWidth: math.min(
          FigmaMobileCanvas.maxWebWidth,
          mediaQuery.size.width,
        ),
        maxHeight: math.max(
          0,
          mediaQuery.size.height - mediaQuery.padding.top - 8,
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSizes.horizontalPadding),
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
                  final isCurrent = option == initialValue;
                  // The check mark alone did not tell screen readers which
                  // option is current (QA 10/7 #53). `selected` only marks
                  // it: the title and the check keep their own colors.
                  return Semantics(
                    inMutuallyExclusiveGroup: true,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: isCurrent,
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
                      trailing: isCurrent
                          ? const Icon(
                              Icons.check_rounded,
                              color: ReportCreateStyle.blue,
                              size: 18,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(option),
                    ),
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
    if (_photos.length >= ReportService.maxImageCount) {
      _showSnack('사진은 최대 3장까지 첨부할 수 있어요.');
      return;
    }
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted || pickedImage == null) {
        return;
      }
      // 제출할 때가 아니라 고르는 즉시 용량을 확인합니다.
      final selection = await selectReportPhotos([
        pickedImage,
      ], remaining: ReportService.maxImageCount - _photos.length);
      if (!mounted) return;
      final notice = reportPhotoSelectionNotice(
        oversized: selection.oversized,
        overLimit: selection.overLimit,
      );
      if (notice != null) _showSnack(notice);
      if (selection.accepted.isEmpty) return;
      setState(() => _photos.addAll(selection.accepted));
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

    setState(() {
      final removed = _photos.removeAt(index);
      _photoBytes.remove(removed.path);
    });
  }

  /// 입력할 때마다 화면이 다시 그려져도 같은 사진을 다시 읽지 않도록 보관합니다.
  Future<Uint8List> _photoBytesFor(XFile photo) =>
      _photoBytes.putIfAbsent(photo.path, photo.readAsBytes);

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    const stepProgressHeight = 60.98;
    const topChromeHeight = HowmuchTopBar.height + stepProgressHeight;
    final isGuest = !ref.watch(authStateProvider).isLoggedIn;

    return PopScope(
      canPop: !_isSubmitting && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: FigmaMobileCanvas(
          backgroundColor: const Color(0xFFF4F6FA),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: topOffset + topChromeHeight,
                child: const ColoredBox(color: Colors.white),
              ),
              Positioned(
                left: 0,
                top: topOffset,
                right: 0,
                height: HowmuchTopBar.height,
                child: _Header(onBack: _handleBack),
              ),
              Positioned(
                left: 0,
                top: topOffset + HowmuchTopBar.height,
                right: 0,
                height: stepProgressHeight,
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
                top: topOffset + topChromeHeight,
                right: 0,
                bottom: 0,
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
                    _TipBox(
                      onLoginTap: isGuest && widget.initialReport == null
                          ? _openLoginKeepingDraft
                          : null,
                    ),
                    const SizedBox(height: 11.989),
                    const _SectionLabel(title: '기본 정보', required: true),
                    const SizedBox(height: 10),
                    _BasicInfoCard(
                      storeController: _storeController,
                      categoryController: _categoryController,
                      addressController: _addressController,
                      onStoreSearch: _pickStore,
                      onCategoryTap: _pickCategory,
                      onAddressTap: _pickAddress,
                    ),
                    const SizedBox(height: 15.994),
                    const _SectionLabel(title: '가격 정보', required: true),
                    const SizedBox(height: 10),
                    _PriceInfoCard(
                      menuPrices: _menuPrices,
                      onAdd: _addMenuPrice,
                      onRemove: _removeMenuPrice,
                      onChanged: _onFormChanged,
                    ),
                    const SizedBox(height: 15.994),
                    const _SectionLabel(
                      title: FeatureFlags.reportImageUploadEnabled
                          ? '사진 및 확인'
                          : '방문 확인',
                      required: !FeatureFlags.reportImageUploadEnabled,
                      optional: FeatureFlags.reportImageUploadEnabled,
                    ),
                    const SizedBox(height: 10),
                    _PhotoConfirmCard(
                      showPhotoUpload: FeatureFlags.reportImageUploadEnabled,
                      photos: _photos,
                      photoBytes: _photoBytesFor,
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
                    _SubmitFooter(
                      onPressed: _saved ? null : _submit,
                      isSubmitting: _isSubmitting,
                      isEditing: widget.initialReport != null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportCreateStyle {
  const ReportCreateStyle._();

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const line = Color(0xFFE5E7EB);
  static const fontFamily = 'Noto Sans KR';
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

class _MenuPriceControllers {
  _MenuPriceControllers({required String menu, required String price})
    : menu = TextEditingController(text: menu),
      price = TextEditingController(text: price);

  final TextEditingController menu;
  final TextEditingController price;
  bool free = false;

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
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return HowmuchTopBar(
      title: '가성비 매장 제보',
      titleFontSize: 17,
      showBorder: false,
      onBack: onBack,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.horizontalPadding,
        ),
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
          mainAxisSize: MainAxisSize.min,
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
  const _TipBox({this.onLoginTap});

  /// 게스트일 때만 전달합니다. 작성 전에 로그인하도록 안내해 입력이 사라지지 않게 합니다.
  final VoidCallback? onLoginTap;

  @override
  Widget build(BuildContext context) {
    final loginTap = onLoginTap;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          loginTap == null
              ? '동네의 좋은 가격 정보를 함께 나눠주세요.\n검토 후 지도에 표시됩니다.'
              : '제보는 로그인 후 제출할 수 있어요.\n여기를 눌러 먼저 카카오 로그인해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF92400E),
            fontFamily: ReportCreateStyle.fontFamily,
            fontFamilyFallback: ReportCreateStyle.fontFallback,
            fontSize: 12,
            fontWeight: loginTap == null ? FontWeight.w400 : FontWeight.w600,
            height: 1.45,
          ),
        ),
      ),
    );
    if (loginTap == null) return box;
    return Semantics(
      button: true,
      label: '카카오 로그인하기',
      child: GestureDetector(
        key: const ValueKey('report-guest-login-tip'),
        behavior: HitTestBehavior.opaque,
        onTap: loginTap,
        child: box,
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
    required this.onStoreSearch,
    required this.onCategoryTap,
    required this.onAddressTap,
  });

  final TextEditingController storeController;
  final TextEditingController categoryController;
  final TextEditingController addressController;
  final VoidCallback onStoreSearch;
  final VoidCallback onCategoryTap;
  final VoidCallback onAddressTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.898, 12.898, 12.898, 12.898),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EditableFormRow(
            label: '매장명',
            required: true,
            controller: storeController,
            hintText: '매장명을 입력하거나 검색',
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onStoreSearch(),
            trailing: _SuffixAction(
              icon: Icons.search_rounded,
              semanticLabel: '매장 검색',
              onTap: onStoreSearch,
            ),
          ),
          const SizedBox(height: 10),
          _EditableFormRow(
            label: '업종',
            required: true,
            controller: categoryController,
            readOnly: true,
            onTap: onCategoryTap,
            trailing: _SuffixAction(
              icon: Icons.keyboard_arrow_down_rounded,
              semanticLabel: '업종 선택',
              onTap: onCategoryTap,
            ),
          ),
          const SizedBox(height: 10),
          _EditableFormRow(
            label: '주소',
            required: true,
            controller: addressController,
            hintText: '도로명 또는 지번 주소 검색',
            readOnly: true,
            onTap: onAddressTap,
            trailing: _SuffixAction(
              icon: Icons.search_rounded,
              semanticLabel: '주소 검색',
              onTap: onAddressTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the store search knows about the current position. Only a refused
/// permission is described as one (QA #34).
enum _SheetLocation {
  locating('현재 위치 확인 중…'),
  located('현재 위치에서 가까운 순으로 보여드려요.'),
  permissionDenied('위치 권한이 없어 검색 관련도순으로 보여드려요.'),
  serviceDisabled('위치 서비스가 꺼져 있어 검색 관련도순으로 보여드려요.'),
  unavailable('현재 위치를 확인하지 못해 검색 관련도순으로 보여드려요.');

  const _SheetLocation(this.message);

  final String message;
}

class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet({
    required this.search,
    required this.locate,
    this.initialQuery = '',
  });

  final PlaceSearch search;
  final LocationLookup locate;
  final String initialQuery;

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  /// Searches typed while the position is still being found wait this long
  /// for it, so the first results are already ordered by distance (QA #34).
  static const _locationWait = Duration(seconds: 3);

  late final TextEditingController _controller;
  Timer? _debounce;
  Timer? _locationWaitTimer;
  List<ReportPlaceSuggestion> _results = const [];
  bool _isLoading = false;
  _SheetLocation _locationStatus = _SheetLocation.locating;
  bool _hasSearched = false;
  bool _hasError = false;
  int _requestId = 0;
  ({double latitude, double longitude})? _location;

  bool get _isLocating => _locationStatus == _SheetLocation.locating;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    final initialQuery = widget.initialQuery.trim();
    _isLoading = initialQuery.length >= 2;
    _loadLocation();
    if (_isLoading) _searchWhenLocated(initialQuery);
  }

  Future<void> _loadLocation() async {
    ({double latitude, double longitude})? location;
    var status = _SheetLocation.unavailable;
    try {
      location = await widget.locate();
      if (location != null) status = _SheetLocation.located;
    } on ReportLocationUnavailable catch (error) {
      status = switch (error.issue) {
        ReportLocationIssue.permissionDenied => _SheetLocation.permissionDenied,
        ReportLocationIssue.serviceDisabled => _SheetLocation.serviceDisabled,
      };
    } catch (_) {
      // Treated as a position that could not be found.
    }
    if (!mounted) return;
    _locationWaitTimer?.cancel();
    _locationWaitTimer = null;
    setState(() {
      _location = location;
      _locationStatus = status;
    });
    final query = _controller.text.trim();
    if (query.length >= 2) {
      _debounce?.cancel();
      setState(() => _isLoading = true);
      _search(query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationWaitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      _requestId++;
      setState(() {
        _results = const [];
        _isLoading = false;
        _hasSearched = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchWhenLocated(query),
    );
  }

  void _searchWhenLocated(String query) {
    if (!_isLocating) {
      _search(query);
      return;
    }
    // _loadLocation searches with the latest query once the position is in.
    _locationWaitTimer ??= Timer(_locationWait, () {
      _locationWaitTimer = null;
      final latest = _controller.text.trim();
      if (mounted && _isLocating && latest.length >= 2) _search(latest);
    });
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final location = _location;
      final results = await widget.search(
        query,
        location?.latitude,
        location?.longitude,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
        _hasSearched = true;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = const [];
        _isLoading = false;
        _hasSearched = true;
        _hasError = true;
      });
    }
  }

  void _retry() {
    final query = _controller.text.trim();
    if (query.length >= 2) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      _search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ReportCreateStyle.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '매장 또는 주소 검색',
                style: TextStyle(
                  color: ReportCreateStyle.ink,
                  fontFamily: ReportCreateStyle.fontFamily,
                  fontFamilyFallback: ReportCreateStyle.fontFallback,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '매장명, 도로명 또는 지번으로 찾아보세요.',
                style: TextStyle(
                  color: ReportCreateStyle.muted,
                  fontFamily: ReportCreateStyle.fontFamily,
                  fontFamilyFallback: ReportCreateStyle.fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _location != null
                        ? Icons.my_location_rounded
                        : Icons.location_off_outlined,
                    size: 15,
                    color: _location != null
                        ? ReportCreateStyle.blue
                        : ReportCreateStyle.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _locationStatus.message,
                      style: const TextStyle(
                        color: ReportCreateStyle.muted,
                        fontFamily: ReportCreateStyle.fontFamily,
                        fontFamilyFallback: ReportCreateStyle.fontFallback,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('report-address-search-input'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  if (value.trim().length >= 2) {
                    _searchWhenLocated(value.trim());
                  }
                },
                style: const TextStyle(
                  color: ReportCreateStyle.ink,
                  fontFamily: ReportCreateStyle.fontFamily,
                  fontFamilyFallback: ReportCreateStyle.fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: '예: 롯데리아, 테헤란로 123',
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색어 지우기',
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: ReportCreateStyle.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: ReportCreateStyle.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: ReportCreateStyle.blue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_hasError) {
      return _AddressSearchMessage(
        icon: Icons.wifi_off_rounded,
        message: '주소를 불러오지 못했어요.',
        actionLabel: '다시 시도',
        onAction: _retry,
      );
    }
    if (!_hasSearched) {
      return const _AddressSearchMessage(
        icon: Icons.storefront_outlined,
        message: '두 글자 이상 입력하면 매장과 주소를 찾아드려요.',
      );
    }
    if (_results.isEmpty) {
      return const _AddressSearchMessage(
        icon: Icons.search_off_rounded,
        message: '검색 결과가 없어요. 매장명이나 주소를 확인해주세요.',
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: ReportCreateStyle.border),
      itemBuilder: (context, index) {
        final place = _results[index];
        final hasPlaceName = place.name.isNotEmpty;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 2),
          minVerticalPadding: 12,
          leading: Icon(
            hasPlaceName
                ? Icons.storefront_outlined
                : Icons.location_on_outlined,
            color: ReportCreateStyle.blue,
            size: 22,
          ),
          title: Text(
            hasPlaceName ? place.name : place.address,
            style: const TextStyle(
              color: ReportCreateStyle.ink,
              fontFamily: ReportCreateStyle.fontFamily,
              fontFamilyFallback: ReportCreateStyle.fontFallback,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          subtitle: hasPlaceName
              ? Text(
                  place.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ReportCreateStyle.muted,
                    fontFamily: ReportCreateStyle.fontFamily,
                    fontFamilyFallback: ReportCreateStyle.fontFallback,
                    fontSize: 12,
                    height: 1.4,
                  ),
                )
              : null,
          trailing: place.distanceMeters >= 0
              ? Text(
                  _formatDistance(place.distanceMeters),
                  style: const TextStyle(
                    color: ReportCreateStyle.blue,
                    fontFamily: ReportCreateStyle.fontFamily,
                    fontFamilyFallback: ReportCreateStyle.fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => Navigator.of(context).pop(place),
        );
      },
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    final kilometers = meters / 1000;
    return kilometers < 10
        ? '${kilometers.toStringAsFixed(1)}km'
        : '${kilometers.round()}km';
  }
}

class _AddressSearchMessage extends StatelessWidget {
  const _AddressSearchMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: ReportCreateStyle.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReportCreateStyle.muted,
              fontFamily: ReportCreateStyle.fontFamily,
              fontFamilyFallback: ReportCreateStyle.fontFallback,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
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
    required this.onChanged,
  });

  final List<_MenuPriceControllers> menuPrices;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.898, 12.898, 12.898, 12.898),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < menuPrices.length; index++) ...[
            _MenuPriceRow(
              key: ObjectKey(menuPrices[index]),
              index: index,
              menuPrice: menuPrices[index],
              showRemove: menuPrices.length > 1,
              onRemove: () => onRemove(index),
              onChanged: onChanged,
            ),
            if (index != menuPrices.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              onPressed: menuPrices.length < maxReportMenuCount ? onAdd : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('메뉴 추가'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ReportCreateStyle.orange,
                side: const BorderSide(color: Color(0xFFFDE68A), width: .909),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
          if (menuPrices.length >= maxReportMenuCount)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '메뉴는 최대 4개까지 입력할 수 있어요.',
                style: TextStyle(color: ReportCreateStyle.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuPriceRow extends StatelessWidget {
  const _MenuPriceRow({
    super.key,
    required this.index,
    required this.menuPrice,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
  });

  /// Position in the menu list, starting at 0 for the main menu.
  final int index;
  final _MenuPriceControllers menuPrice;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // Every row shows the '대표 메뉴' label, so screen readers heard the same
    // name for all of them. Added rows are named by their order, like the
    // completion screen (QA 10/7 #53).
    final name = index == 0 ? '대표 메뉴' : '메뉴 ${index + 1}';
    return SizedBox(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _EditableFormRow(
                  label: '대표 메뉴',
                  semanticLabel: index == 0 ? null : name,
                  required: true,
                  controller: menuPrice.menu,
                ),
              ),
              const SizedBox(width: 7.997),
              Expanded(
                child: _EditableFormRow(
                  label: '가격',
                  semanticLabel: index == 0 ? null : '$name 가격',
                  required: true,
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
                  width: 44,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 25.494),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                          child: IconButton(
                            tooltip:
                                '${menuPrice.menu.text.trim().isEmpty ? '메뉴' : menuPrice.menu.text} 제거',
                            onPressed: onRemove,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
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
          Semantics(
            container: true,
            label: index == 0 ? '무료 메뉴 여부' : '$name 무료 여부',
            child: Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('무료 (가격은 정확히 0원만 가능)'),
                value: menuPrice.free,
                onChanged: (value) {
                  menuPrice.free = value ?? false;
                  if (menuPrice.free) menuPrice.price.text = '0';
                  onChanged();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableFormRow extends StatelessWidget {
  const _EditableFormRow({
    required this.label,
    required this.controller,
    this.semanticLabel,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.onSubmitted,
    this.hintText,
    this.required = false,
  });

  final String label;
  final TextEditingController controller;

  /// The name screen readers hear for the field when it differs from the
  /// visible [label]. The visible label is then left out of the semantics so
  /// the field is not announced under two names.
  final String? semanticLabel;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final visibleLabel = Text.rich(
      TextSpan(
        text: label,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: ReportCreateStyle.orange,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
      style: const TextStyle(
        color: ReportCreateStyle.muted,
        fontFamily: ReportCreateStyle.fontFamily,
        fontFamilyFallback: ReportCreateStyle.fontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    );
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (semanticLabel == null)
            visibleLabel
          else
            ExcludeSemantics(child: visibleLabel),
          const SizedBox(height: 5.994),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ReportCreateStyle.border, width: .909),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label:
                        '${semanticLabel ?? label}${required ? ', 필수 입력' : ''}',
                    child: TextField(
                      controller: controller,
                      readOnly: readOnly,
                      showCursor: !readOnly,
                      enableInteractiveSelection: !readOnly,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      inputFormatters: inputFormatters,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      cursorColor: ReportCreateStyle.blue,
                      textAlignVertical: TextAlignVertical.center,
                      onTap: onTap,
                      onSubmitted: onSubmitted,
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
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Colors.white,
                        hoverColor: Colors.transparent,
                        hintText: hintText,
                        hintStyle: const TextStyle(
                          color: ReportCreateStyle.muted,
                          fontFamily: ReportCreateStyle.fontFamily,
                          fontFamilyFallback: ReportCreateStyle.fontFallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
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
  const _SuffixAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: semanticLabel,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: const EdgeInsets.only(left: 8),
      icon: Icon(icon, size: 18, color: ReportCreateStyle.muted),
    );
  }
}

class _PhotoConfirmCard extends StatelessWidget {
  const _PhotoConfirmCard({
    required this.showPhotoUpload,
    required this.photos,
    required this.photoBytes,
    required this.visitedRecently,
    required this.checkedMenuPrice,
    required this.onPhotoTap,
    required this.onPhotoRemove,
    required this.onVisitedChanged,
    required this.onCheckedChanged,
  });

  final bool showPhotoUpload;
  final List<XFile> photos;
  final Future<Uint8List> Function(XFile photo) photoBytes;
  final bool visitedRecently;
  final bool checkedMenuPrice;
  final VoidCallback onPhotoTap;
  final ValueChanged<int> onPhotoRemove;
  final ValueChanged<bool> onVisitedChanged;
  final ValueChanged<bool> onCheckedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.898, 12.898, 12.898, 12.898),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPhotoUpload) ...[
            _PhotoUploadBox(photos: photos, onTap: onPhotoTap),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 7.997),
              _PhotoThumbnailStrip(
                photos: photos,
                photoBytes: photoBytes,
                onRemove: onPhotoRemove,
              ),
              const SizedBox(height: 9.989),
            ] else
              const SizedBox(height: 11.989),
          ],
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
    final subtitle = hasPhotos ? photos.first.name : '가격 확인을 위해 권장해요';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 71.605,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE5E7EB),
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
  const _PhotoThumbnailStrip({
    required this.photos,
    required this.photoBytes,
    required this.onRemove,
  });

  final List<XFile> photos;
  final Future<Uint8List> Function(XFile photo) photoBytes;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 7.997;
        final slotSize = (constraints.maxWidth - (gap * 2)) / 3;
        final decodeWidth = (slotSize * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 1200);

        return SizedBox(
          height: slotSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (context, index) => const SizedBox(width: gap),
            itemBuilder: (context, index) {
              final photo = photos[index];
              return SizedBox(
                width: slotSize,
                height: slotSize,
                child: _PhotoThumbnailSlot(
                  photo: photo,
                  bytes: isRemoteReportImage(photo.path)
                      ? null
                      : photoBytes(photo),
                  decodeWidth: decodeWidth,
                  index: index,
                  onRemove: onRemove,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PhotoThumbnailSlot extends StatelessWidget {
  const _PhotoThumbnailSlot({
    required this.photo,
    required this.bytes,
    required this.decodeWidth,
    required this.index,
    required this.onRemove,
  });

  final XFile? photo;
  final Future<Uint8List>? bytes;
  final int decodeWidth;
  final int index;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    final imagePath = photo?.path ?? '';
    final isRemoteImage =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: photo == null ? const Color(0xFFF4F6FA) : Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB), width: .909),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null && isRemoteImage)
              Image.network(
                imagePath,
                fit: BoxFit.cover,
                cacheWidth: decodeWidth,
                errorBuilder: (_, _, _) => const _PhotoThumbnailFallback(),
              )
            else if (photo != null)
              FutureBuilder<Uint8List>(
                future: bytes,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: decodeWidth,
                      gaplessPlayback: true,
                    );
                  }

                  if (snapshot.hasError) {
                    return const _PhotoThumbnailFallback();
                  }

                  return const _PhotoThumbnailLoading();
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
                child: IconButton(
                  tooltip: '첨부 사진 ${index + 1} 제거',
                  onPressed: () => onRemove(index),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xE60F172A),
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnailLoading extends StatelessWidget {
  const _PhotoThumbnailLoading();

  @override
  Widget build(BuildContext context) {
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
  }
}

class _PhotoThumbnailFallback extends StatelessWidget {
  const _PhotoThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFFF3EA),
      child: Center(
        child: Icon(
          Icons.camera_alt_outlined,
          color: ReportCreateStyle.muted,
          size: 20,
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
    // A hand-drawn check box: say what it confirms and whether it is checked
    // (it read as plain text, QA 10/7 #53). Without the enabled flag iOS reads
    // a checked item as a disabled switch.
    return Semantics(
      container: true,
      checked: value,
      enabled: true,
      child: GestureDetector(
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
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    )
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
      ),
    );
  }
}

class _SubmitFooter extends StatelessWidget {
  const _SubmitFooter({
    required this.onPressed,
    required this.isSubmitting,
    required this.isEditing,
  });

  final VoidCallback? onPressed;
  final bool isSubmitting;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: isSubmitting ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ReportCreateStyle.blue,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x4D2563EB),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                isEditing ? '제보 수정하기' : '제보 제출하기',
                style: const TextStyle(
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
  borderRadius: BorderRadius.circular(22),
);

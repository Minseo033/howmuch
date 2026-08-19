import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/state/visit_verification_policy.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class VisitVerificationScreen extends StatefulWidget {
  final String storeName;
  final Store? store;

  const VisitVerificationScreen({
    super.key,
    this.storeName = '매장 정보 없음',
    this.store,
  });

  @override
  State<VisitVerificationScreen> createState() =>
      _VisitVerificationScreenState();
}

class _VisitVerificationScreenState extends State<VisitVerificationScreen> {
  final _amountController = TextEditingController();
  final _menuController = TextEditingController();
  bool _isSubmitting = false;
  bool _isCheckingLocation = false;
  bool _isSubmittingReceipt = false;
  XFile? _receiptImage;
  double? _distanceMeters;
  double? _currentLatitude;
  double? _currentLongitude;
  double? _locationAccuracyMeters;
  String? _locationError;

  Timer? _estimateDebounce;
  int? _estimatedSaved;
  int? _referencePrice;
  bool _matchedByMenu = false;
  final ImagePicker _imagePicker = ImagePicker();

  String get _storeName => widget.store?.storeName ?? widget.storeName;

  bool get _hasStoreCoordinates {
    final store = widget.store;
    return store != null &&
        VisitVerificationPolicy.hasValidStoreCoordinates(
          store.latitude,
          store.longitude,
        );
  }

  bool get _isLocationVerified {
    final distance = _distanceMeters;
    return distance != null &&
        VisitVerificationPolicy.isWithinVerificationRadius(distance);
  }

  @override
  void dispose() {
    _estimateDebounce?.cancel();
    _amountController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: GestureDetector(
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
                    '위치 인증',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildLocationVerificationCard(),
                  const SizedBox(height: 12),
                  _buildReceiptComingSoonCard(),
                  const SizedBox(height: 24),
                  // 메뉴 · 결제 금액 입력
                  _buildMenuPriceSection(),
                  const SizedBox(height: 16),
                  // 예상 절약 금액 카드
                  _buildSavingsCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomButton(
            text: _isSubmitting
                ? '기록 중…'
                : _isLocationVerified
                ? '방문 기록하기'
                : '위치 인증 후 기록하기',
            backgroundColor: AppColors.primary,
            onPressed: _isSubmitting || !_isLocationVerified ? null : _submit,
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _storeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.store?.address ?? '매장 위치 정보가 없습니다.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
            child: Text(
              _distanceLabel,
              style: const TextStyle(
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

  String get _distanceLabel {
    if (_isCheckingLocation) return '확인 중';
    if (_isLocationVerified) {
      return VisitVerificationPolicy.formatDistance(_distanceMeters!);
    }
    return '위치 확인 필요';
  }

  String get _locationDescription {
    if (!_hasStoreCoordinates) return '이 매장은 위치 정보가 없어 인증할 수 없어요.';
    if (_isCheckingLocation) return '현재 위치와 매장 거리를 확인하고 있어요.';
    if (_isLocationVerified) {
      return '매장까지 ${VisitVerificationPolicy.formatDistance(_distanceMeters!)} · 위치 인증 가능';
    }
    if (_distanceMeters != null) {
      return '매장까지 ${VisitVerificationPolicy.formatDistance(_distanceMeters!)} · 50m 이내에서 인증할 수 있어요.';
    }
    return _locationError ?? '현재 위치를 확인하면 50m 이내에서 인증할 수 있어요.';
  }

  Future<void> _checkLocation() async {
    if (!_hasStoreCoordinates) {
      setState(() => _locationError = '매장 위치 정보가 없어 인증할 수 없어요.');
      return;
    }

    setState(() {
      _isCheckingLocation = true;
      _locationError = null;
      _distanceMeters = null;
      _currentLatitude = null;
      _currentLongitude = null;
      _locationAccuracyMeters = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationVerificationException('위치 서비스를 활성화해주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationVerificationException('위치 권한이 거부되었습니다.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationVerificationException('설정에서 위치 권한을 허용해주세요.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!VisitVerificationPolicy.hasUsableLocationAccuracy(
        position.accuracy,
      )) {
        throw const _LocationVerificationException(
          '현재 위치 정확도가 낮아요. 잠시 후 다시 시도해주세요.',
        );
      }
      final store = widget.store!;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        store.latitude,
        store.longitude,
      );
      if (!mounted) return;
      setState(() {
        _distanceMeters = distance;
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _locationAccuracyMeters = position.accuracy;
      });
    } on _LocationVerificationException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = '현재 위치를 가져오지 못했어요. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  Widget _buildLocationVerificationCard() {
    final verified = _isLocationVerified;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified ? AppColors.primarySubtle : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified ? AppColors.primary : Colors.grey.shade200,
          width: verified ? 2 : 1,
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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '현재 위치로 인증하기',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _locationDescription,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                verified
                    ? Icons.check_circle_rounded
                    : Icons.location_searching_rounded,
                color: verified ? AppColors.primary : Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCheckingLocation ? null : _checkLocation,
              icon: Icon(
                _isCheckingLocation
                    ? Icons.hourglass_top_rounded
                    : Icons.my_location_rounded,
              ),
              label: Text(_isCheckingLocation ? '현재 위치 확인 중' : '현재 위치 확인'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptComingSoonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '영수증 인증',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _receiptImage == null
                      ? '영수증 사진을 제출하면 관리자 확인 후 방문 기록으로 반영돼요.'
                      : '영수증 사진이 선택되었습니다. 결제 금액을 입력한 뒤 제출하세요.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (_receiptImage != null && !_isSubmittingReceipt) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _submitReceipt,
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text('영수증 제출'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '영수증 사진 선택',
            onPressed: _isSubmittingReceipt ? null : _pickReceiptImage,
            icon: Icon(
              _receiptImage == null
                  ? Icons.add_a_photo_outlined
                  : Icons.change_circle_outlined,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceiptImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (!mounted || image == null) return;
    setState(() => _receiptImage = image);
    await _submitReceipt();
  }

  Future<void> _submitReceipt() async {
    final image = _receiptImage;
    final store = widget.store;
    if (image == null || store == null || _isSubmittingReceipt) return;
    if (!ApiClient.isAuthenticated) {
      setState(() => _receiptImage = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('영수증 인증은 로그인 후 이용할 수 있어요.')));
      return;
    }
    final price = _priceValue;
    if (price <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('영수증 인증 전에 결제 금액을 입력해주세요.')));
      return;
    }
    setState(() => _isSubmittingReceipt = true);
    try {
      final request =
          http.MultipartRequest('POST', ApiClient.uri('/api/visits/receipt'))
            ..headers.addAll(ApiClient.jsonHeaders(auth: true))
            ..fields['storeId'] = store.id
            ..fields['storeName'] = store.storeName
            ..fields['menu'] = _menuController.text.trim()
            ..fields['price'] = price.toString();
      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('images', bytes, filename: 'receipt.jpg'),
      );
      final response = await request.send().timeout(ApiClient.defaultTimeout);
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('영수증 제출 실패 ${response.statusCode} $body');
      }
      final responseData = jsonDecode(body) as Map<String, dynamic>;
      final status = responseData['status']?.toString().toUpperCase();
      if (!mounted) return;
      setState(() => _receiptImage = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'APPROVED'
                ? '영수증 인증이 완료되어 방문 기록에 반영됐어요.'
                : '영수증 인증을 신청했어요. 관리자 확인 후 반영됩니다.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('영수증 인증 오류: $error');
      if (mounted) {
        setState(() => _receiptImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('영수증 인증 신청에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReceipt = false);
    }
  }

  /// 메뉴 · 결제 금액 입력 (방문 인증 시 절약 금액 계산에 사용)
  Widget _buildMenuPriceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '메뉴 · 결제 금액',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _menuController,
            onChanged: (_) => _onInputChanged(),
            decoration: _inputDecoration('메뉴 이름 (예: 김치찌개)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _onInputChanged(),
            decoration: _inputDecoration('결제 금액 입력 (원)'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }

  int get _priceValue =>
      int.tryParse(_amountController.text.replaceAll(RegExp(r'[^\d]'), '')) ??
      0;

  /// 입력 변경 시 400ms 디바운스로 예상 절약 금액 조회 (GET /api/visits/estimate)
  void _onInputChanged() {
    _estimateDebounce?.cancel();
    _estimateDebounce = Timer(
      const Duration(milliseconds: 400),
      _fetchEstimate,
    );
    setState(() {});
  }

  Future<void> _fetchEstimate() async {
    final price = _priceValue;
    if (price <= 0) {
      setState(() {
        _estimatedSaved = null;
        _referencePrice = null;
        _matchedByMenu = false;
      });
      return;
    }
    try {
      final response = await http
          .get(
            ApiClient.uri('/api/visits/estimate', {
              'storeName': _storeName,
              'menu': _menuController.text.trim(),
              'price': '$price',
            }),
            headers: ApiClient.jsonHeaders(auth: true),
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200 && mounted) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _estimatedSaved = (data['savedAmount'] as num?)?.toInt();
          _referencePrice = (data['referencePrice'] as num?)?.toInt();
          _matchedByMenu = data['matchedByMenu'] == true;
        });
      }
    } catch (e) {
      debugPrint('예상 절약 금액 조회 오류: $e');
    }
  }

  String _formatWon(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// 방문 인증 생성 (POST /api/visits) — 절약 금액은 서버 룰로 계산됨
  Future<void> _submit() async {
    if (!_isLocationVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('매장 50m 이내에서 현재 위치를 확인해주세요.')),
      );
      return;
    }
    final price =
        int.tryParse(_amountController.text.replaceAll(RegExp(r'[^\d]'), '')) ??
        0;
    if (price <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('결제 금액을 입력해주세요.')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      // 기록 직전에 위치를 다시 확인해, 인증 후 이동한 상태로 저장되지 않게 합니다.
      await _checkLocation();
      if (!mounted || !_isLocationVerified) {
        return;
      }
      final response = await http
          .post(
            ApiClient.uri('/api/visits'),
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({
              'storeId': widget.store?.id,
              'storeName': _storeName,
              'industry': widget.store?.industry,
              'menu': _menuController.text.trim(),
              'price': price,
              'verificationMethod': 'LOCATION',
              'verificationDistanceMeters': _distanceMeters!.round(),
              'latitude': _currentLatitude,
              'longitude': _currentLongitude,
              'locationAccuracyMeters': _locationAccuracyMeters,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        context.push(
          AppRoutes.visitVerificationComplete,
          extra: {
            'savedAmount': (data['savedAmount'] as num?)?.toInt() ?? 0,
            'storeName': _storeName,
            'menu': _menuController.text.trim(),
            'price': price,
          },
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요한 기능입니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방문 기록에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('네트워크 오류가 발생했습니다.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSavingsCard() {
    final estimated = _estimatedSaved;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
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
          const SizedBox(height: 10),
          Text(
            estimated == null
                ? '금액 입력 시 자동 계산'
                : '약 ${_formatWon(estimated)}원 절약 예상',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _referencePrice == null
                ? '한국소비자원 참가격 기준으로 자동 계산돼요'
                : (_matchedByMenu
                      ? '참가격 기준가 ${_formatWon(_referencePrice!)}원 기준'
                      : '카테고리 평균가 ${_formatWon(_referencePrice!)}원 기준 (참가격 기반)'),
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LocationVerificationException implements Exception {
  const _LocationVerificationException(this.message);

  final String message;
}

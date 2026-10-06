import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:howmuch/features/store/presentation/state/directions_urls.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart'
    as howmuch_home;
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

typedef DirectionsPositionLookup = Future<Position?> Function();

/// A cached fix older than this may be from another neighborhood, which
/// would give the external map a wrong starting point.
const directionsLastKnownMaxAge = Duration(minutes: 2);

@visibleForTesting
bool isFreshLastKnownPosition(Position? position, DateTime now) {
  if (position == null) return false;
  final age = now.toUtc().difference(position.timestamp.toUtc());
  return !age.isNegative && age <= directionsLastKnownMaxAge;
}

class DirectionsExternalAppScreen extends StatefulWidget {
  const DirectionsExternalAppScreen({
    super.key,
    this.storeName = '선택한 매장',
    this.address = '주소 정보 없음',
    this.distanceLabel = '거리 정보 없음',
    this.latitude,
    this.longitude,
    this.startLatitude,
    this.startLongitude,
    this.positionLookup,
    this.startName = '현재 위치',
  });

  final String storeName;
  final String address;
  final String distanceLabel;
  final double? latitude;
  final double? longitude;
  final double? startLatitude;
  final double? startLongitude;
  final DirectionsPositionLookup? positionLookup;
  final String startName;

  @override
  State<DirectionsExternalAppScreen> createState() =>
      _DirectionsExternalAppScreenState();
}

class _DirectionsExternalAppScreenState
    extends State<DirectionsExternalAppScreen> {
  int _selectedTransport = 0;
  double? _resolvedStartLat;
  double? _resolvedStartLng;
  bool _isResolvingStart = false;
  Future<void>? _positionRequest;

  final List<Map<String, dynamic>> _transports = [
    {'icon': Icons.directions_walk, 'label': '도보', 'mode': 'FOOT'},
    {'icon': Icons.directions_bus_rounded, 'label': '대중교통', 'mode': 'PUBLIC'},
    {'icon': Icons.directions_car_rounded, 'label': '자동차', 'mode': 'CAR'},
  ];

  double? get _effectiveStartLat =>
      _resolvedStartLat ??
      widget.startLatitude ??
      howmuch_home.HomeMapScreen.globalUserPosition?.latitude;

  double? get _effectiveStartLng =>
      _resolvedStartLng ??
      widget.startLongitude ??
      howmuch_home.HomeMapScreen.globalUserPosition?.longitude;

  bool get _hasRouteCoordinates =>
      _isValidCoordinate(widget.latitude, widget.longitude) &&
      _isValidCoordinate(_effectiveStartLat, _effectiveStartLng);

  String get _effectiveDistanceLabel {
    if (_hasRouteCoordinates) {
      final meters = Geolocator.distanceBetween(
        _effectiveStartLat!,
        _effectiveStartLng!,
        widget.latitude!,
        widget.longitude!,
      );
      return formatRecommendationDistance(meters);
    }
    if (widget.distanceLabel.isNotEmpty &&
        widget.distanceLabel != '거리 정보 확인 중') {
      return widget.distanceLabel;
    }
    return '거리 정보 없음';
  }

  bool _isValidCoordinate(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude != 0 &&
      longitude != 0 &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  @override
  void initState() {
    super.initState();
    final globalPosition = howmuch_home.HomeMapScreen.globalUserPosition;
    _resolvedStartLat = widget.startLatitude ?? globalPosition?.latitude;
    _resolvedStartLng = widget.startLongitude ?? globalPosition?.longitude;
    if (_isValidCoordinate(widget.latitude, widget.longitude) &&
        !_isValidCoordinate(_effectiveStartLat, _effectiveStartLng)) {
      unawaited(_resolveStartLocation());
    }
  }

  Future<Position?> _loadCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    // Browsers have no last-known position API (geolocator throws there), so
    // the web goes straight to a current fix.
    if (!kIsWeb) {
      try {
        final cached = await Geolocator.getLastKnownPosition();
        if (cached != null &&
            _isValidCoordinate(cached.latitude, cached.longitude) &&
            isFreshLastKnownPosition(cached, DateTime.now())) {
          return cached;
        }
      } catch (error) {
        debugPrint('마지막 위치 조회 실패: $error');
      }
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 8),
    ).timeout(const Duration(seconds: 10));
  }

  Future<void> _resolveStartLocation() {
    final pending = _positionRequest;
    if (pending != null) return pending;

    final request = _resolveStartLocationOnce();
    _positionRequest = request;
    return request.whenComplete(() => _positionRequest = null);
  }

  Future<void> _resolveStartLocationOnce() async {
    if (_isValidCoordinate(_effectiveStartLat, _effectiveStartLng)) return;
    if (mounted) setState(() => _isResolvingStart = true);
    try {
      final position = await (widget.positionLookup ?? _loadCurrentPosition)();
      if (position == null ||
          !_isValidCoordinate(position.latitude, position.longitude)) {
        return;
      }
      _resolvedStartLat = position.latitude;
      _resolvedStartLng = position.longitude;
      howmuch_home.HomeMapScreen.globalUserPosition = position;
    } catch (error) {
      debugPrint('길찾기 출발지 위치 확인 실패: $error');
    } finally {
      if (mounted) setState(() => _isResolvingStart = false);
    }
  }

  Future<void> _ensureStartLocation() async {
    if (_isValidCoordinate(_effectiveStartLat, _effectiveStartLng)) return;
    await _resolveStartLocation();
  }

  Future<void> _launchKakaoMap() => _launchDirections(true);

  Future<void> _launchNaverMap() => _launchDirections(false);

  Future<void> _launchDirections(bool kakao) async {
    // On web, opening a window must stay on the button's activation event.
    // If GPS was not ready, resolve it first and ask for a second activation.
    if (kIsWeb && !_hasRouteCoordinates && !_isResolvingStart) {
      await _ensureStartLocation();
      if (!mounted) return;
      if (_hasRouteCoordinates) {
        ScaffoldMessenger.of(context).showSnackBar(
          HowmuchSnackBar(content: Text('출발지를 확인했어요. 지도 열기 버튼을 다시 눌러주세요.')),
        );
        return;
      }
    } else if (!kIsWeb) {
      await _ensureStartLocation();
    }
    final args = DirectionsTransport.values[_selectedTransport];
    final urls = kakao
        ? buildKakaoDirectionsUrls(
            destinationName: widget.storeName,
            startName: widget.startName,
            transport: args,
            startLatitude: _effectiveStartLat,
            startLongitude: _effectiveStartLng,
            destinationLatitude: widget.latitude,
            destinationLongitude: widget.longitude,
          )
        : buildNaverDirectionsUrls(
            destinationName: widget.storeName,
            startName: widget.startName,
            transport: args,
            startLatitude: _effectiveStartLat,
            startLongitude: _effectiveStartLng,
            destinationLatitude: widget.latitude,
            destinationLongitude: widget.longitude,
          );
    try {
      bool opened;
      if (kIsWeb) {
        opened = await launchUrl(
          urls.web,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        opened = false;
        try {
          if (await canLaunchUrl(urls.native)) {
            opened = await launchUrl(urls.native);
          }
        } catch (_) {
          // An installed but unavailable map app must still allow web routes.
        }
        if (!opened) {
          if (!kakao && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              HowmuchSnackBar(
                content: Text('네이버 지도 앱을 설치해 이용할 수도 있어요. 설치 없이 웹 지도로 연결합니다.'),
              ),
            );
          }
          opened = await launchUrl(
            urls.web,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          HowmuchSnackBar(
            content: Text('지도를 열지 못했어요. 브라우저 팝업 설정을 확인하고 다시 눌러주세요.'),
          ),
        );
      } else if (!_hasRouteCoordinates) {
        ScaffoldMessenger.of(context).showSnackBar(
          HowmuchSnackBar(
            content: Text('현재 위치를 확인하지 못했어요. 외부 지도에서 출발지와 이동 방식을 선택해주세요.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          HowmuchSnackBar(content: Text('지도를 열지 못했어요. 연결 상태를 확인하고 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: const CustomAppBar(title: '길찾기'),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreCard(),
                const SizedBox(height: 24),
                const Text(
                  '이동 방식',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildTransportOptions(),
                const SizedBox(height: 24),
                const Text(
                  '외부 앱으로 열기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildAppButton(
                  badge: 'N',
                  color: AppColors.naverGreen,
                  label: '네이버지도에서 열기',
                  textColor: AppColors.white,
                  onTap: _launchNaverMap,
                ),
                const SizedBox(height: 10),
                _buildAppButton(
                  badge: 'K',
                  color: AppColors.kakaoYellow,
                  label: '카카오맵에서 열기',
                  textColor: Colors.black87,
                  onTap: _launchKakaoMap,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '외부 지도 앱으로 이동해 경로를 확인할 수 있어요.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '길찾기 시작',
          backgroundColor: AppColors.primary,
          onPressed: _launchKakaoMap,
        ),
      ),
    );
  }

  Widget _buildStoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.address,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _effectiveDistanceLabel,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      _hasRouteCoordinates
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      size: 13,
                      color: _hasRouteCoordinates
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _isResolvingStart
                            ? '출발지 · 현재 위치 확인 중'
                            : _hasRouteCoordinates
                            ? '출발지 · ${widget.startName}'
                            : '출발지 · 지도 앱에서 선택',
                        style: TextStyle(
                          color: _hasRouteCoordinates
                              ? AppColors.primary
                              : AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportOptions() {
    return Row(
      children: List.generate(_transports.length, (i) {
        final selected = _selectedTransport == i;
        return Expanded(
          child: Semantics(
            label: '${_transports[i]['label']} 이동 방식',
            selected: selected,
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTransport = i),
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(
                    right: i < _transports.length - 1 ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primarySubtle : AppColors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _transports[i]['icon'] as IconData,
                        color: selected
                            ? AppColors.primary
                            : Colors.grey.shade500,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _transports[i]['label'] as String,
                        style: TextStyle(
                          color: selected ? AppColors.primary : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '지도 앱에서 확인',
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAppButton({
    required String badge,
    required Color color,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

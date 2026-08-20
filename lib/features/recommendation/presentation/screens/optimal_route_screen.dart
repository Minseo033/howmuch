import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/recommendation/presentation/state/route_geometry.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_point.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_view.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_step_card.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:geolocator/geolocator.dart';

class OptimalRouteScreen extends ConsumerStatefulWidget {
  const OptimalRouteScreen({super.key});

  @override
  ConsumerState<OptimalRouteScreen> createState() => _OptimalRouteScreenState();
}

class _OptimalRouteScreenState extends ConsumerState<OptimalRouteScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _routeData;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(todaysPickServiceProvider);
      final position = await _resolveCurrentPosition();
      _userLatitude = position?.latitude;
      _userLongitude = position?.longitude;
      final data = await service.getRoute(
        lat: _userLatitude,
        lng: _userLongitude,
      );
      if (!mounted) return;
      if (data['error'] == true) {
        setState(() {
          _errorMessage = '루트를 불러오지 못했어요.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _routeData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '네트워크 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _picks => _routeData?['picks'] ?? [];

  List<RouteMapPoint> get _routeMapPoints {
    final points = <RouteMapPoint>[];
    for (var index = 0; index < _picks.length; index++) {
      final pick = _picks[index];
      if (pick is! Map) continue;
      final coordinates = _coordinates(pick);
      if (coordinates == null) continue;
      points.add(
        RouteMapPoint(
          order: index + 1,
          name: pick['storeName']?.toString() ?? '알 수 없음',
          latitude: coordinates.lat,
          longitude: coordinates.lng,
        ),
      );
    }
    return points;
  }

  int get _totalCost {
    int sum = 0;
    for (var p in _picks) {
      final parsed = parseRecommendationPrice(p['price1']);
      if (parsed != null) sum += parsed;
    }
    return sum;
  }

  int get _totalDistance {
    return _picks.asMap().entries.fold<int>(0, (sum, entry) {
      final leg = _legDistanceMeters(entry.key);
      return sum + (leg?.round() ?? 0);
    });
  }

  String get _totalDistanceLabel {
    if (_picks.isEmpty ||
        _picks.asMap().keys.every((i) => _legDistanceMeters(i) == null)) {
      return '거리 정보 없음';
    }
    return formatRecommendationDistance(_totalDistance.toDouble());
  }

  Future<Position?> _resolveCurrentPosition() async {
    final cached = HomeMapScreen.globalUserPosition;
    if (cached != null) return cached;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );
    } catch (_) {
      return null;
    }
  }

  double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  RouteCoordinate? _coordinates(Object? raw) => parseRouteCoordinate(raw);

  double? _legDistanceMeters(int index) {
    if (index < 0 || index >= _picks.length) return null;
    if (_userLatitude == null || _userLongitude == null) {
      return _number(_picks[index]['distanceMeters']);
    }
    final current = _coordinates(_picks[index]);
    if (current == null) return _number(_picks[index]['distanceMeters']);

    final previous = index == 0
        ? (_userLatitude != null && _userLongitude != null
              ? (lat: _userLatitude!, lng: _userLongitude!)
              : null)
        : _coordinates(_picks[index - 1]);
    if (previous == null) {
      return index == 0 ? _number(_picks[index]['distanceMeters']) : null;
    }

    return routeDistanceMeters(previous, current);
  }

  String _distanceText(Object? value) {
    return formatRecommendationDistance(_number(value));
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top: topOffset + 11.98876953125,
                bottom: 12,
                left: 8,
                right: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      '추천 루트',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: topOffset + 50.96590805053711,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFF64748B),
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '추천 경로를 불러오지 못했어요',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 140,
                            height: 40,
                            child: FilledButton(
                              onPressed: _loadRoute,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '다시 시도',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _picks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.alt_route_rounded,
                              color: Color(0xFF64748B),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '추천 동선 매장이 없어요',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '근처에 연속 탐방할 수 있는 착한가격업소가 부족하거나 위치 권한이 켜져 있지 않아요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 100 + bottomOffset),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '식사부터 카페까지 저렴한 동선을 추천해요',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final mapHeight = (constraints.maxWidth / 1.58)
                                  .clamp(180.0, 212.0)
                                  .toDouble();
                              return SizedBox(
                                height: mapHeight,
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EEF6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: _routeMapPoints.isEmpty
                                      ? const _RouteMapUnavailable()
                                      : RouteMapView(
                                          points: _routeMapPoints,
                                          userLatitude: _userLatitude,
                                          userLongitude: _userLongitude,
                                        ),
                                ),
                              );
                            },
                          ),
                          if (_routeMapPoints.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildRouteLegend(),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            '추천 동선',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_picks.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('추천할 매장이 없어요.')),
                            )
                          else
                            ..._picks.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final p = entry.value;
                              final storeName = p['storeName'] ?? '알 수 없음';
                              final menu = p['menu1'] ?? '';
                              final price = formatRecommendationPrice(
                                p['price1'],
                                unavailable: '',
                              );
                              final distance = _distanceText(
                                p['distanceMeters'],
                              );
                              final legDistance = _legDistanceMeters(idx);

                              return Column(
                                children: [
                                  RouteStepCard(
                                    index: '${idx + 1}',
                                    storeName: storeName,
                                    details: [menu, price, distance]
                                        .where((part) => part.isNotEmpty)
                                        .join(' · '),
                                  ),
                                  if (idx < _picks.length - 1 &&
                                      legDistance != null)
                                    _buildConnection(
                                      '도보 약 ${math.max(1, (legDistance / 80).round())}분',
                                    ),
                                ],
                              );
                            }),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '총 예상 비용',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      formatRecommendationPrice(_totalCost),
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '총 거리',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _totalDistanceLabel,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 1,
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 12),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Color(0xFF64748B),
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'AI 추천 동선',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_routeData?['route'] != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AI 추천 이유',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _routeData!['route'].toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          if (!_isLoading && _errorMessage == null && _picks.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: 16 + bottomOffset,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: GestureDetector(
                  onTap: () {
                    final firstPick = _picks.isNotEmpty && _picks.first is Map
                        ? _picks.first as Map
                        : const {};
                    final firstCoordinates = _coordinates(firstPick);
                    context.push(
                      AppRoutes.directionsExternalApp,
                      extra: {
                        'storeName':
                            firstPick['storeName']?.toString() ?? '선택한 매장',
                        'address':
                            firstPick['address']?.toString() ?? '주소 정보 없음',
                        'distanceLabel': _distanceText(
                          firstPick['distanceMeters'],
                        ),
                        'latitude': firstCoordinates?.lat,
                        'longitude': firstCoordinates?.lng,
                        'startLatitude': _userLatitude,
                        'startLongitude': _userLongitude,
                      },
                    );
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '이 루트로 길찾기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteLegend() {
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              '순서',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            ..._routeMapPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${point.order}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        point.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildConnection(String timeText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.more_vert, color: Color(0xFFE5E7EB), size: 20),
          const SizedBox(width: 12),
          Text(
            timeText,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RouteMapUnavailable extends StatelessWidget {
  const _RouteMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, color: Color(0xFF64748B)),
            SizedBox(height: 8),
            Text(
              '매장 좌표가 없어 지도를 표시할 수 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF475569), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

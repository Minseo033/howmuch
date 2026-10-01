import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';
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
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/recommendation_radius_button.dart';

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
  int _loadGeneration = 0;
  int _loadedRadiusMeters = defaultRecommendationRadiusMeters;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(recommendationRadiusProvider.notifier).ready;
      if (!mounted || generation != _loadGeneration) return;
      _loadedRadiusMeters = ref.read(recommendationRadiusProvider);
      final service = ref.read(todaysPickServiceProvider);
      final position = await _resolveCurrentPosition();
      if (position == null) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _errorMessage = '추천 루트를 만들려면 위치 권한을 허용해주세요.';
          _isLoading = false;
        });
        return;
      }
      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
      final data = await service.getRoute(
        lat: _userLatitude,
        lng: _userLongitude,
        radiusMeters: _loadedRadiusMeters,
      );
      if (!mounted || generation != _loadGeneration) return;
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
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _errorMessage = '네트워크 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _picks {
    final rawPicks = _routeData?['picks'];
    if (rawPicks is! List) return const [];
    return rawPicks
        .whereType<Map>()
        .map((pick) => Map<String, dynamic>.from(pick))
        .where((pick) {
          final coordinates = _coordinates(pick);
          final distance =
              _number(pick['distanceMeters']) ??
              (_userLatitude != null &&
                      _userLongitude != null &&
                      coordinates != null
                  ? routeDistanceMeters((
                      lat: _userLatitude!,
                      lng: _userLongitude!,
                    ), coordinates)
                  : null);
          return pick['isClosed'] != true &&
              distance != null &&
              distance.isFinite &&
              distance >= 0 &&
              distance <= _loadedRadiusMeters;
        })
        .toList(growable: false);
  }

  List<RouteMapPoint> get _routeMapPoints {
    final points = <RouteMapPoint>[];
    for (var index = 0; index < _picks.length; index++) {
      final pick = _picks[index];
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

  String get _totalCostLabel => formatRecommendationTotal(_picks);

  int? get _totalDistance {
    int sum = 0;
    bool hasAny = false;
    for (int i = 0; i < _picks.length; i++) {
      final leg = _legDistanceMeters(i);
      if (leg != null && leg.isFinite && leg >= 0) {
        sum += leg.round();
        hasAny = true;
      }
    }
    return hasAny ? sum : null;
  }

  String get _totalDistanceLabel {
    final total = _totalDistance;
    if (total == null || _picks.isEmpty) {
      return '거리 정보 없음';
    }
    return formatRecommendationDistance(total.toDouble());
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
    if (index == 0) {
      final first = _coordinates(_picks[0]);
      if (_userLatitude != null && _userLongitude != null && first != null) {
        return routeDistanceMeters((
          lat: _userLatitude!,
          lng: _userLongitude!,
        ), first);
      }
      return _number(_picks[index]['distanceMeters']);
    }

    final previous = _coordinates(_picks[index - 1]);
    final current = _coordinates(_picks[index]);
    if (previous != null && current != null) {
      return routeDistanceMeters(previous, current);
    }
    return null;
  }

  String _distanceText(Object? value) {
    return formatRecommendationDistance(_number(value));
  }

  String _formatLegDuration(double? legDistance) {
    if (legDistance == null || !legDistance.isFinite || legDistance < 0) {
      return '이동';
    }
    if (legDistance <= 1500) {
      final walkMinutes = math.max(1, (legDistance / 80).round());
      return '도보 약 $walkMinutes분';
    }
    return '대중교통/차량 이동 (${formatRecommendationDistance(legDistance)})';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(recommendationRadiusProvider, (previous, next) {
      if (previous != null && previous != next) _loadRoute();
    });
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: topOffset + HowmuchTopBar.height,
              child: Padding(
                padding: EdgeInsets.only(top: topOffset),
                child: HowmuchTopBar(
                  title: '추천 루트',
                  onBack: () => context.pop(),
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: topOffset + HowmuchTopBar.height,
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
                          const RecommendationRadiusButton(),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5E7EB),
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
                              fontFamily: 'Noto Sans KR',
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
                              fontFamily: 'Noto Sans KR',
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
                                  borderRadius: BorderRadius.circular(16),
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
                              color: Color(0xFFE5E7EB),
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
                              fontFamily: 'Noto Sans KR',
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
                              fontFamily: 'Noto Sans KR',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const RecommendationRadiusButton(),
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
                          const RecommendationRadiusButton(),
                          const SizedBox(height: 12),
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
                                    color: const Color(0xFFEFF4FF),
                                    borderRadius: BorderRadius.circular(22),
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
                              final matchedMenu =
                                  p['matchedMenu']?.toString().trim() ?? '';
                              final menu = matchedMenu.isNotEmpty
                                  ? matchedMenu
                                  : p['menu1']?.toString() ?? '';
                              final price = formatRecommendationPrice(
                                recommendationMenuPrice(p),
                                unavailable: '',
                                free: recommendationMenuFree(p),
                              );
                              final distance = _distanceText(
                                p['distanceMeters'],
                              );
                              final nextLegDistance = idx < _picks.length - 1
                                  ? _legDistanceMeters(idx + 1)
                                  : null;

                              return Column(
                                children: [
                                  RouteStepCard(
                                    index: '${idx + 1}',
                                    storeName: storeName,
                                    details: [menu, price, distance]
                                        .where((part) => part.isNotEmpty)
                                        .join(' · '),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _canOpenLeg(idx)
                                          ? () => _openLeg(idx)
                                          : null,
                                      icon: const Icon(
                                        Icons.directions_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        '${idx + 1}구간: ${_legStartName(idx)} → $storeName',
                                      ),
                                    ),
                                  ),
                                  if (idx < _picks.length - 1)
                                    _buildConnection(
                                      _formatLegDuration(nextLegDistance),
                                    ),
                                ],
                              );
                            }),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '총 예상 비용',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      flex: 2,
                                      child: Text(
                                        _totalCostLabel,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
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
                                borderRadius: BorderRadius.circular(22),
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
                                      color: Color(0xFF374151),
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
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _showRouteLegs,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '구간별 길찾기',
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
                          color: Color(0xFF374151),
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

  String _legStartName(int index) => index == 0
      ? '현재 위치'
      : _picks[index - 1]['storeName']?.toString() ?? '이전 매장';

  RouteCoordinate? _legStart(int index) => index == 0
      ? (_userLatitude != null && _userLongitude != null
            ? (lat: _userLatitude!, lng: _userLongitude!)
            : null)
      : _coordinates(_picks[index - 1]);

  bool _canOpenLeg(int index) =>
      index >= 0 &&
      index < _picks.length &&
      _legStart(index) != null &&
      _coordinates(_picks[index]) != null;

  void _openLeg(int index) {
    if (!_canOpenLeg(index)) return;
    final pick = _picks[index];
    final destination = _coordinates(pick)!;
    final start = _legStart(index)!;
    context.push(
      AppRoutes.directionsExternalApp,
      extra: {
        'storeName': pick['storeName']?.toString() ?? '선택한 매장',
        'address': pick['address']?.toString() ?? '주소 정보 없음',
        'distanceLabel': formatRecommendationDistance(
          _legDistanceMeters(index),
        ),
        'latitude': destination.lat,
        'longitude': destination.lng,
        'startLatitude': start.lat,
        'startLongitude': start.lng,
        'startName': _legStartName(index),
      },
    );
  }

  Future<void> _showRouteLegs() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '구간별 길찾기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text('순서대로 이동할 구간을 선택하세요. 지도에서 돌아와도 방문 완료로 처리하지 않아요.'),
              ),
              for (var i = 0; i < _picks.length; i++)
                ListTile(
                  enabled: _canOpenLeg(i),
                  leading: Text('${i + 1}구간'),
                  title: Text(
                    '${_legStartName(i)} → ${_picks[i]['storeName']}',
                  ),
                  subtitle: Text(
                    _canOpenLeg(i)
                        ? formatRecommendationDistance(_legDistanceMeters(i))
                        : '위치 정보가 없어 이 구간을 열 수 없어요.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && index != null) _openLeg(index);
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
              style: TextStyle(color: Color(0xFF374151), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

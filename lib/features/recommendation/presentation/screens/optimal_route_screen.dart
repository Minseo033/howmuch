import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/keep_all_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_failure.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/recommendation/presentation/state/route_geometry.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_point.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_view.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_step_card.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/recommendation_radius_button.dart';

/// The server's deterministic route (Gemini disabled or failed) starts with
/// this sentence. Such a route must not be labelled as an AI recommendation.
const localRouteTextPrefix = '현재는 거리순으로';

/// The server orders the route so the walk from the current location through
/// every stop is as short as possible (FE-STORE-13). That is not the same as
/// sorting the stops by their distance from the current location.
const routeOrderLabel = '총 이동 거리가 짧도록 정한 동선';

/// A subtitle that matches the stops the route actually has (QA #25).
String routeSubtitleFor(Iterable<Map<String, dynamic>> picks) {
  var meals = 0;
  var desserts = 0;
  for (final pick in picks) {
    if (isDessertRecommendation(pick)) {
      desserts++;
    } else {
      meals++;
    }
  }
  if (meals > 0 && desserts > 0) return '식사부터 카페까지 저렴한 동선을 추천해요';
  if (desserts > 0) return '저렴한 카페·디저트 $desserts곳을 들르는 동선을 추천해요';
  return '저렴한 음식점 $meals곳을 들르는 동선을 추천해요';
}

/// The guide for a route that AI did not write.
///
/// The server's text lists the stops by distance from the current location,
/// while the cards and map numbers follow the route order of `picks`. The
/// guide is built from the same stops in the same order, with the menu and
/// price format of the cards (QA #6, #27).
String buildRouteGuideText(List<Map<String, dynamic>> picks) {
  final lines = ['현재 위치에서 출발해 총 이동 거리가 짧도록 정한 순서예요.'];
  for (var index = 0; index < picks.length; index++) {
    final selection = RecommendationMenuSelection.fromPick(picks[index]);
    final name = selection.storeName.isEmpty ? '알 수 없음' : selection.storeName;
    final menu = selection.menu.isEmpty ? '메뉴 정보 없음' : selection.menu;
    final price = formatRecommendationPrice(
      selection.price,
      free: selection.free,
    );
    lines.add('${index + 1}. $name ($menu, $price)');
  }
  return lines.join('\n');
}

class OptimalRouteScreen extends ConsumerStatefulWidget {
  const OptimalRouteScreen({super.key});

  @override
  ConsumerState<OptimalRouteScreen> createState() => _OptimalRouteScreenState();
}

class _OptimalRouteScreenState extends ConsumerState<OptimalRouteScreen> {
  bool _isLoading = true;
  RecommendationFailure? _failure;
  String? _failureServerMessage;
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
      _failure = null;
      _failureServerMessage = null;
    });

    try {
      await ref.read(recommendationRadiusProvider.notifier).ready;
      if (!mounted || generation != _loadGeneration) return;
      _loadedRadiusMeters = ref.read(recommendationRadiusProvider);
      final service = ref.read(todaysPickServiceProvider);
      final position = await _resolveCurrentPosition();
      if (position == null) {
        if (!mounted || generation != _loadGeneration) return;
        _showFailure(RecommendationFailure.location);
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
        _showFailure(
          recommendationFailureOf(data),
          serverMessage: data['message']?.toString(),
        );
        return;
      }
      setState(() {
        _routeData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      _showFailure(RecommendationFailure.unknown);
    }
  }

  void _showFailure(RecommendationFailure failure, {String? serverMessage}) {
    setState(() {
      _failure = failure;
      _failureServerMessage = serverMessage;
      _isLoading = false;
    });
  }

  bool get _isAiRoute {
    final route = _routeData?['route']?.toString().trim() ?? '';
    return route.isNotEmpty && !route.startsWith(localRouteTextPrefix);
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
      // Some browsers ignore timeLimit, so keep an outer bound as well.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      ).timeout(const Duration(seconds: 4));
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

  static const _legUnavailableText = '위치 정보가 없어 이 구간을 열 수 없어요.';

  /// Distance of the leg that ends at stop [index], and whether it is a walk:
  /// up to 1.5km on foot, otherwise by transit or car.
  ({double meters, bool walk})? _legTravel(int index) {
    final meters = _legDistanceMeters(index);
    if (meters == null || !meters.isFinite || meters < 0) return null;
    return (meters: meters, walk: meters <= 1500);
  }

  /// Travel time of the leg that ends at stop [index]: from the current
  /// location for the first stop, otherwise from the previous stop.
  String? _legTimeText(int index) {
    final travel = _legTravel(index);
    if (travel == null) return null;
    if (travel.walk) {
      final walkMinutes = math.max(1, (travel.meters / 80).round());
      return '도보 약 $walkMinutes분';
    }
    return '대중교통/차량 이동 (${formatRecommendationDistance(travel.meters)})';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(recommendationRadiusProvider, (previous, next) {
      if (previous != null && previous != next) _loadRoute();
    });
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final failure = _failure;
    final failureCopy = failure == null
        ? null
        : recommendationFailureCopy(
            failure,
            route: true,
            serverMessage: _failureServerMessage,
          );

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
                : failureCopy != null
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
                            child: Icon(
                              failure == RecommendationFailure.location
                                  ? Icons.location_off_outlined
                                  : Icons.error_outline_rounded,
                              color: const Color(0xFF64748B),
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            failureCopy.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Noto Sans KR',
                              fontFamilyFallback: ['Noto Sans KR'],
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            failureCopy.message,
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
                          Text(
                            routeSubtitleFor(_picks),
                            style: const TextStyle(
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
                              final storeName =
                                  p['storeName']?.toString() ?? '알 수 없음';
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
                              final canOpenLeg = _canOpenLeg(idx);

                              return Column(
                                children: [
                                  _RouteStopWithLeg(
                                    stop: RouteStepCard(
                                      index: '${idx + 1}',
                                      storeName: storeName,
                                      details: [menu, price, distance]
                                          .where((part) => part.isNotEmpty)
                                          .join(' · '),
                                    ),
                                    leg: _RouteLegButton(
                                      key: ValueKey('route-leg-${idx + 1}'),
                                      label:
                                          '${idx + 1}구간: ${_legStartName(idx)} → $storeName',
                                      // Each leg shows its own travel time.
                                      // It used to sit under the previous
                                      // leg's button (QA #24).
                                      detail: canOpenLeg
                                          ? _legTimeText(idx)
                                          : _legUnavailableText,
                                      onPressed: canOpenLeg
                                          ? () => _openLeg(idx)
                                          : null,
                                    ),
                                  ),
                                  if (idx < _picks.length - 1)
                                    _buildConnection(),
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
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_walk,
                                      color: Color(0xFF64748B),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isAiRoute ? 'AI 추천 동선' : routeOrderLabel,
                                      style: const TextStyle(
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
                                  Text(
                                    _isAiRoute ? 'AI 추천 이유' : '동선 안내',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isAiRoute
                                        ? _routeData!['route'].toString()
                                        : buildRouteGuideText(_picks),
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
          if (!_isLoading && _failure == null && _picks.isNotEmpty)
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
    final legs = [for (var i = 0; i < _picks.length; i++) _legSummary(i)];
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Same 430 column as the radius sheet on a wide browser window.
      constraints: const BoxConstraints(
        maxWidth: FigmaMobileCanvas.maxWebWidth,
      ),
      builder: (sheetContext) => _RouteLegsSheet(
        legs: legs,
        onSelected: (leg) => Navigator.pop(sheetContext, leg),
      ),
    );
    if (mounted && index != null) _openLeg(index);
  }

  _RouteLeg _legSummary(int index) {
    final travel = _legTravel(index);
    final time = _legTimeText(index);
    return _RouteLeg(
      index: index,
      from: _legStartName(index),
      to: _picks[index]['storeName']?.toString() ?? '알 수 없음',
      canOpen: _canOpenLeg(index),
      walk: travel?.walk ?? true,
      // A far leg already names its distance.
      travel: travel == null
          ? null
          : travel.walk
          ? '$time · ${formatRecommendationDistance(travel.meters)}'
          : time,
    );
  }

  Widget _buildConnection() {
    return const Padding(
      // Lines the dots up under the stop numbers.
      padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [Icon(Icons.more_vert, color: Color(0xFFE5E7EB), size: 20)],
      ),
    );
  }
}

/// A stop card with the button for the leg that ends at it, so each leg
/// reads as the way to that stop.
class _RouteStopWithLeg extends StatelessWidget {
  const _RouteStopWithLeg({required this.stop, required this.leg});

  final Widget stop;
  final Widget leg;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [stop, leg],
      ),
    );
  }
}

/// Opens directions for one leg: the leg in brand blue with its travel time
/// under it, across the whole width of the stop card.
class _RouteLegButton extends StatelessWidget {
  const _RouteLegButton({
    super.key,
    required this.label,
    this.detail,
    this.onPressed,
  });

  final String label;
  final String? detail;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? AppColors.primary : AppColors.muted;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minimumTouchTarget,
            ),
            child: Padding(
              // Lines the icon up under the stop number and the label under
              // the store name of the card above.
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.directions_rounded, size: 20, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KeepAllText(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                        if (detail case final detail?) ...[
                          const SizedBox(height: 1),
                          Text(
                            detail,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One leg of the route as the leg sheet lists it.
class _RouteLeg {
  const _RouteLeg({
    required this.index,
    required this.from,
    required this.to,
    required this.canOpen,
    required this.walk,
    this.travel,
  });

  final int index;
  final String from;
  final String to;
  final bool canOpen;
  final bool walk;

  /// Time and distance, such as '도보 약 2분 · 167m'.
  final String? travel;

  int get number => index + 1;

  String? get detail =>
      canOpen ? travel : _OptimalRouteScreenState._legUnavailableText;

  String get semanticsLabel => [
    '$number구간',
    '$from에서 $to까지',
    ?detail?.replaceAll(' · ', ', '),
  ].join(', ');
}

/// Lists every leg as a numbered card. Picking one closes the sheet with its
/// index; closing the sheet any other way picks nothing.
class _RouteLegsSheet extends StatelessWidget {
  const _RouteLegsSheet({required this.legs, required this.onSelected});

  final List<_RouteLeg> legs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('route-legs-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.overlay),
        ),
      ),
      child: SafeArea(
        top: false,
        // Scrolls when there are many legs or the text is large.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RouteSheetHandle(),
              const SizedBox(height: 14),
              const Text(
                '구간별 길찾기',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const KeepAllText(
                '순서대로 이동할 구간을 선택하세요. 지도에서 돌아와도 방문 완료로 처리하지 않아요.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              for (final leg in legs) ...[
                if (leg.index > 0) const SizedBox(height: 10),
                _RouteLegCard(leg: leg, onTap: () => onSelected(leg.index)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSheetHandle extends StatelessWidget {
  const _RouteSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.disabled,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A leg in the sheet, laid out like the stop cards on the screen: the stop
/// number, where the leg ends, where it starts, and how long it takes.
class _RouteLegCard extends StatelessWidget {
  const _RouteLegCard({required this.leg, required this.onTap});

  final _RouteLeg leg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = leg.canOpen;
    final detail = leg.detail;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: leg.semanticsLabel,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: Material(
        key: ValueKey('route-leg-sheet-${leg.number}'),
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                _RouteLegNumber(number: leg.number, enabled: enabled),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KeepAllText(
                        leg.to,
                        style: TextStyle(
                          color: enabled ? AppColors.ink : AppColors.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      KeepAllText(
                        '${leg.from}에서 출발',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 8),
                        _RouteLegTravel(
                          icon: !enabled
                              ? Icons.location_off_outlined
                              : leg.walk
                              ? Icons.directions_walk_rounded
                              : Icons.commute_rounded,
                          text: detail,
                          enabled: enabled,
                        ),
                      ],
                    ],
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteLegNumber extends StatelessWidget {
  const _RouteLegNumber({required this.number, required this.enabled});

  final int number;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: enabled ? AppColors.primary : AppColors.disabled,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        // The number repeats the card's spoken label; past the chrome cap it
        // would no longer fit the circle.
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: AppTextScale.compactChrome),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// How the leg is travelled, with an icon that stays on the first line.
class _RouteLegTravel extends StatelessWidget {
  const _RouteLegTravel({
    required this.icon,
    required this.text,
    required this.enabled,
  });

  static const _fontSize = 12.0;
  static const _lineHeight = 1.45;

  final IconData icon;
  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final iconSize = textScaler
        .clamp(maxScaleFactor: AppTextScale.compactChrome)
        .scale(15);
    final firstLine = textScaler.scale(_fontSize) * _lineHeight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: math.max(0, (firstLine - iconSize) / 2),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? AppColors.primary : AppColors.muted,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: enabled ? AppColors.textBody : AppColors.muted,
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              height: _lineHeight,
            ),
          ),
        ),
      ],
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

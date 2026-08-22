import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_distance.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_weather.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:geolocator/geolocator.dart';

class TodaysPickItem {
  final String id;
  final String storeName;
  final String menuName;
  final String price;
  final String tipText;
  final String distance;
  final double? distanceMeters;
  final int? priceValue;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final List<String> tags;
  final String? theme;
  final String? reason;
  final Store? store;

  TodaysPickItem({
    required this.id,
    required this.storeName,
    required this.menuName,
    required this.price,
    required this.tipText,
    required this.distance,
    this.distanceMeters,
    this.priceValue,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.tags,
    this.theme,
    this.reason,
    this.store,
  });
}

class TodaysPickScreen extends ConsumerStatefulWidget {
  const TodaysPickScreen({super.key});

  @override
  ConsumerState<TodaysPickScreen> createState() => _TodaysPickScreenState();
}

class _TodaysPickScreenState extends ConsumerState<TodaysPickScreen> {
  String _selectedFilter = '날씨 기반';
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _pickData;

  @override
  void initState() {
    super.initState();
    _loadTodaysPick();
  }

  Future<void> _loadTodaysPick() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(todaysPickServiceProvider);
      // 지도에서 이미 확보한 위치가 있으면 그대로 사용, 없으면 geolocator로 조회
      double? lat;
      double? lng;
      if (HomeMapScreen.globalUserPosition != null) {
        lat = HomeMapScreen.globalUserPosition!.latitude;
        lng = HomeMapScreen.globalUserPosition!.longitude;
      } else {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 3),
          ).timeout(const Duration(seconds: 4));
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {
          // 위치 조회 실패 시 null로 두고 서버에서 서울 기본 격자 사용
        }
      }
      final data = await service.getTodaysPick(lat: lat, lng: lng);
      if (!mounted) return;
      if (data['error'] == true) {
        final fallback = buildLocalTodaysPickData(
          stores: HomeMapScreen.globalAllStores,
          lat: lat,
          lng: lng,
        );
        if ((fallback['picks'] as List).isNotEmpty) {
          setState(() {
            _pickData = fallback;
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _errorMessage = '오늘의 픽을 불러오지 못했어요.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _pickData = data;
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

  List<TodaysPickItem> _buildItems() {
    if (_pickData == null || _pickData!['picks'] == null) return [];
    final List<dynamic> picks = _pickData!['picks'];
    final weather = _pickData!['weather'] ?? '알 수 없음';
    final temp = _pickData!['temp'];

    return picks.asMap().entries.map((entry) {
      final idx = entry.key;
      final p = entry.value;
      final store = p is Map
          ? Store.fromJson(Map<String, dynamic>.from(p))
          : null;
      final distanceValue = p['distanceMeters'];
      final distanceNumber = _asDouble(distanceValue);
      final distance = formatRecommendationDistance(distanceNumber);
      // 백엔드가 낸 reason(이유 멘트)이 있으면 그걸 우선 사용, 없으면 기존 날씨 문구 폼백
      final backendReason = p['reason'] as String?;
      final backendTheme = p['theme'] as String?;
      final backendMenu = p['matchedMenu'] as String?;
      final temperature = _asDouble(temp);
      final tip = backendReason != null && backendReason.isNotEmpty
          ? backendReason
          : (weather == '비' ||
                    weather == '비/눈' ||
                    weather == '눈' ||
                    weather == '소나기'
                ? '☔ 비 오는 날 추천'
                : (temperature != null && temperature >= 28
                      ? '🌡️ 더운 날 시원한 메뉴'
                      : '✨ 오늘의 추천'));

      return TodaysPickItem(
        id: '${idx + 1}',
        storeName: p['storeName'] ?? '알 수 없음',
        menuName: backendMenu != null && backendMenu.isNotEmpty
            ? backendMenu
            : (p['menu1'] ?? '메뉴 정보 없음'),
        price: formatRecommendationPrice(p['price1']),
        tipText: tip,
        distance: distance,
        distanceMeters: distanceNumber,
        priceValue: parseRecommendationPrice(p['price1']),
        badgeText: '착한가격업소',
        badgeColor: const Color(0xFF2563EB),
        badgeBg: const Color(0xFFEFF4FF),
        tags: const ['날씨 기반'],
        theme: backendTheme,
        reason: backendReason,
        store: store,
      );
    }).toList();
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '') ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;

    final items = _buildItems();
    final filteredItems = [...items];
    if (_selectedFilter == '가까운 거리') {
      filteredItems.sort(
        (a, b) => (a.distanceMeters ?? double.infinity).compareTo(
          b.distanceMeters ?? double.infinity,
        ),
      );
    } else if (_selectedFilter == '저렴한 가격') {
      filteredItems.sort(
        (a, b) => (a.priceValue ?? double.maxFinite).compareTo(
          b.priceValue ?? double.maxFinite,
        ),
      );
    }

    final weather = _pickData?['weather'] ?? '알 수 없음';
    final temp = _pickData?['temp'];
    final forecastTime = formatForecastTime(_pickData?['fcstTime']);
    final now = DateTime.now();
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          Positioned.fill(child: const ColoredBox(color: Color(0xFFF4F6FA))),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
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
                          '오늘의 픽',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Color(0xFF0A0A0A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
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
                                  '오늘의 픽을 불러오지 못했어요',
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
                                    onPressed: _loadTodaysPick,
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
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.only(
                            top: 16,
                            bottom: safePadding.bottom + 20,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF3B82F6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dateStr,
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontFamilyFallback: const [
                                                      'Noto Sans KR',
                                                    ],
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  weather == '비' ||
                                                          weather == '비/눈' ||
                                                          weather == '눈' ||
                                                          weather == '소나기'
                                                      ? '비가 오는 날이네요 ☔️'
                                                      : (temp != null &&
                                                                temp >= 28
                                                            ? '더운 날이네요 🌡️'
                                                            : '오늘의 날씨예요'),
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontFamilyFallback: [
                                                      'Noto Sans KR',
                                                    ],
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                temp != null ? '$temp°' : '-°',
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w300,
                                                  height: 1.0,
                                                ),
                                              ),
                                              if (forecastTime.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  forecastTime,
                                                  style: TextStyle(
                                                    fontFamily: 'Noto Sans KR',
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          weather == '비' ||
                                                  weather == '비/눈' ||
                                                  weather == '눈' ||
                                                  weather == '소나기'
                                              ? '🍜 따뜻한 국물 메뉴를 추천해요'
                                              : (temp != null && temp >= 28
                                                    ? '🧊 시원한 메뉴를 추천해요'
                                                    : '✨ 오늘의 추천 메뉴'),
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontFamilyFallback: [
                                              'Noto Sans KR',
                                            ],
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildFilterChip(
                                      '날씨 기반',
                                      const Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildFilterChip(
                                      '가까운 거리',
                                      const Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildFilterChip(
                                      '저렴한 가격',
                                      const Color(0xFFF97316),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (filteredItems.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE2E8F0),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.lightbulb_outline_rounded,
                                              color: Color(0xFF64748B),
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            '오늘 추천할 매장이 없어요',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontFamilyFallback: [
                                                'Noto Sans KR',
                                              ],
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            '선택하신 필터에 부합하는 매장이 없거나 주변 착한가격업소 데이터가 충분하지 않아요.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontFamilyFallback: [
                                                'Noto Sans KR',
                                              ],
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...filteredItems.asMap().entries.map((entry) {
                                    int idx = entry.key;
                                    var item = entry.value;

                                    Color indexBg;
                                    Color indexText;
                                    if (idx == 0) {
                                      indexBg = const Color(0xFFEFF4FF);
                                      indexText = const Color(0xFF2563EB);
                                    } else if (idx == 1) {
                                      indexBg = const Color(0xFFFFF3EA);
                                      indexText = const Color(0xFFF97316);
                                    } else {
                                      indexBg = const Color(0xFFE8F8F1);
                                      indexText = const Color(0xFF10B981);
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildPickCard(
                                        index: (idx + 1).toString(),
                                        indexBgColor: indexBg,
                                        indexTextColor: indexText,
                                        badgeText: item.badgeText,
                                        badgeColor: item.badgeColor,
                                        badgeBg: item.badgeBg,
                                        distance: item.distance,
                                        storeName: item.storeName,
                                        menuName: item.menuName,
                                        price: item.price,
                                        tipText: item.tipText,
                                        theme: item.theme,
                                        onTap: item.store == null
                                            ? null
                                            : () => context.push(
                                                AppRoutes.storeDetail,
                                                extra: item.store,
                                              ),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.map_outlined,
                                              color: Color(0xFF0F172A),
                                              size: 16,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '지도에서 보기',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontFamilyFallback: [
                                                  'Noto Sans KR',
                                                ],
                                                color: Color(0xFF0F172A),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => context.push(
                                          AppRoutes.optimalRoute,
                                        ),
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF2563EB,
                                                ).withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.route,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                '이 루트로 보기',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontFamilyFallback: [
                                                    'Noto Sans KR',
                                                  ],
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String text, Color baseColor) {
    bool isSelected = _selectedFilter == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? baseColor.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? Border.all(color: baseColor)
              : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              color: isSelected ? baseColor : const Color(0xFF94A3B8),
              size: 6,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: const ['Noto Sans KR'],
                color: isSelected ? baseColor : const Color(0xFF475569),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickCard({
    required String index,
    required Color indexBgColor,
    required Color indexTextColor,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required String distance,
    required String storeName,
    required String menuName,
    required String price,
    required String tipText,
    String? theme,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: indexBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'PICK',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        index,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['Noto Sans KR'],
                          color: indexTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: badgeColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      badgeText,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontFamilyFallback: const [
                                          'Noto Sans KR',
                                        ],
                                        color: badgeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 백엔드 테마 칩 (이열치열/비 오면 파전 등)
                              if (theme != null && theme.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3EA),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    theme,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      color: Color(0xFFF97316),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          distance,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      storeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['Noto Sans KR'],
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            menuName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          price,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tipText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF475569),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
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

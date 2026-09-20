import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';
import 'dart:convert';
import 'package:howmuch/core/network/api_client.dart';
import 'package:geolocator/geolocator.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  static const blue = Color(0xFF315F52);
  static const orange = Color(0xFFA76546);
  static const green = Color(0xFF527A6C);
  static const amber = Color(0xFFF59E0B);
  static const ink = Color(0xFF1F342D);
  static const black = Color(0xFF1F342D);
  static const muted = Color(0xFF707A70);
  static const hint = Color(0xFFA8AEA4);
  static const border = Color(0xFFD9DDD2);
  static const commentSurface = Color(0xFFF7F5EE);
  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with WidgetsBindingObserver {
  int _selectedFilterIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  List<dynamic> _rawFeeds = [];

  // 위치는 사용자가 직접 요청할 때만 조회한다. 피드 진입만으로 권한을 묻지 않는다.
  String _locationLabel = '전체';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchFeeds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchFeeds(silent: true);
    }
  }

  /// 현위치 → 서버 역지오코딩으로 행정동명 조회.
  /// 권한 거부·실패 시 조용히 '전체'로 폼백 (피드 목록은 항상 전체 표시라 UX 영향 없음).
  Future<void> _loadCurrentLocationLabel() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _setLocationFallback();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _setLocationFallback();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      ).timeout(const Duration(seconds: 10));
      final response = await ApiClient.get(
        ApiClient.uri('/api/locations/region', {
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
        }),
        headers: ApiClient.authHeaders(),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode != 200) return _setLocationFallback();

      final data = ApiClient.decodeJson(response);
      final dong = data['label']?.toString().trim() ?? '';
      if (!mounted) return;
      setState(() {
        _locationLabel = dong.isNotEmpty ? dong : '전체';
      });
    } catch (e) {
      debugPrint('커뮤니티 현위치 조회 실패: $e');
      _setLocationFallback();
    }
  }

  void _setLocationFallback() {
    if (!mounted) return;
    setState(() => _locationLabel = '전체');
  }

  Future<void> _fetchFeeds({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/community/feed'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _rawFeeds = decoded is List ? decoded : [];
          _isLoading = false;
          _hasError = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          if (!silent) {
            _isLoading = false;
            _hasError = true;
          }
        });
      }
    } catch (e) {
      debugPrint('커뮤니티 피드 조회 오류: $e');
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _isLoading = false;
          _hasError = true;
        }
      });
    }
  }

  List<_FeedItem> get _visibleFeedItems {
    final List<_FeedItem> items = _rawFeeds.map((data) {
      final String id = data['id']?.toString() ?? '';
      final String loc = data['location']?.toString() ?? '알 수 없음';
      final String title = data['title']?.toString() ?? '';
      final String author = data['author']?.toString() ?? '알 수 없음';
      final int likes = (data['likes'] as num?)?.toInt() ?? 0;
      final int comments = (data['comments'] as num?)?.toInt() ?? 0;
      final String rawStatus = data['status']?.toString() ?? 'PENDING';
      final String createdAt = data['createdAt']?.toString() ?? '';
      final imageUrls = data['imageUrls'] is List
          ? data['imageUrls'] as List
          : const [];
      final validUrls = imageUrls
          .map((url) => url.toString())
          .where(
            (url) => url.startsWith('http://') || url.startsWith('https://'),
          )
          .toList();
      final String? imageUrl = validUrls.firstOrNull;
      final int imageCount = validUrls.length;

      final rawStore = data['storeName']?.toString().trim() ?? '';
      final rawMenu = data['menu']?.toString().trim() ?? '';
      final rawPrice = data['price']?.toString().trim() ?? '';

      final parsed = _parseFeedTitle(
        title,
        store: rawStore.isNotEmpty ? rawStore : null,
        menu: rawMenu.isNotEmpty ? rawMenu : null,
        price: rawPrice.isNotEmpty ? rawPrice : null,
      );

      final String status = switch (rawStatus.toUpperCase()) {
        'APPROVED' => '승인 완료',
        'PENDING' => '검토 중',
        _ => '가격 변동',
      };

      final Color statusColor = switch (rawStatus.toUpperCase()) {
        'APPROVED' => CommunityFeedScreen.green,
        'PENDING' => const Color(0xFF7A4D30),
        _ => CommunityFeedScreen.orange,
      };

      final Color statusBackground = switch (rawStatus.toUpperCase()) {
        'APPROVED' => const Color(0xFFE7F0E8),
        'PENDING' => const Color(0xFFF6EDE4),
        _ => const Color(0xFFF6EDE4),
      };

      final Color? dotColor = rawStatus.toUpperCase() == 'PENDING'
          ? CommunityFeedScreen.amber
          : null;

      final bool compactStatus = rawStatus.toUpperCase() == 'PENDING';

      return _FeedItem(
        id: id,
        location: loc,
        title: title,
        storeName: parsed.storeName,
        menu: parsed.menu,
        price: parsed.priceFormatted,
        author: author,
        relativeTime: _formatRelativeTime(createdAt),
        likes: likes,
        comments: comments,
        status: status,
        statusColor: statusColor,
        statusBackground: statusBackground,
        imageUrl: imageUrl,
        imageCount: imageCount,
        dotColor: dotColor,
        compactStatus: compactStatus,
      );
    }).toList();

    // 현위치 라벨과 일치하는 제보가 있으면 그 지역만, 없으면 전체 표시.
    // (실데이터 location은 '구로구' 등 다양한 형식이라 정확 일치가 거의 없을 수 있음)
    final matched = items
        .where((item) => item.location == _locationLabel)
        .toList();
    final List<_FeedItem> scoped = matched.isNotEmpty ? matched : items;

    return switch (_selectedFilterIndex) {
      1 => scoped.where((item) => item.status == '가격 변동').toList(),
      2 => (scoped..sort((a, b) => b.likes.compareTo(a.likes))),
      _ => scoped,
    };
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF315F52)),
            SizedBox(height: 12),
            Text(
              '주변 제보를 불러오고 있어요',
              style: TextStyle(
                color: CommunityFeedScreen.muted,
                fontFamily: CommunityFeedScreen.fontFamily,
                fontFamilyFallback: CommunityFeedScreen.fontFallback,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: CommunityFeedScreen.hint,
              size: 36,
            ),
            const SizedBox(height: 10),
            const Text(
              '피드를 불러오지 못했어요',
              style: TextStyle(
                color: CommunityFeedScreen.ink,
                fontFamily: CommunityFeedScreen.fontFamily,
                fontFamilyFallback: CommunityFeedScreen.fontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '네트워크 상태를 확인하고 다시 시도해주세요',
              style: TextStyle(
                color: CommunityFeedScreen.muted,
                fontFamily: CommunityFeedScreen.fontFamily,
                fontFamilyFallback: CommunityFeedScreen.fontFallback,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _fetchFeeds, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final items = _visibleFeedItems;
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '아직 제보가 없어요. 첫 제보를 남겨보세요!',
          style: TextStyle(
            color: CommunityFeedScreen.muted,
            fontFamily: CommunityFeedScreen.fontFamily,
            fontFamilyFallback: CommunityFeedScreen.fontFallback,
            fontSize: 12,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchFeeds,
      color: CommunityFeedScreen.blue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 84),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FeedCard(
              item: item,
              onTap: () async {
                await context.push(
                  '${AppRoutes.communityPostDetail}?id=${item.id}',
                );
                if (mounted) await _fetchFeeds(silent: true);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomNavHeight = HowmuchBottomNav.heightFor(safePadding.bottom);

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFFBFAF5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactLandscape = constraints.maxHeight < 400;
          final navHeight = compactLandscape ? 0.0 : bottomNavHeight;
          final contentTop = compactLandscape
              ? topOffset + 112
              : topOffset + 148.0;
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: topOffset,
                  height: HowmuchTopBar.height,
                  child: _Header(
                    onBack: () => context.go(AppRoutes.home),
                    onSearch: () => context.push(
                      AppRoutes.searchResult,
                      extra: const {'query': ''},
                    ),
                  ),
                ),
                Positioned(
                  left: AppSizes.horizontalPadding,
                  top: topOffset + 58.0,
                  right: AppSizes.horizontalPadding,
                  height: 32,
                  child: _LocationRow(
                    location: _locationLabel,
                    onTap: _loadCurrentLocationLabel,
                  ),
                ),
                Positioned(
                  left: AppSizes.horizontalPadding,
                  top: topOffset + 98.0,
                  right: AppSizes.horizontalPadding,
                  height: 34,
                  child: _FilterRow(
                    selectedIndex: _selectedFilterIndex,
                    onSelected: (index) =>
                        setState(() => _selectedFilterIndex = index),
                  ),
                ),
                Positioned(
                  left: AppSizes.horizontalPadding,
                  top: contentTop,
                  right: AppSizes.horizontalPadding,
                  bottom: navHeight,
                  child: _buildContent(),
                ),
                Positioned(
                  right: 16,
                  bottom: navHeight + 16,
                  child: _NewReportButton(
                    onTap: () => context.push(AppRoutes.reportCreate),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: navHeight,
                  child: navHeight == 0
                      ? const SizedBox.shrink()
                      : HowmuchBottomNav(
                          safeBottom: safePadding.bottom,
                          activeTab: HowmuchBottomTab.explore,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSearch});

  final VoidCallback onBack;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return HowmuchTopBar(
      title: '동네 제보',
      onBack: onBack,
      trailingIcon: Icons.search_rounded,
      onTrailingTap: onSearch,
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, required this.onTap});

  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LocationChip(location: location, onTap: onTap),
        const Spacer(),
        Text(
          '우리 동네 실시간 절약 제보',
          style: const TextStyle(
            color: CommunityFeedScreen.muted,
            fontFamily: CommunityFeedScreen.fontFamily,
            fontFamilyFallback: CommunityFeedScreen.fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location, required this.onTap});

  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '현재 위치로 동네 설정',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEE7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE7EEE7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 13,
                  color: CommunityFeedScreen.blue,
                ),
                const SizedBox(width: 5),
                Text(
                  location,
                  style: const TextStyle(
                    color: CommunityFeedScreen.blue,
                    fontFamily: CommunityFeedScreen.fontFamily,
                    fontFamilyFallback: CommunityFeedScreen.fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: CommunityFeedScreen.blue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // The three chips are wider than a 320px viewport once page padding is
    // included. Keep the row one line and let it scroll rather than allowing
    // a RenderFlex overflow (also useful in short landscape viewports).
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _FilterChip(
          label: '최신 제보',
          selected: selectedIndex == 0,
          onTap: () => onSelected(0),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: '가격 변동',
          selected: selectedIndex == 1,
          onTap: () => onSelected(1),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: '인기 제보',
          selected: selectedIndex == 2,
          onTap: () => onSelected(2),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? CommunityFeedScreen.blue : Colors.white,
          border: Border.all(
            color: selected
                ? CommunityFeedScreen.blue
                : const Color(0xFFD9DDD2),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF315F52).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF46564D),
            fontFamily: CommunityFeedScreen.fontFamily,
            fontFamilyFallback: CommunityFeedScreen.fontFallback,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item, required this.onTap});

  final _FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null;

    return Container(
      key: ValueKey('feed-card-${item.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF2EC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 좌측: 본문 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. 태그 행 (위치 칩 + 상태 뱃지)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2EC),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.place_rounded,
                                      size: 11,
                                      color: Color(0xFF707A70),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.location,
                                      style: const TextStyle(
                                        fontFamily:
                                            CommunityFeedScreen.fontFamily,
                                        fontFamilyFallback:
                                            CommunityFeedScreen.fontFallback,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF707A70),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.status == '가격 변동') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6EDE4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFF6EDE4),
                                    ),
                                  ),
                                  child: const Text(
                                    '가격 변동',
                                    style: TextStyle(
                                      fontFamily:
                                          CommunityFeedScreen.fontFamily,
                                      fontFamilyFallback:
                                          CommunityFeedScreen.fontFallback,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFA76546),
                                    ),
                                  ),
                                ),
                              ] else if (item.status == '검토 중') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6EDE4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFE7CDAF),
                                    ),
                                  ),
                                  child: const Text(
                                    '검토 중',
                                    style: TextStyle(
                                      fontFamily:
                                          CommunityFeedScreen.fontFamily,
                                      fontFamilyFallback:
                                          CommunityFeedScreen.fontFallback,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9B6541),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 2. 상호명 (볼드 타이틀)
                          Text(
                            item.storeName.isNotEmpty
                                ? item.storeName
                                : item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: CommunityFeedScreen.fontFamily,
                              fontFamilyFallback:
                                  CommunityFeedScreen.fontFallback,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F342D),
                              letterSpacing: -0.3,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // 3. 대표 메뉴 및 가격 (블루 볼드 강조)
                          if (item.menu.isNotEmpty || item.price.isNotEmpty)
                            Row(
                              children: [
                                if (item.menu.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      item.menu,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily:
                                            CommunityFeedScreen.fontFamily,
                                        fontFamilyFallback:
                                            CommunityFeedScreen.fontFallback,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF46564D),
                                      ),
                                    ),
                                  ),
                                if (item.menu.isNotEmpty &&
                                    item.price.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        color: Color(0xFFC9D0C5),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (item.price.isNotEmpty)
                                  Text(
                                    item.price,
                                    style: const TextStyle(
                                      fontFamily:
                                          CommunityFeedScreen.fontFamily,
                                      fontFamilyFallback:
                                          CommunityFeedScreen.fontFallback,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF315F52),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 12),

                          // 4. 메타 정보 (작성자, 시간, 반응 카운트)
                          Row(
                            children: [
                              Text(
                                item.author,
                                style: const TextStyle(
                                  fontFamily: CommunityFeedScreen.fontFamily,
                                  fontFamilyFallback:
                                      CommunityFeedScreen.fontFallback,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF707A70),
                                ),
                              ),
                              if (item.relativeTime.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                const Text(
                                  '·',
                                  style: TextStyle(
                                    color: Color(0xFFC9D0C5),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  item.relativeTime,
                                  style: const TextStyle(
                                    fontFamily: CommunityFeedScreen.fontFamily,
                                    fontFamilyFallback:
                                        CommunityFeedScreen.fontFallback,
                                    fontSize: 12,
                                    color: Color(0xFFA8AEA4),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // 우측 하단 반응 카운트가 들어갈 공간을 항상 확보한다.
                              const SizedBox(width: 76),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 우측: 사진이 있을 때만 썸네일 노출
                    if (hasImage) ...[
                      const SizedBox(width: 14),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              item.imageUrl!,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2EC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: Color(0xFFA8AEA4),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          if (item.imageCount > 1)
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.image_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      '${item.imageCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                Positioned(
                  key: ValueKey('feed-reactions-${item.id}'),
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.likes > 0
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 13,
                        color: item.likes > 0
                            ? const Color(0xFFA64B4B)
                            : const Color(0xFFA8AEA4),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.likes}',
                        style: TextStyle(
                          fontFamily: CommunityFeedScreen.fontFamily,
                          fontFamilyFallback: CommunityFeedScreen.fontFallback,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.likes > 0
                              ? const Color(0xFFA64B4B)
                              : const Color(0xFF707A70),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                        color: Color(0xFFA8AEA4),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.comments}',
                        style: const TextStyle(
                          fontFamily: CommunityFeedScreen.fontFamily,
                          fontFamilyFallback: CommunityFeedScreen.fontFallback,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF707A70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewReportButton extends StatelessWidget {
  const _NewReportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA76546), Color(0xFFA76546)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA76546).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.white, size: 19),
              SizedBox(width: 5),
              Text(
                '제보하기',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: CommunityFeedScreen.fontFamily,
                  fontFamilyFallback: CommunityFeedScreen.fontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedItem {
  const _FeedItem({
    required this.id,
    required this.location,
    required this.title,
    required this.storeName,
    required this.menu,
    required this.price,
    required this.author,
    required this.relativeTime,
    required this.likes,
    required this.comments,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.imageUrl,
    required this.imageCount,
    this.dotColor,
    this.compactStatus = false,
  });

  final String id;
  final String location;
  final String title;
  final String storeName;
  final String menu;
  final String price;
  final String author;
  final String relativeTime;
  final int likes;
  final int comments;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String? imageUrl;
  final int imageCount;
  final Color? dotColor;
  final bool compactStatus;
}

String _formatRelativeTime(String isoString) {
  if (isoString.isEmpty) return '';
  try {
    final date = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}월 ${date.day}일';
  } catch (_) {
    return '';
  }
}

String _formatNumberComma(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

class _ParsedFeedTitle {
  final String storeName;
  final String menu;
  final String priceFormatted;

  const _ParsedFeedTitle({
    required this.storeName,
    required this.menu,
    required this.priceFormatted,
  });
}

_ParsedFeedTitle _parseFeedTitle(
  String rawTitle, {
  String? store,
  String? menu,
  String? price,
}) {
  if (store != null && store.isNotEmpty) {
    final pNum = int.tryParse(price?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
    final formattedPrice = pNum != null
        ? '${_formatNumberComma(pNum)}원'
        : (price != null && price.isNotEmpty
              ? (price.endsWith('원') ? price : '$price원')
              : '');
    return _ParsedFeedTitle(
      storeName: store,
      menu: menu ?? '',
      priceFormatted: formattedPrice,
    );
  }

  final tokens = rawTitle
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) {
    return const _ParsedFeedTitle(storeName: '', menu: '', priceFormatted: '');
  }

  // 맨 끝 토큰이 숫자이면 가격으로 분리
  String priceStr = '';
  if (tokens.length >= 2 && RegExp(r'^\d+원?$').hasMatch(tokens.last)) {
    final rawNumStr = tokens.removeLast().replaceAll('원', '');
    final numVal = int.tryParse(rawNumStr);
    if (numVal != null) {
      priceStr = '${_formatNumberComma(numVal)}원';
    } else {
      priceStr = '$rawNumStr원';
    }
  }

  if (tokens.isEmpty) {
    return _ParsedFeedTitle(
      storeName: rawTitle,
      menu: '',
      priceFormatted: priceStr,
    );
  }

  if (tokens.length == 1) {
    return _ParsedFeedTitle(
      storeName: tokens.first,
      menu: '',
      priceFormatted: priceStr,
    );
  }

  return _ParsedFeedTitle(
    storeName: tokens.first,
    menu: tokens.sublist(1).join(' '),
    priceFormatted: priceStr,
  );
}

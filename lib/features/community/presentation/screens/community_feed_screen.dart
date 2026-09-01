import 'package:flutter/material.dart';
import 'dart:async';
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

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const border = Color(0xFFE5E7EB);
  static const commentSurface = Color(0xFFF8FAFC);
  static const fontFamily = 'Inter';
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

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  int _selectedFilterIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  List<dynamic> _rawFeeds = [];
  Timer? _feedRefreshTimer;

  // 위치는 사용자가 직접 요청할 때만 조회한다. 피드 진입만으로 권한을 묻지 않는다.
  String _locationLabel = '전체';

  @override
  void initState() {
    super.initState();
    _fetchFeeds();
    _feedRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchFeeds(silent: true),
    );
  }

  @override
  void dispose() {
    _feedRefreshTimer?.cancel();
    super.dispose();
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
      final imageUrls = data['imageUrls'] is List
          ? data['imageUrls'] as List
          : const [];
      final String? imageUrl = imageUrls
          .map((url) => url.toString())
          .where(
            (url) => url.startsWith('http://') || url.startsWith('https://'),
          )
          .firstOrNull;

      final String status = switch (rawStatus.toUpperCase()) {
        'APPROVED' => '승인 완료',
        'PENDING' => '검토 중',
        _ => '가격 변동',
      };

      final Color statusColor = switch (rawStatus.toUpperCase()) {
        'APPROVED' => CommunityFeedScreen.green,
        'PENDING' => const Color(0xFF92400E),
        _ => CommunityFeedScreen.orange,
      };

      final Color statusBackground = switch (rawStatus.toUpperCase()) {
        'APPROVED' => const Color(0xFFE8F8F1),
        'PENDING' => const Color(0xFFFEF3C7),
        _ => const Color(0xFFFFF3EA),
      };

      final Color? dotColor = rawStatus.toUpperCase() == 'PENDING'
          ? CommunityFeedScreen.amber
          : null;

      final bool compactStatus = rawStatus.toUpperCase() == 'PENDING';

      return _FeedItem(
        id: id,
        location: loc,
        title: title,
        author: author,
        likes: likes,
        comments: comments,
        status: status,
        statusColor: statusColor,
        statusBackground: statusBackground,
        imageUrl: imageUrl,
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
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
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
    return SingleChildScrollView(
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 11.989),
                child: _FeedCard(
                  title: item.title,
                  author: item.author,
                  likes: item.likes,
                  comments: item.comments,
                  status: item.status,
                  statusColor: item.statusColor,
                  statusBackground: item.statusBackground,
                  imageUrl: item.imageUrl,
                  dotColor: item.dotColor,
                  compactStatus: item.compactStatus,
                  onTap: () async {
                    await context.push(
                      '${AppRoutes.communityPostDetail}?id=${item.id}',
                    );
                    if (mounted) await _fetchFeeds(silent: true);
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomNavHeight = HowmuchBottomNav.heightFor(safePadding.bottom);

    return FigmaMobileCanvas(
      backgroundColor: Colors.white,
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
            top: topOffset + 60.87,
            right: 20,
            height: 28,
            child: _LocationRow(
              location: _locationLabel,
              onTap: _loadCurrentLocationLabel,
            ),
          ),
          Positioned(
            left: AppSizes.horizontalPadding,
            top: topOffset + 100.85,
            right: 20,
            height: 33.793,
            child: _FilterRow(
              selectedIndex: _selectedFilterIndex,
              onSelected: (index) =>
                  setState(() => _selectedFilterIndex = index),
            ),
          ),
          Positioned(
            left: AppSizes.horizontalPadding,
            top: topOffset + 150.64,
            right: 20,
            bottom: bottomNavHeight + 85,
            child: _buildContent(),
          ),
          Positioned(
            left: AppSizes.horizontalPadding,
            bottom: bottomNavHeight + 16,
            right: 20,
            height: 54.972,
            child: _NewReportButton(
              onTap: () => context.push(AppRoutes.reportCreate),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomNavHeight,
            child: HowmuchBottomNav(
              safeBottom: safePadding.bottom,
              activeTab: HowmuchBottomTab.explore,
            ),
          ),
        ],
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
        const SizedBox(width: AppSizes.smallSpacing),
        Text(
          '$location 기준',
          style: TextStyle(
            color: CommunityFeedScreen.muted,
            fontFamily: CommunityFeedScreen.fontFamily,
            fontFamilyFallback: CommunityFeedScreen.fontFallback,
            fontSize: 11,
            fontWeight: FontWeight.w400,
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
            height: 28,
            padding: const EdgeInsets.only(left: 10, right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: CommunityFeedScreen.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    color: CommunityFeedScreen.blue,
                    fontFamily: CommunityFeedScreen.fontFamily,
                    fontFamilyFallback: CommunityFeedScreen.fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
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

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: '최신 제보',
          selected: selectedIndex == 0,
          onTap: () => onSelected(0),
        ),
        const SizedBox(width: 5.994),
        _FilterChip(
          label: '가격 변동',
          selected: selectedIndex == 1,
          onTap: () => onSelected(1),
        ),
        const SizedBox(width: 5.994),
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
      child: Container(
        height: 33.793,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.horizontalPadding),
        decoration: BoxDecoration(
          color: selected ? CommunityFeedScreen.blue : Colors.white,
          border: selected
              ? null
              : Border.all(color: CommunityFeedScreen.border, width: .909),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontFamily: CommunityFeedScreen.fontFamily,
            fontFamilyFallback: CommunityFeedScreen.fontFallback,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.title,
    required this.author,
    required this.likes,
    required this.comments,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.imageUrl,
    this.dotColor,
    this.compactStatus = false,
    required this.onTap,
  });

  final String title;
  final String author;
  final int likes;
  final int comments;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String? imageUrl;
  final Color? dotColor;
  final bool compactStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const height = 93.807;
    final imageHeight = height - 1.818;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CommunityFeedScreen.border, width: .909),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 91.989,
              height: imageHeight,
              color: CommunityFeedScreen.commentSurface,
              child: imageUrl == null
                  ? const _FeedImageFallback()
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _FeedImageFallback(),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 11.989,
                  top: 11.989,
                  right: 11.8,
                ),
                child: SizedBox(
                  height: height - 24,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CommunityFeedScreen.ink,
                            fontFamily: CommunityFeedScreen.fontFamily,
                            fontFamilyFallback:
                                CommunityFeedScreen.fontFallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 22.19,
                        child: Text(
                          'by $author',
                          style: const TextStyle(
                            color: CommunityFeedScreen.muted,
                            fontFamily: CommunityFeedScreen.fontFamily,
                            fontFamilyFallback:
                                CommunityFeedScreen.fontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 48.92,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 11,
                              color: CommunityFeedScreen.muted,
                            ),
                            const SizedBox(width: 4),
                            Text('$likes', style: _metricStyle),
                            const SizedBox(width: 11.989),
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 11,
                              color: CommunityFeedScreen.muted,
                            ),
                            const SizedBox(width: 4),
                            Text('$comments', style: _metricStyle),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 46.67,
                        child: _StatusBadge(
                          label: status,
                          color: statusColor,
                          dotColor: dotColor ?? statusColor,
                          backgroundColor: statusBackground,
                          compact: compactStatus,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Colors.white],
          stops: [0, .4],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 0),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: CommunityFeedScreen.orange,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0x4DF97316),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '＋',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: CommunityFeedScreen.fontFamily,
                  fontFamilyFallback: CommunityFeedScreen.fontFallback,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              SizedBox(width: 5),
              Text(
                '새 제보하기',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: CommunityFeedScreen.fontFamily,
                  fontFamilyFallback: CommunityFeedScreen.fontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _metricStyle = TextStyle(
  color: CommunityFeedScreen.muted,
  fontFamily: CommunityFeedScreen.fontFamily,
  fontFamilyFallback: CommunityFeedScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.dotColor,
    required this.backgroundColor,
    required this.compact,
  });

  final String label;
  final Color color;
  final Color dotColor;
  final Color backgroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 21,
      width: compact ? 60.5 : 70.5,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: CommunityFeedScreen.fontFamily,
              fontFamilyFallback: CommunityFeedScreen.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItem {
  const _FeedItem({
    required this.id,
    required this.location,
    required this.title,
    required this.author,
    required this.likes,
    required this.comments,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.imageUrl,
    this.dotColor,
    this.compactStatus = false,
  });

  final String id;
  final String location;
  final String title;
  final String author;
  final int likes;
  final int comments;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String? imageUrl;
  final Color? dotColor;
  final bool compactStatus;
}

class _FeedImageFallback extends StatelessWidget {
  const _FeedImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: CommunityFeedScreen.muted,
            size: 21,
          ),
          SizedBox(height: 4),
          Text(
            '이미지 없음',
            style: TextStyle(
              color: CommunityFeedScreen.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

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
  int _selectedLocationIndex = 0;

  static const _locations = ['역삼동', '합정동'];

  List<_FeedItem> get _visibleFeedItems {
    final location = _locations[_selectedLocationIndex];
    final items = _feedItems.where((item) => item.location == location);

    return switch (_selectedFilterIndex) {
      1 => items.where((item) => item.status == '가격 변동').toList(),
      2 => (items.toList()..sort((a, b) => b.likes.compareTo(a.likes))),
      _ => items.toList(),
    };
  }

  void _cycleLocation() {
    setState(() {
      _selectedLocationIndex = (_selectedLocationIndex + 1) % _locations.length;
    });
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
            top: topOffset,
            width: FigmaMobileCanvas.width,
            height: 48.878,
            child: _Header(
              onBack: () => context.go(AppRoutes.home),
              onSearch: () => context.push(AppRoutes.searchEmpty),
            ),
          ),
          Positioned(
            left: 20,
            top: topOffset + 60.87,
            width: 335.45452880859375,
            height: 28,
            child: _LocationRow(
              location: _locations[_selectedLocationIndex],
              onTap: _cycleLocation,
            ),
          ),
          Positioned(
            left: 20,
            top: topOffset + 100.85,
            width: 335.45452880859375,
            height: 33.793,
            child: _FilterRow(
              selectedIndex: _selectedFilterIndex,
              onSelected: (index) =>
                  setState(() => _selectedFilterIndex = index),
            ),
          ),
          Positioned(
            left: 20,
            top: topOffset + 150.64,
            width: 335.45452880859375,
            child: Column(
              children: _visibleFeedItems
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
                        imageBackground: item.imageBackground,
                        dotColor: item.dotColor,
                        compactStatus: item.compactStatus,
                        onTap: () =>
                            context.push(AppRoutes.communityPostDetail),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Positioned(
            left: 20,
            bottom: bottomNavHeight + 16,
            width: 335.45452880859375,
            height: 54.972,
            child: _NewReportButton(
              onTap: () => context.push(AppRoutes.reportCreate),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: CommunityFeedScreen.border)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 13.98,
            width: 28,
            height: 20,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: CommunityFeedScreen.ink,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 11.99,
            child: Center(
              child: Text(
                '동네 제보',
                style: TextStyle(
                  color: CommunityFeedScreen.black,
                  fontFamily: CommunityFeedScreen.fontFamily,
                  fontFamilyFallback: CommunityFeedScreen.fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 13.98,
            width: 28,
            height: 20,
            child: GestureDetector(
              onTap: onSearch,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.search_rounded,
                size: 22,
                color: CommunityFeedScreen.ink,
              ),
            ),
          ),
        ],
      ),
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
        const SizedBox(width: 8),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
        padding: EdgeInsets.symmetric(horizontal: selected ? 13 : 13.909),
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
    required this.imageBackground,
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
  final Color imageBackground;
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
              color: imageBackground,
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: CommunityFeedScreen.hint,
                  size: 22,
                ),
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
    required this.location,
    required this.title,
    required this.author,
    required this.likes,
    required this.comments,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.imageBackground,
    this.dotColor,
    this.compactStatus = false,
  });

  final String location;
  final String title;
  final String author;
  final int likes;
  final int comments;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final Color imageBackground;
  final Color? dotColor;
  final bool compactStatus;
}

const _feedItems = [
  _FeedItem(
    location: '합정동',
    title: '골목밥상 제육덮밥 6,000원',
    author: '절약왕민수',
    likes: 32,
    comments: 8,
    status: '승인 완료',
    statusColor: CommunityFeedScreen.green,
    statusBackground: Color(0xFFE8F8F1),
    imageBackground: Color(0xFFFFE4D4),
  ),
  _FeedItem(
    location: '역삼동',
    title: '동네카페 아메리카노 2,500원으로 인상',
    author: '강남직장인',
    likes: 12,
    comments: 4,
    status: '가격 변동',
    statusColor: CommunityFeedScreen.orange,
    statusBackground: Color(0xFFFFF3EA),
    imageBackground: Color(0xFFE0E7FF),
  ),
  _FeedItem(
    location: '역삼동',
    title: '착한미용실 남성컷 8,000원',
    author: '동네탐험가',
    likes: 21,
    comments: 6,
    status: '검토 중',
    statusColor: Color(0xFF92400E),
    statusBackground: Color(0xFFFEF3C7),
    imageBackground: Color(0xFFDCFCE7),
    dotColor: CommunityFeedScreen.amber,
    compactStatus: true,
  ),
];

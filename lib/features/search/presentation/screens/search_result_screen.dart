import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/search/presentation/screens/search_filter_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart' as howmuch_home;
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

// ──────────────────────────────────────────────────────────────
// 2-2  검색 결과 화면
// ──────────────────────────────────────────────────────────────
class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({
    super.key,
    required this.initialQuery,
    this.autoOpenFilter = false,
  });

  final String initialQuery;
  final bool autoOpenFilter;

  static const blue   = Color(0xFF2563EB);
  static const ink    = Color(0xFF0F172A);
  static const muted  = Color(0xFF64748B);
  static const hint   = Color(0xFF94A3B8);
  static const surface = Color(0xFFF4F6FA);
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
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  List<Store> _results = [];
  bool _loading = false;
  bool _searched = false;
  String _query = '';
  SearchFilter _filter = const SearchFilter();

  // 디바운스
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _ctrl = TextEditingController(text: _query);
    _doSearch(_query);
    if (widget.autoOpenFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 화면 전환 애니메이션이 완료된 후 바텀시트 열기 (즉시 열면 freeze 발생)
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) _openFilter();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  //  API 검색
  // ────────────────────────────────────────────────
  Future<void> _doSearch(String q) async {
    setState(() {
      _loading = true;
      _searched = true;
      _query = q.trim();
    });

    // 💥 서버 요청 대신 HomeMapScreen에 로드된 전체 11,000개 캐시에서 직접 필터링
    try {
      var stores = List<Store>.from(howmuch_home.HomeMapScreen.globalAllStores);

      // 검색어 필터링
      if (q.isNotEmpty) {
        stores = stores.where((s) => 
          s.storeName.contains(q) || 
          s.menu1.contains(q) || 
          s.industry.contains(q)
        ).toList();
      }

      // 가격 필터링
      if (_filter.maxPrice != null) {
        stores = stores.where((s) {
          final p = int.tryParse(s.price1.replaceAll(RegExp(r'[^0-9]'), ''));
          return p == null || p <= _filter.maxPrice!;
        }).toList();
      }
      
      // 업종 필터링
      if (_filter.industries.isNotEmpty) {
        stores = stores
            .where((s) => _filter.industries.any((ind) =>
              SearchFilter.matchesIndustry(s, ind)))
            .toList();
      }
      
      // 정렬 적용
      if (_filter.sortOrder == '저렴한순') {
        stores.sort((a, b) {
          final pa = int.tryParse(a.price1.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
          final pb = int.tryParse(b.price1.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
          return pa.compareTo(pb);
        });
      }

      // 결과가 너무 많으면 UI 버벅임 방지용으로 100개까지만 노출
      if (stores.length > 100) {
        stores = stores.take(100).toList();
      }

      setState(() => _results = stores);
    } catch (e) {
      debugPrint('검색 중 에러: $e');
      if (mounted) setState(() => _results = _mockResults(q));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 백엔드 미연결 시 더미 데이터
  List<Store> _mockResults(String q) => [
        Store(
          storeName: '$q 맛집 1호',
          address: '서울특별시 중구 명동길 12',
          phoneNumber: '02-1234-5678',
          industry: '한식',
          menu1: '된장찌개',
          price1: '7000',
          menu2: '김치찌개',
          price2: '7000',
          menu3: '',
          price3: '',
          menu4: '',
          price4: '',
          latitude: 37.5636,
          longitude: 126.9834,
        ),
        Store(
          storeName: '$q 식당',
          address: '서울특별시 중구 을지로 3가 45',
          phoneNumber: '02-9876-5432',
          industry: '분식',
          menu1: '떡볶이',
          price1: '5000',
          menu2: '순대',
          price2: '4000',
          menu3: '튀김',
          price3: '3000',
          menu4: '',
          price4: '',
          latitude: 37.5660,
          longitude: 126.9920,
        ),
        Store(
          storeName: '착한 $q 집',
          address: '서울특별시 종로구 종로 100',
          phoneNumber: '02-5555-1234',
          industry: '한식',
          menu1: '백반',
          price1: '6000',
          menu2: '제육볶음',
          price2: '8000',
          menu3: '',
          price3: '',
          menu4: '',
          price4: '',
          latitude: 37.5700,
          longitude: 126.9800,
        ),
      ];

  // ────────────────────────────────────────────────
  //  필터 바텀시트 열기
  // ────────────────────────────────────────────────
  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<SearchFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchFilterSheet(current: _filter),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      _doSearch(_query);
    }
  }

  // ────────────────────────────────────────────────
  //  가격 포맷
  // ────────────────────────────────────────────────
  String _fmt(String raw) {
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n == null) return raw;
    return '${n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        )}원';
  }

  // ────────────────────────────────────────────────
  //  업종 이모지
  // ────────────────────────────────────────────────
  String _emoji(String industry) {
    if (industry.contains('한식')) return '🍲';
    if (industry.contains('분식')) return '🍜';
    if (industry.contains('중식') || industry.contains('중국')) return '🥡';
    if (industry.contains('일식') || industry.contains('초밥')) return '🍱';
    if (industry.contains('양식') || industry.contains('피자')) return '🍕';
    if (industry.contains('카페') || industry.contains('커피')) return '☕';
    if (industry.contains('치킨')) return '🍗';
    if (industry.contains('고기')) return '🥩';
    if (industry.contains('해산물') || industry.contains('횟')) return '🦞';
    if (industry.contains('빵') || industry.contains('베이커리')) return '🥐';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).padding.top;
    final activeFilters = _filter.activeLabels;

    return Scaffold(
      backgroundColor: SearchResultScreen.surface,
      body: Column(
        children: [
          // ──────────────────────────────────────────
          //  상단 헤더 (검색바 + 필터칩)
          // ──────────────────────────────────────────
          _SearchHeader(
            topOffset: topOffset,
            controller: _ctrl,
            focus: _focus,
            activeFilters: activeFilters,
            onBack: () => context.pop({
              'query': _query,
              'filter': _filter,
            }),
            onSearch: () => _doSearch(_ctrl.text),
            onFilterTap: _openFilter,
            onRemoveFilter: (label) {
              setState(() => _filter = _filter.remove(label));
              _doSearch(_query);
            },
          ),

          // ──────────────────────────────────────────
          //  결과 카운트 바
          // ──────────────────────────────────────────
          if (_searched && !_loading)
            _ResultCountBar(
              query: _query,
              count: _results.length,
            ),

          // ──────────────────────────────────────────
          //  본문 (로딩 / 빈 결과 / 결과 리스트)
          // ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SearchResultScreen.blue,
                      strokeWidth: 2.5,
                    ),
                  )
                : _searched && _results.isEmpty
                    ? _EmptyResult(
                        onReset: () {
                          setState(() => _filter = const SearchFilter());
                          _doSearch(_query);
                        },
                        onSuggestionTap: (suggestion) {
                          setState(() => _query = suggestion);
                          _ctrl.text = suggestion;
                          _doSearch(suggestion);
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _results.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final s = _results[i];
                          return _StoreCard(
                            store: s,
                            emoji: _emoji(s.industry),
                            priceLabel: s.menu1.isNotEmpty
                                ? '${s.menu1}  ${_fmt(s.price1)}'
                                : s.industry,
                            onTap: () => context.push(
                              AppRoutes.storeDetail,
                              extra: s,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  검색 헤더 위젯
// ──────────────────────────────────────────────────────────────
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.topOffset,
    required this.controller,
    required this.focus,
    required this.activeFilters,
    required this.onBack,
    required this.onSearch,
    required this.onFilterTap,
    required this.onRemoveFilter,
  });

  final double topOffset;
  final TextEditingController controller;
  final FocusNode focus;
  final List<String> activeFilters;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onRemoveFilter;

  @override
  Widget build(BuildContext context) {
    final hasFilters = activeFilters.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: SearchResultScreen.border, width: 0.9),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topOffset + 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // 뒤로가기
                GestureDetector(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: SearchResultScreen.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 검색 입력창
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: SearchResultScreen.blue, width: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search_rounded,
                            color: SearchResultScreen.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focus,
                            textInputAction: TextInputAction.search,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.text,
                            onSubmitted: (_) {
                              onSearch();
                            },
                            style: const TextStyle(
                              fontFamily: SearchResultScreen.fontFamily,
                              fontFamilyFallback:
                                  SearchResultScreen.fontFallback,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: SearchResultScreen.ink,
                              height: 1.4,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.transparent,
                              hintText: '가게명, 메뉴, 지역 검색',
                              hintStyle: TextStyle(
                                color: SearchResultScreen.hint,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 필터 버튼
                GestureDetector(
                  onTap: onFilterTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: activeFilters.isNotEmpty
                          ? SearchResultScreen.blue
                          : Colors.white,
                      border: Border.all(
                        color: activeFilters.isNotEmpty
                            ? SearchResultScreen.blue
                            : SearchResultScreen.border,
                        width: 0.9,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: activeFilters.isNotEmpty
                          ? Colors.white
                          : SearchResultScreen.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 활성 필터 칩
          if (hasFilters)
            Padding(
              padding: const EdgeInsets.only(
                  left: 44, right: 12, top: 10, bottom: 4),
              child: SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: activeFilters.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final f = activeFilters[i];
                    return GestureDetector(
                      onTap: () => onRemoveFilter(f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: SearchResultScreen.blue, width: 0.9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              f,
                              style: const TextStyle(
                                fontFamily: SearchResultScreen.fontFamily,
                                fontFamilyFallback:
                                    SearchResultScreen.fontFallback,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SearchResultScreen.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.close_rounded,
                                size: 10,
                                color: SearchResultScreen.blue),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          SizedBox(height: hasFilters ? 10 : 14),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  결과 카운트 바
// ──────────────────────────────────────────────────────────────
class _ResultCountBar extends StatelessWidget {
  const _ResultCountBar({required this.query, required this.count});

  final String query;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: SearchResultScreen.fontFamily,
            fontFamilyFallback: SearchResultScreen.fontFallback,
            fontSize: 13,
            color: SearchResultScreen.muted,
          ),
          children: [
            TextSpan(
              text: '"$query"',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: SearchResultScreen.blue,
              ),
            ),
            TextSpan(text: ' 검색 결과  '),
            TextSpan(
              text: '$count',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: SearchResultScreen.ink,
              ),
            ),
            const TextSpan(text: '개'),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  매장 카드
// ──────────────────────────────────────────────────────────────
class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.emoji,
    required this.priceLabel,
    required this.onTap,
  });

  final Store store;
  final String emoji;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
                color: SearchResultScreen.border, width: 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // 이모지 박스
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 가게명 + 업종
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.storeName,
                            style: const TextStyle(
                              fontFamily: SearchResultScreen.fontFamily,
                              fontFamilyFallback:
                                  SearchResultScreen.fontFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: SearchResultScreen.ink,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _IndustryChip(label: store.industry),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 주소
                    Text(
                      store.address,
                      style: const TextStyle(
                        fontFamily: SearchResultScreen.fontFamily,
                        fontFamilyFallback: SearchResultScreen.fontFallback,
                        fontSize: 12,
                        color: SearchResultScreen.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 대표메뉴 + 가격
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu_rounded,
                            size: 12, color: SearchResultScreen.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            priceLabel,
                            style: const TextStyle(
                              fontFamily: SearchResultScreen.fontFamily,
                              fontFamilyFallback:
                                  SearchResultScreen.fontFallback,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SearchResultScreen.blue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: SearchResultScreen.hint),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  업종 칩
// ──────────────────────────────────────────────────────────────
class _IndustryChip extends StatelessWidget {
  const _IndustryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final shortened =
        label.length > 5 ? '${label.substring(0, 5)}…' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: SearchResultScreen.border, width: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        shortened,
        style: const TextStyle(
          fontFamily: SearchResultScreen.fontFamily,
          fontFamilyFallback: SearchResultScreen.fontFallback,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: SearchResultScreen.muted,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  빈 결과
// ──────────────────────────────────────────────────────────────
class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.onReset, required this.onSuggestionTap});

  final VoidCallback onReset;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: FigmaMobileCanvas.width,
        height: 377.9261169433594,
        child: Stack(
          children: [
            Positioned(
              left: 151.73297119140625,
              top: 0,
              width: 71.98863220214844,
              height: 71.98863220214844,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: SearchResultScreen.border, width: .909),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: Color(0xFF5F708A),
                  size: 32,
                ),
              ),
            ),
            const Positioned(
              left: 113.75,
              top: 91.98828125,
              width: 147.9545440673828,
              height: 25.49715805053711,
              child: Text(
                '검색 결과가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SearchResultScreen.ink,
                  fontFamily: SearchResultScreen.fontFamily,
                  fontFamilyFallback: SearchResultScreen.fontFallback,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
            const Positioned(
              left: 75.44036865234375,
              top: 123.48046875,
              width: 224.5596466064453,
              height: 44.1761360168457,
              child: Text(
                '필터를 넓히거나 검색어를 바꿔보세요.\n다른 업종을 찾아볼 수도 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SearchResultScreen.muted,
                  fontFamily: SearchResultScreen.fontFamily,
                  fontFamilyFallback: SearchResultScreen.fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.7,
                ),
              ),
            ),
            Positioned(
              left: 46.1221923828125,
              top: 191.6474609375,
              width: 283.1960144042969,
              height: 58.29545211791992,
              child: _Suggestions(onSuggestionTap: onSuggestionTap),
            ),
            Positioned(
              left: 31.9886474609375,
              top: 273.9345703125,
              width: 311.4772644042969,
              height: 103.99147033691406,
              child: Column(
                children: [
                  _ActionButton(
                    label: '필터 초기화하기',
                    primary: true,
                    onTap: onReset,
                  ),
                  const SizedBox(height: 7.8),
                  _ActionButton(
                    label: '전체 매장 보기',
                    onTap: () {
                      context.pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    const suggestions = <(String, double)>[
      ('김치찌개', 73.80681610107422),
      ('아메리카노', 85.79544830322266),
      ('커트', 49.8011360168457),
      ('백반', 49.8011360168457),
    ];

    return Column(
      children: [
        const SizedBox(
          height: 16.49147605895996,
          child: Center(
            child: Text(
              '이런 건 어때요?',
              style: TextStyle(
                color: SearchResultScreen.muted,
                fontFamily: SearchResultScreen.fontFamily,
                fontFamilyFallback: SearchResultScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < suggestions.length; index++) ...[
              _SuggestionChip(
                label: suggestions[index].$1,
                width: suggestions[index].$2,
                onTap: () => onSuggestionTap(suggestions[index].$1),
              ),
              if (index != suggestions.length - 1)
                const SizedBox(width: 7.997158050537109),
            ],
          ],
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.width,
    required this.onTap,
  });

  final String label;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: width,
          height: 31.80397605895996,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: SearchResultScreen.border, width: .909),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: SearchResultScreen.ink,
              fontFamily: SearchResultScreen.fontFamily,
              fontFamilyFallback: SearchResultScreen.fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 311.4772644042969,
      height: 47.99715805053711,
      child: Material(
        color: primary ? SearchResultScreen.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: primary
                  ? null
                  : Border.all(color: SearchResultScreen.border, width: .909),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : SearchResultScreen.ink,
                fontFamily: SearchResultScreen.fontFamily,
                fontFamilyFallback: SearchResultScreen.fontFallback,
                fontSize: 14,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  필터 데이터 모델
// ──────────────────────────────────────────────────────────────
class SearchFilter {
  final List<String> industries;
  final int? maxPrice;
  final String? distance;
  final String? sortOrder;
  final bool govCertified;
  final bool userReported;

  const SearchFilter({
    this.industries = const [],
    this.maxPrice,
    this.distance,
    this.sortOrder,
    this.govCertified = false,
    this.userReported = true,
  });

  // 하위 호환: 단일 industry getter
  String get industry => industries.isNotEmpty ? industries.first : '';

  List<String> get activeLabels {
    return [
      ...industries,
      if (maxPrice != null) '${(maxPrice! / 10000).toStringAsFixed(0)}만원 이하',
      if (distance != null && distance!.isNotEmpty) distance!,
      if (sortOrder != null && sortOrder!.isNotEmpty) sortOrder!,
      if (govCertified) '정부 인증',
      if (!userReported) '제보 매장 제외',
    ];
  }

  static const Map<String, List<String>> industryKeywords = {
    '음식점': ['한식', '중식', '일식', '양식', '분식', '패스트푸드', '음식', '식당', '반찬', '도시락', '국수', '치킨', '피자', '족발', '감자탕', '삼겹살', '고깃집', '정육', '떡볶이', '김밥'],
    '카페': ['카페', '커피', '음료', '베이커리', '빵', '제과', '디저트', '차(음료)', '주스', '스무디', '아이스크림'],
    '미용': ['미용', '헤어', '네일', '피부', '뷰티', '화장', '미용실', '이발'],
    '세탁': ['세탁', '빨래', '클리닝', '드라이'],
    '생활서비스': ['수선', '열쇠', '인쇄', '복사', '사진', '촬영', '스튜디오', '생활', '서비스', '수리', '기타'],
  };

  static bool matchesIndustry(Store store, String filterIndustry) {
    if (filterIndustry.isEmpty || filterIndustry == '전체') return true;
    final keywords = industryKeywords[filterIndustry];
    if (keywords == null) {
      return store.industry.contains(filterIndustry);
    }
    final lowerIndustry = store.industry.toLowerCase();
    final lowerName = store.storeName.toLowerCase();
    final lowerMenu = store.menu1.toLowerCase();
    
    return keywords.any((kw) {
      final k = kw.toLowerCase();
      return lowerIndustry.contains(k) || lowerName.contains(k) || lowerMenu.contains(k);
    });
  }

  SearchFilter remove(String label) {
    List<String> newIndustries = List.from(industries);
    int? newMaxPrice = maxPrice;
    String? newDistance = distance;
    String? newSortOrder = sortOrder;
    bool newGov = govCertified;
    bool newUser = userReported;

    if (newIndustries.contains(label)) {
      newIndustries.remove(label);
    }
    if (maxPrice != null && label == '${(maxPrice! / 10000).toStringAsFixed(0)}만원 이하') {
      newMaxPrice = null;
    }
    if (label == distance) newDistance = null;
    if (label == sortOrder) newSortOrder = null;
    if (label == '정부 인증') newGov = false;
    if (label == '제보 매장 제외') newUser = true;

    return SearchFilter(
      industries: newIndustries,
      maxPrice: newMaxPrice,
      distance: newDistance,
      sortOrder: newSortOrder,
      govCertified: newGov,
      userReported: newUser,
    );
  }

  SearchFilter copyWith({
    List<String>? industries,
    int? maxPrice,
    bool clearMaxPrice = false,
    String? distance,
    String? sortOrder,
    bool? govCertified,
    bool? userReported,
  }) {
    return SearchFilter(
      industries: industries ?? this.industries,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      distance: distance ?? this.distance,
      sortOrder: sortOrder ?? this.sortOrder,
      govCertified: govCertified ?? this.govCertified,
      userReported: userReported ?? this.userReported,
    );
  }
}


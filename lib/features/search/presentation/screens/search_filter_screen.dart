import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';

// ──────────────────────────────────────────────────────────────
// 2-3  필터 화면 (바텀 시트)
// ──────────────────────────────────────────────────────────────
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({super.key, required this.current});

  final SearchFilter current;

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
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

  // ── 업종
  static const _industryOptions = ['전체', '음식점', '카페', '미용', '세탁', '생활서비스'];

  // ── 최대 가격
  static const _prices = [
    (label: '5천원 이하', value: 5000),
    (label: '1만원 이하', value: 10000),
    (label: '2만원 이하', value: 20000),
  ];

  // ── 거리
  static const _distances = ['500m 이내', '1km 이내', '3km 이내'];

  // ── 정렬 방식
  static const _sortOrders = ['가까운순', '저렴한순', '리뷰 많은순', '절약금액순'];

  late Set<String> _industries;
  late int? _maxPrice;
  late String? _distance;
  late String? _sortOrder;
  late bool _govCertified;
  late bool _userReported;

  @override
  void initState() {
    super.initState();
    _industries = widget.current.industries.isEmpty
        ? {'전체'}
        : Set.from(widget.current.industries);
    _maxPrice = widget.current.maxPrice;
    _distance = widget.current.distance;
    _sortOrder = widget.current.sortOrder;
    _govCertified = widget.current.govCertified;
    _userReported = widget.current.userReported;
  }

  void _apply() {
    final selected = Set.of(_industries)..remove('전체');
    Navigator.pop(
      context,
      SearchFilter(
        industries: selected.toList(),
        maxPrice: _maxPrice,
        distance: _distance,
        sortOrder: _sortOrder,
        govCertified: _govCertified,
        userReported: _userReported,
      ),
    );
  }

  void _reset() {
    setState(() {
      _industries = {'전체'};
      _maxPrice = null;
      _distance = null;
      _sortOrder = null;
      _govCertified = false;
      _userReported = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 핸들 바
          const _Handle(),
          // ─── 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text(
                  '검색 필터',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 스크롤 영역
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 업종 섹션
                    const _SectionTitle(title: '업종'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _industryOptions.map((ind) {
                        final selected = _industries.contains(ind);
                        return _ChipWidget(
                          label: ind,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              if (ind == '전체') {
                                _industries = {'전체'};
                              } else {
                                _industries.remove('전체');
                                if (_industries.contains(ind)) {
                                  _industries.remove(ind);
                                  if (_industries.isEmpty)
                                    _industries.add('전체');
                                } else {
                                  _industries.add(ind);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // ── 가격대 섹션
                    const _SectionTitle(title: '가격대'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _prices.map((p) {
                        final selected = _maxPrice == p.value;
                        return _ChipWidget(
                          label: p.label,
                          selected: selected,
                          onTap: () => setState(
                            () => _maxPrice = selected ? null : p.value,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // ── 거리 섹션
                    const _SectionTitle(title: '거리'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _distances.map((d) {
                        final selected = _distance == d;
                        return _ChipWidget(
                          label: d,
                          selected: selected,
                          onTap: () =>
                              setState(() => _distance = selected ? null : d),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // ── 정렬 방식 섹션
                    const _SectionTitle(title: '정렬 방식'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _sortOrders.map((s) {
                        final selected = _sortOrder == s;
                        return _ChipWidget(
                          label: s,
                          selected: selected,
                          onTap: () =>
                              setState(() => _sortOrder = selected ? null : s),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // ── 스위치 영역
                    _SwitchRow(
                      label: '정부 인증 업소만 보기',
                      value: _govCertified,
                      onChanged: (val) => setState(() => _govCertified = val),
                    ),
                    const SizedBox(height: 16),
                    _SwitchRow(
                      label: '사용자 제보 매장 포함',
                      value: _userReported,
                      onChanged: (val) => setState(() => _userReported = val),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: surface),

          // ─── 하단 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _reset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: surface,
                        foregroundColor: ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '초기화',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontFamilyFallback: fontFallback,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '필터 적용',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontFamilyFallback: fontFallback,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
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
}

// ──────────────────────────────────────────────────────────────
//  재사용 위젯들
// ──────────────────────────────────────────────────────────────
class _ChipWidget extends StatelessWidget {
  const _ChipWidget({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _SearchFilterSheetState.blue : Colors.white,
          border: Border.all(
            color: selected
                ? _SearchFilterSheetState.blue
                : _SearchFilterSheetState.border,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _SearchFilterSheetState.fontFamily,
            fontFamilyFallback: _SearchFilterSheetState.fontFallback,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : _SearchFilterSheetState.ink,
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: _SearchFilterSheetState.fontFamily,
            fontFamilyFallback: _SearchFilterSheetState.fontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _SearchFilterSheetState.ink,
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: _SearchFilterSheetState.blue,
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: _SearchFilterSheetState.fontFamily,
        fontFamilyFallback: _SearchFilterSheetState.fontFallback,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _SearchFilterSheetState.ink,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreDetailScreen extends StatelessWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  static const _blue = Color(0xFF2563EB);
  static const _ink  = Color(0xFF111827);
  static const _sub  = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _bg   = Color(0xFFF9FAFB);

  String _emoji() {
    final i = store.industry;
    if (i.contains('한식'))                       return '🍲';
    if (i.contains('분식'))                       return '🍜';
    if (i.contains('중식') || i.contains('중국')) return '🥡';
    if (i.contains('일식') || i.contains('초밥') || i.contains('돈까스')) return '🍱';
    if (i.contains('양식') || i.contains('피자') || i.contains('버거'))   return '🍕';
    if (i.contains('카페') || i.contains('커피') || i.contains('음료'))   return '☕';
    if (i.contains('치킨') || i.contains('닭'))  return '🍗';
    if (i.contains('고기') || i.contains('육'))  return '🥩';
    if (i.contains('해산물') || i.contains('해물') || i.contains('횟')) return '🦞';
    if (i.contains('빵') || i.contains('베이커리')) return '🥐';
    return '🍽️';
  }

  String _fmt(String raw) {
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n == null) return raw;
    return '${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';
  }

  Future<void> _call(BuildContext ctx) async {
    final num = store.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.isEmpty) {
      _snack(ctx, '전화번호 정보가 없습니다.');
      return;
    }
    await launchUrl(Uri.parse('tel:$num'));
  }

  Future<void> _map(BuildContext ctx) async {
    await launchUrl(
      Uri.parse('https://map.kakao.com/?q=${Uri.encodeComponent(store.address)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _snack(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final menus = [
      if (store.menu1.isNotEmpty) (name: store.menu1, price: store.price1),
      if (store.menu2.isNotEmpty) (name: store.menu2, price: store.price2),
      if (store.menu3.isNotEmpty) (name: store.menu3, price: store.price3),
      if (store.menu4.isNotEmpty) (name: store.menu4, price: store.price4),
    ];
    final hasPhone = store.phoneNumber.isNotEmpty &&
        store.phoneNumber != '전화번호 없음';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ────────────────────────────────────────────────────
              //  상단 앱바 - 흰 배경, 타이틀 없음, 뒤로가기·아이콘만
              // ────────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.black12,
                elevation: 0.5,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border_rounded, size: 22),
                    onPressed: () => _snack(context, '찜 기능은 추후 개발 예정입니다.'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─────────────────────────────────────────────
                    //  가게 헤더 (흰 카드)
                    // ─────────────────────────────────────────────
                    _White(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 이모지 아이콘 박스
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(_emoji(),
                                  style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // 이름 + 업종
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  store.storeName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  store.industry,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _sub,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 별점 (목업)
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFF59E0B), size: 15),
                                    const SizedBox(width: 3),
                                    const Text('4.6',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _ink)),
                                    const SizedBox(width: 4),
                                    const Text('리뷰 128',
                                        style: TextStyle(
                                            fontSize: 12, color: _sub)),
                                    const SizedBox(width: 8),
                                    _MockTag('목업'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const _Divider(),

                    // ─────────────────────────────────────────────
                    //  예상 절약 금액 (목업)
                    // ─────────────────────────────────────────────
                    _White(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('예상 절약 금액',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _sub)),
                              const SizedBox(width: 6),
                              _MockTag('목업 - 추후 개발 필요'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('2,000',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: _blue,
                                      letterSpacing: -1)),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4, left: 3),
                                child: Text('원',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _blue)),
                              ),
                              const SizedBox(width: 8),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 3),
                                child: Text('주변 평균 대비',
                                    style: TextStyle(
                                        fontSize: 12, color: _sub)),
                              ),
                            ],
                          ),
                          if (store.menu1.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(store.menu1,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _ink)),
                                  const Spacer(),
                                  Text(_fmt(store.price1),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _blue)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const _Divider(),

                    // ─────────────────────────────────────────────
                    //  메뉴 목록 (공공데이터)
                    // ─────────────────────────────────────────────
                    if (menus.isNotEmpty)
                      _White(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('메뉴',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _ink)),
                                const Spacer(),
                                const Text('공공데이터 기준',
                                    style: TextStyle(
                                        fontSize: 11, color: _sub)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...menus.asMap().entries.map((e) {
                              final isFirst = e.key == 0;
                              return Column(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text(
                                                e.value.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isFirst
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: _ink,
                                                ),
                                              ),
                                              if (isFirst) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFEFF6FF),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('대표',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: _blue,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _fmt(e.value.price),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isFirst
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isFirst ? _blue : _ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (e.key < menus.length - 1)
                                    const Divider(
                                        height: 1, color: Color(0xFFF3F4F6)),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                    const _Divider(),

                    // ─────────────────────────────────────────────
                    //  매장 정보
                    // ─────────────────────────────────────────────
                    _White(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('매장 정보',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _ink)),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.access_time_outlined,
                            label: '영업시간',
                            value: '정보 없음',
                            isMock: true,
                          ),
                          const Divider(height: 24, color: Color(0xFFF3F4F6)),
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            label: '전화번호',
                            value: hasPhone
                                ? store.phoneNumber
                                : '정보 없음',
                            onTap: hasPhone
                                ? () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: store.phoneNumber));
                                    if (context.mounted) {
                                      _snack(context, '전화번호가 복사되었습니다.');
                                    }
                                  }
                                : null,
                          ),
                          const Divider(height: 24, color: Color(0xFFF3F4F6)),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: '주소',
                            value: store.address,
                            onTap: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: store.address));
                              if (context.mounted) {
                                _snack(context, '주소가 복사되었습니다.');
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const _Divider(),

                    // ─────────────────────────────────────────────
                    //  리뷰 (목업)
                    // ─────────────────────────────────────────────
                    _White(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('리뷰',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _ink)),
                              const SizedBox(width: 6),
                              _MockTag('목업 - 추후 개발 필요'),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {},
                                child: const Text('전체보기',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _blue,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _Review(
                            name: '김○○',
                            text: '가격이 저렴하고 양이 많아요. 강력 추천합니다!',
                            stars: 5,
                            ago: '2일 전',
                          ),
                          const Divider(height: 24, color: Color(0xFFF3F4F6)),
                          _Review(
                            name: '이○○',
                            text: '착한 가격에 맛도 좋아요. 자주 올 것 같아요.',
                            stars: 4,
                            ago: '5일 전',
                          ),
                        ],
                      ),
                    ),

                    // 하단 여백 (하단 바 높이만큼)
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // ────────────────────────────────────────────────────
          //  하단 고정 액션바
          // ────────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: _line),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // 전화 버튼
                      _BottomIconBtn(
                        icon: Icons.phone_rounded,
                        label: '전화',
                        onTap: () => _call(context),
                      ),
                      const SizedBox(width: 10),
                      // 제보 버튼 (목업)
                      _BottomIconBtn(
                        icon: Icons.campaign_rounded,
                        label: '가격 제보',
                        onTap: () =>
                            _snack(context, '가격 변동 제보는 추후 개발 예정입니다.'),
                        muted: true,
                      ),
                      const SizedBox(width: 10),
                      // 길찾기 버튼 (메인 CTA)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _map(context),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '길찾기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  흰 배경 섹션
// ─────────────────────────────────────────────────────────
class _White extends StatelessWidget {
  final Widget child;
  const _White({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────
//  섹션 구분선
// ─────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: const Color(0xFFF3F4F6));
  }
}

// ─────────────────────────────────────────────────────────
//  목업 태그
// ─────────────────────────────────────────────────────────
class _MockTag extends StatelessWidget {
  final String text;
  const _MockTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF92400E),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  정보 행
// ─────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isMock;
  final VoidCallback? onTap;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMock = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMock
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF111827),
                      fontStyle:
                          isMock ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (isMock) _MockTag('추후 개발 필요'),
                if (!isMock && onTap != null)
                  const Icon(Icons.copy_outlined,
                      size: 14, color: Color(0xFFD1D5DB)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  리뷰 아이템
// ─────────────────────────────────────────────────────────
class _Review extends StatelessWidget {
  final String name, text, ago;
  final int stars;
  const _Review(
      {required this.name,
      required this.text,
      required this.stars,
      required this.ago});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF3F4F6),
          child: Text(
            name[0],
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827))),
                  const SizedBox(width: 6),
                  Text(ago,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  ...List.generate(
                      stars,
                      (_) => const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFF59E0B))),
                  ...List.generate(
                      5 - stars,
                      (_) => const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFE5E7EB))),
                ],
              ),
              const SizedBox(height: 4),
              Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  하단 아이콘 버튼
// ─────────────────────────────────────────────────────────
class _BottomIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;
  const _BottomIconBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = muted ? const Color(0xFF9CA3AF) : const Color(0xFF374151);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

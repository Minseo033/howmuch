import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
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
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  bool _showStoreSummary = false;

  void _showStore() {
    setState(() {
      _showStoreSummary = true;
    });
  }

  void _hideStore() {
    if (!_showStoreSummary) {
      return;
    }

    setState(() {
      _showStoreSummary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final bottomNavHeight = _BottomNav.heightFor(bottomOffset);
    const storeCardHeight = 150.44033813476562;
    const storeCardBottomGap = 94.0;
    final storeCardTop =
        FigmaMobileCanvas.height - storeCardBottomGap - storeCardHeight;

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFDDE6F0),
      child: Stack(
        children: [
          // TODO(박지환 BE): 여기를 지우고 실제 지도 API 위젯으로 교체하세요.
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideStore,
              behavior: HitTestBehavior.opaque,
              child: const _MapBackground(),
            ),
          ),
          // TODO(박지환 BE): 매장/가격/좌표 DB API가 붙으면 아래 더미 마커들을 API 응답 기반으로 렌더링하세요.
          Positioned(
            left: 107,
            top: 289.23016357421875,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _Pin(color: HomeMapScreen.blue),
            ),
          ),
          Positioned(
            left: 227,
            top: 229.23016357421875,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _Pin(color: HomeMapScreen.blue),
            ),
          ),
          Positioned(
            left: 297,
            top: 349.23016357421875,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _Pin(color: HomeMapScreen.orange, square: true),
            ),
          ),
          Positioned(
            left: 77,
            top: 439.23016357421875,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _Pin(color: HomeMapScreen.orange, square: true),
            ),
          ),
          Positioned(
            left: 139,
            top: 401.03265380859375,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _PriceMarker(),
            ),
          ),
          Positioned(
            left: 307,
            top: 469.23016357421875,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _Pin(color: HomeMapScreen.blue),
            ),
          ),
          const Positioned(left: 158, top: 538, child: _MyLocationDot()),
          Positioned(
            left: 15.99432373046875,
            top: 10 + topOffset,
            width: 343.4659118652344,
            height: 52,
            child: _SearchBar(onTap: () {}),
          ),
          Positioned(
            left: 15.99432373046875,
            top: 67.98297119140625 + topOffset,
            width: 183.67897033691406,
            height: 28.480112075805664,
            child: const _SourceLegend(),
          ),
          Positioned(
            left: 15.99432373046875,
            top: 106.46307373046875 + topOffset,
            width: 343.4659118652344,
            height: 55.80965805053711,
            child: const _TodayPickCard(),
          ),
          Positioned(
            left: 315.46875,
            top: storeCardTop - 113.5511474609375,
            width: 43.99147415161133,
            height: 43.99147415161133,
            child: const _RoundIconButton(
              icon: Icons.near_me_rounded,
              color: HomeMapScreen.blue,
            ),
          ),
          Positioned(
            left: 225.80963134765625,
            top: storeCardTop - 51.5482177734375,
            width: 133.6505584716797,
            height: 51.9886360168457,
            child: const _AiRecommendControl(),
          ),
          if (_showStoreSummary)
            Positioned(
              left: 15.99432373046875,
              top: storeCardTop,
              width: 343.4659118652344,
              height: storeCardHeight,
              child: const _StoreSummaryCard(),
            ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
            height: bottomNavHeight,
            child: _BottomNav(
              safeBottom: bottomOffset,
              onMypageTap: () => context.go(AppRoutes.mypage),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreTapTarget extends StatelessWidget {
  const _StoreTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 7,
              shadowColor: const Color(0x140F172A),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.99432373046875),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 19,
                      ),
                      SizedBox(width: 7.997158050537109),
                      Text(
                        '가게명, 메뉴, 지역 검색',
                        style: TextStyle(
                          color: HomeMapScreen.hint,
                          fontFamily: HomeMapScreen.fontFamily,
                          fontFamilyFallback: HomeMapScreen.fontFallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7.997158050537109),
        const _SquareButton(icon: Icons.tune_rounded),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 7,
      shadowColor: const Color(0x140F172A),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(icon, color: HomeMapScreen.ink, size: 19),
      ),
    );
  }
}

class _SourceLegend extends StatelessWidget {
  const _SourceLegend();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: const [
            SizedBox(width: 11.988616943359375),
            _Dot(color: HomeMapScreen.blue),
            SizedBox(width: 5.994326591491699),
            Text('정부 인증', style: _smallText),
            SizedBox(width: 10),
            SizedBox(
              height: 10,
              child: VerticalDivider(color: Color(0xFFE5E7EB), width: 1),
            ),
            SizedBox(width: 10),
            _Dot(color: HomeMapScreen.orange),
            SizedBox(width: 5.994326591491699),
            Text('사용자 제보', style: _smallText),
            SizedBox(width: 11.988616943359375),
          ],
        ),
      ),
    );
  }
}

class _TodayPickCard extends StatelessWidget {
  const _TodayPickCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB), width: .909),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 55.99431610107422,
            height: 53.99147415161133,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.thunderstorm_outlined,
                    color: HomeMapScreen.blue,
                    size: 20,
                  ),
                  SizedBox(height: 1.989),
                  Text(
                    '18°',
                    style: TextStyle(
                      color: HomeMapScreen.blue,
                      fontFamily: HomeMapScreen.fontFamily,
                      fontFamilyFallback: HomeMapScreen.fontFallback,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 11.988616943359375),
          Expanded(child: _TodayPickText()),
          _RankDot(label: '1', color: HomeMapScreen.blue),
          _RankDot(label: '2', color: HomeMapScreen.orange),
          _RankDot(label: '3', color: HomeMapScreen.green),
          SizedBox(width: 9.985779),
          Icon(
            Icons.chevron_right_rounded,
            color: HomeMapScreen.muted,
            size: 17,
          ),
          SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _TodayPickText extends StatelessWidget {
  const _TodayPickText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Row(
          children: [
            Text(
              '오늘의 픽',
              style: TextStyle(
                color: HomeMapScreen.blue,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1.5,
                letterSpacing: .4,
              ),
            ),
            SizedBox(width: 5.994),
            Text(
              '· 05.16 토',
              style: TextStyle(
                color: HomeMapScreen.muted,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 9.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
        SizedBox(height: .994),
        Text(
          '따뜻한 국물 메뉴 3곳',
          style: TextStyle(
            color: HomeMapScreen.ink,
            fontFamily: HomeMapScreen.fontFamily,
            fontFamilyFallback: HomeMapScreen.fontFallback,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.5,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _StoreSummaryCard extends StatelessWidget {
  const _StoreSummaryCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240F172A),
            blurRadius: 16,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.99432373046875),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _StoreInfo()),
                  _StorePrice(),
                ],
              ),
            ),
            SizedBox(height: 11.5),
            Row(children: [_SavingBadge(), Spacer(), _DetailButton()]),
          ],
        ),
      ),
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(left: 0, top: 0, child: _GovernmentBadge()),
        Positioned(
          left: 77.5,
          top: 2.2442626953125,
          child: Text('· 320m', style: _muted11),
        ),
        Positioned(
          left: 0,
          top: 28.991455078125,
          child: Text(
            '착한분식',
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 58.4801025390625,
          child: Text('한식 · 분식', style: _muted12),
        ),
        Positioned(
          left: 67.05963134765625,
          top: 61.974365234375,
          child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 11),
        ),
        Positioned(
          left: 86.05111694335938,
          top: 58.4801025390625,
          child: Text(
            '4.6',
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _StorePrice extends StatelessWidget {
  const _StorePrice();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Text('대표 메뉴', style: _muted10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '5,500', style: TextStyle(fontSize: 17)),
                TextSpan(text: '원', style: TextStyle(fontSize: 12)),
              ],
            ),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingBadge extends StatelessWidget {
  const _SavingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24.474430084228516,
      padding: const EdgeInsets.symmetric(horizontal: 7.997161865234375),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text(
        '평균 대비 2,000원 절약',
        style: TextStyle(
          color: HomeMapScreen.green,
          fontFamily: HomeMapScreen.fontFamily,
          fontFamilyFallback: HomeMapScreen.fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}

class _DetailButton extends StatelessWidget {
  const _DetailButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88.9772720336914,
      height: 29.985794067382812,
      decoration: BoxDecoration(
        color: HomeMapScreen.blue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '상세보기',
            style: TextStyle(
              color: Colors.white,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Colors.white, size: 13),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.safeBottom, required this.onMypageTap});

  static const designHeight = 81.98863220214844;
  static const contentHeight = 60.002838134765625;
  static const designBottomReserve = designHeight - contentHeight;
  static const contentLift = 32.0;

  static double heightFor(double safeBottom) {
    return contentHeight +
        (safeBottom > designBottomReserve ? safeBottom : designBottomReserve) +
        contentLift;
  }

  final double safeBottom;
  final VoidCallback onMypageTap;

  @override
  Widget build(BuildContext context) {
    final bottomReserve = safeBottom > designBottomReserve
        ? safeBottom
        : designBottomReserve;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: .909)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomReserve + contentLift,
            height: contentHeight,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 7.5426025390625,
                right: 7.571,
                top: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _NavItem(
                    icon: Icons.home_outlined,
                    label: '홈',
                    active: true,
                  ),
                  const _NavItem(icon: Icons.explore_outlined, label: '탐색'),
                  const _ReportNavItem(),
                  const _NavItem(icon: Icons.bar_chart_rounded, label: '리포트'),
                  GestureDetector(
                    onTap: onMypageTap,
                    child: const _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: '마이',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? HomeMapScreen.blue : HomeMapScreen.hint;

    return SizedBox(
      width: 60,
      height: 50.002838134765625,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 5.994326591491699),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportNavItem extends StatelessWidget {
  const _ReportNavItem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 50.002838134765625,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -13.991455078125,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: HomeMapScreen.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x47F97316),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
          ),
          const Positioned(
            top: 32.0028076171875,
            child: Text(
              '제보',
              style: TextStyle(
                color: HomeMapScreen.hint,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8EEF6), Color(0xFFDDE6F0)],
        ),
      ),
      child: CustomPaint(painter: _HomeMapPainter(), child: SizedBox.expand()),
    );
  }
}

class _HomeMapPainter extends CustomPainter {
  const _HomeMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // TODO(박지환 BE): 실제 지도 API 연결 후 이 더미 지도 그림은 삭제하세요.
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.square;
    final roadDashed = Paint()
      ..color = const Color(0xFFD9E2EE)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    final park = Paint()..color = const Color(0xFFD7EED5);
    final water = Paint()..color = const Color(0x1F2563EB);

    canvas.drawLine(Offset(0, 258), Offset(size.width, 225), road);
    canvas.drawLine(Offset(0, 496), Offset(size.width, 530), road);
    canvas.drawLine(Offset(132, 0), Offset(126, size.height), road);
    canvas.drawLine(Offset(250, 0), Offset(273, size.height), road);

    for (var i = 0; i < 30; i++) {
      final x = i * 14.0;
      canvas.drawLine(
        Offset(x, 252 - i * .9),
        Offset(x + 7, 251 - i * .9),
        roadDashed,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(200, 304, 115, 114),
        const Radius.circular(12),
      ),
      park,
    );
    canvas.drawCircle(
      const Offset(238, 351),
      10,
      Paint()..color = const Color(0xFFB7DDB6),
    );
    canvas.drawCircle(
      const Offset(276, 379),
      14,
      Paint()..color = const Color(0xFFB7DDB6),
    );
    canvas.drawCircle(const Offset(187, 728), 42, water);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, this.square = false});

  final Color color;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 31,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? BorderRadius.circular(8) : null,
              border: Border.all(color: Colors.white, width: 2.727),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.place_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
          CustomPaint(size: const Size(7, 5), painter: _TrianglePainter(color)),
        ],
      ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 122,
      height: 29,
      child: Column(
        children: [
          Container(
            width: 122,
            height: 24,
            decoration: BoxDecoration(
              color: HomeMapScreen.blue,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '●  착한분식 5,500원',
              style: TextStyle(
                color: Colors.white,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(9, 5),
            painter: _TrianglePainter(HomeMapScreen.blue),
          ),
        ],
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: HomeMapScreen.blue.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: HomeMapScreen.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.727),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _AiRecommendControl extends StatelessWidget {
  const _AiRecommendControl();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 73.6647720336914,
          height: 22.982954025268555,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F172A),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'AI',
                  style: TextStyle(color: HomeMapScreen.blue),
                ),
                TextSpan(text: ' 추천받기'),
              ],
            ),
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 7.5),
        Container(
          width: 51.9886360168457,
          height: 51.9886360168457,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HomeMapScreen.blue, Color(0xFF7C3AED)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.818),
            boxShadow: const [
              BoxShadow(
                color: Color(0x592563EB),
                blurRadius: 10,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _RankDot extends StatelessWidget {
  const _RankDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21.988636016845703,
      height: 21.988636016845703,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.818),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: HomeMapScreen.fontFamily,
          fontFamilyFallback: HomeMapScreen.fontFallback,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
    );
  }
}

class _GovernmentBadge extends StatelessWidget {
  const _GovernmentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20.99431800842285,
      padding: const EdgeInsets.symmetric(horizontal: 7.997161865234375),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Dot(color: HomeMapScreen.blue, size: 5.994318008422852),
          SizedBox(width: 5.994),
          Text(
            '정부 인증',
            style: TextStyle(
              color: HomeMapScreen.blue,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 7.997159004211426});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox(width: size, height: size),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _smallText = TextStyle(
  color: HomeMapScreen.ink,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _muted10 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _muted11 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _muted12 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

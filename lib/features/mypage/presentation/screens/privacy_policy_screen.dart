import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
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

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final contentHeight = 1236 + topOffset + bottomOffset;

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(
                width: FigmaMobileCanvas.width,
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 64.8720703125 + topOffset,
                      width: 335.45452880859375,
                      height: 73.80681610107422,
                      child: const _PrivacyIntroCard(),
                    ),
                    Positioned(
                      left: 20,
                      top: 150.66748046875 + topOffset,
                      width: 335.45452880859375,
                      height: 253.0113525390625,
                      child: _TableOfContents(
                        onItemTap: _scrollToPolicyChapter,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 415.66748046875 + topOffset,
                      width: 335.45452880859375,
                      height: 709,
                      child: const Column(
                        children: [
                          _PolicyChapter(
                            number: '1',
                            title: '수집하는 개인정보 항목',
                            lines: [
                              _PolicyLine(
                                strong: '필수',
                                body: ' · 카카오/네이버/애플 로그인 식별자, 닉네임, 이메일',
                              ),
                              _PolicyLine(
                                strong: '선택',
                                body: ' · 위치 정보, 프로필 사진',
                              ),
                              _PolicyLine(
                                strong: '자동 수집',
                                body: ' · 기기 정보, 접속 로그, 방문 기록',
                              ),
                            ],
                            height: 139,
                          ),
                          SizedBox(height: 10),
                          _PolicyChapter(
                            number: '2',
                            title: '개인정보 이용 목적',
                            body:
                                '· 회원 식별 및 서비스 제공\n'
                                '· 주변 매장 추천 및 절약 리포트 산출\n'
                                '· 제보·리뷰 게시 및 사용자 간 상호작용\n'
                                '· 부정 이용 방지 및 보안',
                            height: 145,
                          ),
                          SizedBox(height: 10),
                          _PolicyChapter(
                            number: '3',
                            title: '보유 및 이용 기간',
                            lines: [
                              _PolicyLine(body: '회원 탈퇴 시 즉시 파기를 원칙으로 하나,'),
                              _PolicyLine(
                                strong: '관계 법령',
                                body: '에 따라 일부 정보는 보관됩니다.',
                              ),
                              _PolicyLine(body: '· 계약·결제 기록: 5년 (전자상거래법)'),
                              _PolicyLine(body: '· 접속 로그: 3개월 (통신비밀보호법)'),
                            ],
                            height: 145,
                          ),
                          SizedBox(height: 10),
                          _PolicyChapter(
                            number: '5',
                            title: '위치 정보 처리',
                            lines: [
                              _PolicyLine(
                                body: '위치 정보는 ',
                                strong: '매장 검색·추천 목적',
                                tail:
                                    '으로만 사용되며 별도로 저장하지 않습니다. 위치 권한은 마이페이지에서 언제든 해제할 수 있습니다.',
                              ),
                            ],
                            height: 128,
                          ),
                          SizedBox(height: 10),
                          _PolicyChapter(
                            number: '7',
                            title: '회원 탈퇴 시 데이터 처리',
                            lines: [
                              _PolicyLine(
                                body: '개인 식별 정보는 즉시 삭제되며, ',
                                strong: '승인된 제보 데이터는 익명화',
                                tail: '되어 공익 목적으로 계속 활용됩니다.',
                              ),
                            ],
                            height: 112,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 1140.66748046875 + topOffset,
                      width: 335.45452880859375,
                      height: 93.26704406738281,
                      child: _PrivacyManagerCard(
                        onInquiry: () => context.go(AppRoutes.inquiry),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 1249.9287109375 + topOffset,
                      width: 335.45452880859375,
                      height: 16.789772033691406,
                      child: const Center(
                        child: Text('이전 버전 보기 · 변경 이력', style: _captionText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _LegalHeader(
            title: '개인정보 처리방침',
            topOffset: topOffset,
            onBack: _goBack,
            onAction: _copyDocumentLink,
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.accountManagement);
    }
  }

  void _copyDocumentLink() {
    Clipboard.setData(
      const ClipboardData(text: 'https://eolmago.kr/privacy/v2.4'),
    );
    _showSnackBar('개인정보 처리방침 링크를 복사했어요.');
  }

  void _scrollToPolicyChapter(int index) {
    const chapterTops = [
      415.66748046875,
      564.66748046875,
      719.66748046875,
      874.66748046875,
      874.66748046875,
      1012.66748046875,
      1012.66748046875,
    ];

    if (!_scrollController.hasClients) {
      return;
    }

    final rawTarget =
        chapterTops[index] +
        FigmaMobileCanvas.designSafePaddingOf(context).top -
        60;
    final target = rawTarget.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader({
    required this.title,
    required this.topOffset,
    required this.onBack,
    required this.onAction,
  });

  final String title;
  final double topOffset;
  final VoidCallback onBack;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: FigmaMobileCanvas.width,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: _PrivacyPolicyScreenState.border,
              width: .909,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 72,
              height: 48.877838134765625,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: _PrivacyPolicyScreenState.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 11.98876953125 + topOffset,
              child: IgnorePointer(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _titleText,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: topOffset + 4,
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onAction,
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: _PrivacyPolicyScreenState.muted,
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

class _PrivacyIntroCard extends StatelessWidget {
  const _PrivacyIntroCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        border: Border.all(color: const Color(0x212563EB), width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16.903),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.privacy_tip_outlined,
              size: 18,
              color: _PrivacyPolicyScreenState.blue,
            ),
          ),
          const SizedBox(width: 11.989),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('얼마고? 개인정보 처리방침', style: _blueLabelText),
                SizedBox(height: 3.992),
                Text('버전 2.4   ·   시행 2026.04.01', style: _captionText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({required this.onItemTap});

  final ValueChanged<int> onItemTap;

  static const items = [
    '1. 수집하는 개인정보 항목',
    '2. 개인정보 이용 목적',
    '3. 보유 및 이용 기간',
    '4. 제 3자 제공 안내',
    '5. 위치 정보 처리',
    '6. 이용자의 권리',
    '7. 회원 탈퇴 시 데이터 처리',
  ];

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.903, 12.897, 16.903, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('목차', style: _sectionText),
            const SizedBox(height: 8),
            for (var index = 0; index < items.length; index++)
              _TocRow(title: items[index], onTap: () => onItemTap(index)),
          ],
        ),
      ),
    );
  }
}

class _TocRow extends StatelessWidget {
  const _TocRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 27.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Text(title, style: _bodyText),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: _PrivacyPolicyScreenState.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyChapter extends StatelessWidget {
  const _PolicyChapter({
    required this.number,
    required this.title,
    required this.height,
    this.body,
    this.lines,
  });

  final String number;
  final String title;
  final double height;
  final String? body;
  final List<_PolicyLine>? lines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: _RoundedPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.903, 16.903, 16.903, 0.909),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 21.988,
                    height: 21.988,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(number, style: _numberText),
                  ),
                  const SizedBox(width: 7.997),
                  Text(title, style: _chapterTitleText),
                ],
              ),
              const SizedBox(height: 7.997),
              if (lines != null)
                RichText(
                  text: TextSpan(
                    style: _policyBodyText,
                    children: [
                      for (final line in lines!) ...[
                        line.toSpan(),
                        if (line != lines!.last) const TextSpan(text: '\n'),
                      ],
                    ],
                  ),
                )
              else
                Text(body ?? '', style: _policyBodyText),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyLine {
  const _PolicyLine({this.strong, this.body = '', this.tail = ''});

  final String? strong;
  final String body;
  final String tail;

  TextSpan toSpan() {
    final strongFirst =
        strong != null && (body.isEmpty || body.startsWith(' ·'));
    return TextSpan(
      children: [
        if (strongFirst)
          TextSpan(
            text: strong,
            style: _policyBodyText.copyWith(
              color: _PrivacyPolicyScreenState.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (body.isNotEmpty) TextSpan(text: body),
        if (strong != null && !strongFirst)
          TextSpan(
            text: strong,
            style: _policyBodyText.copyWith(
              color: _PrivacyPolicyScreenState.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (tail.isNotEmpty) TextSpan(text: tail),
      ],
    );
  }
}

class _PrivacyManagerCard extends StatelessWidget {
  const _PrivacyManagerCard({required this.onInquiry});

  final VoidCallback onInquiry;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.903, 16.903, 16.903, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('개인정보 보호 책임자', style: _sectionText),
            const SizedBox(height: 5.994),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('김보호 · 정보보호팀장', style: _managerNameText),
                      SizedBox(height: .994),
                      Text('privacy@eolmago.kr', style: _captionText),
                    ],
                  ),
                ),
                Material(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onInquiry,
                    child: const SizedBox(
                      width: 56.9886360168457,
                      height: 28.480112075805664,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 11,
                            color: _PrivacyPolicyScreenState.blue,
                          ),
                          SizedBox(width: 3),
                          Text('문의', style: _inquiryText),
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
    );
  }
}

class _RoundedPanel extends StatelessWidget {
  const _RoundedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _PrivacyPolicyScreenState.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

const _titleText = TextStyle(
  color: _PrivacyPolicyScreenState.black,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _blueLabelText = TextStyle(
  color: _PrivacyPolicyScreenState.blue,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _sectionText = TextStyle(
  color: _PrivacyPolicyScreenState.muted,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .3,
);

const _bodyText = TextStyle(
  color: _PrivacyPolicyScreenState.ink,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _policyBodyText = TextStyle(
  color: _PrivacyPolicyScreenState.muted,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  height: 1.6,
);

const _captionText = TextStyle(
  color: _PrivacyPolicyScreenState.muted,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _numberText = TextStyle(
  color: _PrivacyPolicyScreenState.blue,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _chapterTitleText = TextStyle(
  color: _PrivacyPolicyScreenState.ink,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _managerNameText = TextStyle(
  color: _PrivacyPolicyScreenState.ink,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _inquiryText = TextStyle(
  color: _PrivacyPolicyScreenState.blue,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

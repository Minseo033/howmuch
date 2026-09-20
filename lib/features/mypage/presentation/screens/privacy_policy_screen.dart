import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const blue = AppColors.primary;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  final _scrollController = ScrollController();
  final List<GlobalKey> _chapterKeys = List.generate(7, (_) => GlobalKey());

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

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                48.877838134765625 + topOffset + 16,
                20,
                24 + bottomOffset,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PrivacyIntroCard(),
                  const SizedBox(height: 12),
                  _TableOfContents(onItemTap: _scrollToPolicyChapter),
                  const SizedBox(height: 12),
                  _PolicyChapter(
                    key: _chapterKeys[0],
                    number: '1',
                    title: '수집하는 개인정보 항목',
                    lines: const [
                      _PolicyLine(strong: '필수', body: ' · 카카오 로그인 식별자, 이메일'),
                      _PolicyLine(strong: '선택', body: ' · 위치 정보'),
                      _PolicyLine(strong: '자동 수집', body: ' · 제보·리뷰·방문·찜·문의 기록'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[1],
                    number: '2',
                    title: '개인정보 이용 목적',
                    body:
                        '· 회원 식별 및 서비스 제공\n'
                        '· 주변 매장 추천 및 절약 리포트 산출\n'
                        '· 제보·리뷰 게시 및 사용자 간 상호작용\n'
                        '· 부정 이용 방지 및 보안',
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[2],
                    number: '3',
                    title: '보유 및 이용 기간',
                    lines: const [
                      _PolicyLine(body: '회원 탈퇴 시 즉시 파기를 원칙으로 하나,'),
                      _PolicyLine(strong: '관계 법령', body: '에 따라 일부 정보는 보관됩니다.'),
                      _PolicyLine(body: '· 회원 탈퇴 시 회원 정보와 이용 기록 삭제'),
                      _PolicyLine(body: '· 법령상 보존 의무가 발생하는 정보는 해당 기간 동안 보관'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[3],
                    number: '4',
                    title: '제 3자 제공 안내',
                    lines: const [
                      _PolicyLine(
                        body: '운영자는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.',
                      ),
                      _PolicyLine(
                        strong: '예외',
                        body: ' · 이용자가 요청한 소셜 로그인 인증 시 카카오 계정 직접 연동',
                      ),
                      _PolicyLine(
                        strong: '제공받는 자',
                        body: ' · (주)카카오 (카카오 로그인 인증 목적 / 카카오 방침 준용)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[4],
                    number: '5',
                    title: '위치 정보 처리',
                    lines: const [
                      _PolicyLine(
                        body: '위치 정보는 ',
                        strong: '매장 검색·추천 목적',
                        tail:
                            '으로만 사용되며 별도로 저장하지 않습니다. 위치 권한은 마이페이지에서 언제든 해제할 수 있습니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[5],
                    number: '6',
                    title: '이용자의 권리',
                    lines: const [
                      _PolicyLine(
                        strong: '열람·정정',
                        body: ' · 마이페이지 프로필 수정에서 닉네임·동네 등 정정',
                      ),
                      _PolicyLine(
                        strong: '삭제·탈퇴',
                        body: ' · 회원 탈퇴 시 계정 및 연관 데이터 즉시 삭제',
                      ),
                      _PolicyLine(
                        strong: '권한 철회',
                        body: ' · 단말기 OS 설정에서 위치·알림·사진 권한 해제',
                      ),
                      _PolicyLine(body: '기타 권리 행사는 앱 내 1:1 문의를 통해 접수할 수 있습니다.'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[6],
                    number: '7',
                    title: '회원 탈퇴 시 데이터 처리',
                    lines: const [
                      _PolicyLine(
                        body: '개인 식별 정보는 즉시 삭제되며, ',
                        strong: '승인된 제보 데이터는 익명화',
                        tail: '되어 공익 목적으로 계속 활용됩니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PrivacyManagerCard(
                    onInquiry: () => context.push(AppRoutes.inquiry),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('이전 버전 보기 · 변경 이력', style: _captionText),
                  ),
                ],
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
      const ClipboardData(text: '얼마고? 개인정보 처리방침 — 앱 내 마이페이지에서 확인'),
    );
    _showSnackBar('개인정보 처리방침 안내를 복사했어요.');
  }

  void _scrollToPolicyChapter(int index) {
    if (index < 0 || index >= _chapterKeys.length) {
      return;
    }
    final targetContext = _chapterKeys[index].currentContext;
    if (targetContext == null ||
        !_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }

    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final scrollable = Scrollable.of(targetContext);
    final scrollBox = scrollable.context.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    final offsetInScrollable = renderBox.localToGlobal(
      Offset.zero,
      ancestor: scrollBox,
    );
    final headerHeight =
        48.877838134765625 +
        FigmaMobileCanvas.designSafePaddingOf(context).top +
        12.0;
    final targetOffset =
        (_scrollController.offset + offsetInScrollable.dy - headerHeight).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
    _scrollController.animateTo(
      targetOffset,
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
      right: 0,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        key: const ValueKey('privacy-policy-header'),
        decoration: const BoxDecoration(
          color: AppColors.white,
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
                color: AppColors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: AppColors.primaryLight,
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        key: ValueKey('privacy-policy-back-icon'),
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
              right: 0,
              top: topOffset,
              width: 72,
              height: 48.877838134765625,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: onAction,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        key: ValueKey('privacy-policy-action-icon'),
                        Icons.open_in_new_rounded,
                        size: 24,
                        color: _PrivacyPolicyScreenState.ink,
                      ),
                    ),
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
        color: AppColors.primaryLight,
        border: Border.all(color: AppColors.primaryAlpha, width: .909),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                  color: _PrivacyPolicyScreenState.blue,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('얼마고? 개인정보 처리방침', style: _blueLabelText),
                  SizedBox(height: 4),
                  Text('버전 2.4   ·   시행 2026.04.01', style: _captionText),
                ],
              ),
            ),
          ],
        ),
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
        color: AppColors.transparent,
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
    super.key,
    required this.number,
    required this.title,
    this.body,
    this.lines,
  });

  final String number;
  final String title;
  final String? body;
  final List<_PolicyLine>? lines;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.all(16.903),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 21.988,
                  height: 21.988,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
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
    );
  }
}

class _PolicyLine {
  const _PolicyLine({this.strong, this.body = '', this.tail = ''});

  final String? strong;
  final String body;
  final String tail;

  TextSpan toSpan() {
    final spans = <TextSpan>[];

    final leading = tail.isNotEmpty ? body : '';
    if (leading.isNotEmpty) {
      spans.add(TextSpan(text: leading));
    }

    if (strong != null && strong!.isNotEmpty) {
      spans.add(
        TextSpan(
          text: strong,
          style: _policyBodyText.copyWith(
            color: _PrivacyPolicyScreenState.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final trailing = tail.isNotEmpty
        ? tail
        : (leading.isEmpty && strong != null ? body : '');
    if (trailing.isNotEmpty) {
      spans.add(TextSpan(text: trailing));
    }

    if (leading.isEmpty &&
        trailing.isEmpty &&
        (strong == null || strong!.isEmpty) &&
        body.isNotEmpty) {
      spans.add(TextSpan(text: body));
    }

    return TextSpan(children: spans);
  }
}

class _PrivacyManagerCard extends StatelessWidget {
  const _PrivacyManagerCard({required this.onInquiry});

  final VoidCallback onInquiry;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Text('개인정보 보호 문의 담당', style: _managerNameText),
                      SizedBox(height: .994),
                      Text('앱 내 1:1 문의로 접수', style: _captionText),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onInquiry,
                    child: SizedBox(
                      key: const ValueKey('privacy-inquiry-button'),
                      width: 56.9886360168457,
                      height: 28.480112075805664,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            key: ValueKey('privacy-inquiry-icon'),
                            size: 11,
                            color: _PrivacyPolicyScreenState.blue,
                          ),
                          const SizedBox(width: 3),
                          Transform.translate(
                            offset: const Offset(0, -1),
                            child: const Text(
                              '문의',
                              key: ValueKey('privacy-inquiry-label'),
                              style: _inquiryText,
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
        color: AppColors.white,
        border: Border.all(
          color: _PrivacyPolicyScreenState.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(22),
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

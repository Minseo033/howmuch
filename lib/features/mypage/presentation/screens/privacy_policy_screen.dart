import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
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
  final List<GlobalKey> _chapterKeys = List.generate(
    _TableOfContents.items.length,
    (_) => GlobalKey(),
  );

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
                  // Each line below mirrors what the app and server actually
                  // collect, send and delete. Update it with the code.
                  _PolicyChapter(
                    key: _chapterKeys[0],
                    number: '1',
                    title: '수집하는 개인정보 항목',
                    lines: const [
                      _PolicyLine(
                        strong: '필수',
                        body: ' · 카카오 회원번호(서비스 식별자), 닉네임, 주 활동 동네, 관심 카테고리',
                      ),
                      _PolicyLine(
                        strong: '카카오에서 동의한 경우',
                        body: ' · 이메일, 카카오 프로필 사진 주소',
                      ),
                      _PolicyLine(
                        strong: '선택',
                        body: ' · 이번 달 절약 목표 금액, 위치 정보(권한을 허용한 경우)',
                      ),
                      _PolicyLine(
                        strong: '서비스 이용 중 생성',
                        body:
                            ' · 제보(매장 정보·메뉴·가격·첨부 사진), 리뷰, 커뮤니티 댓글·좋아요, '
                            '방문 인증 기록(매장·메뉴·결제 금액·절약 금액·매장과의 거리), '
                            '영수증 사진과 판독 결과(금액·날짜), 찜·가격 알림 설정, '
                            '1:1 문의(내용·첨부 사진), 알림 설정과 알림 내역',
                      ),
                      _PolicyLine(
                        strong: '앱 알림을 허용한 경우',
                        body: ' · 푸시 알림용 기기 토큰과 기기 종류(Android·iOS)',
                      ),
                      _PolicyLine(
                        strong: 'AI 채팅을 이용한 경우',
                        body: ' · 입력한 메시지와 최근 대화(최대 6개). 서버에 저장하지 않습니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[1],
                    number: '2',
                    title: '개인정보 이용 목적',
                    body:
                        '· 회원 식별, 로그인 유지 및 서비스 제공\n'
                        '· 커뮤니티·리뷰의 작성자 닉네임과 프로필 사진 표시\n'
                        '· 제보 검토와 지도·커뮤니티 공개, 리뷰·댓글 게시\n'
                        '· 주변 매장 검색·추천, 방문 인증(영수증 판독 포함)과 절약 리포트 산출\n'
                        '· 찜한 매장 가격 변동, 제보 처리 결과, 댓글, 문의 답변, 공지 알림 발송\n'
                        '· 1:1 문의 응대와 AI 채팅 답변 생성\n'
                        '· 부정 이용 방지 및 보안',
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[2],
                    number: '3',
                    title: '보유 및 이용 기간',
                    lines: const [
                      _PolicyLine(
                        body: '· 회원 정보와 이용 기록은 회원 탈퇴 시까지 보관하고, 탈퇴하면 삭제합니다.',
                      ),
                      _PolicyLine(body: '· 영수증 사진은 방문 인증을 승인하거나 반려한 뒤 삭제합니다.'),
                      _PolicyLine(body: '· 로그인 세션은 발급 후 7일(168시간)이 지나면 만료됩니다.'),
                      _PolicyLine(
                        body: '· 다만 ',
                        strong: '관계 법령',
                        tail: '에 따라 보존해야 하는 정보가 생기면 그 기간 동안 보관합니다.',
                      ),
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
                        strong: '서비스 안 공개',
                        body:
                            ' · 커뮤니티 글·댓글에는 작성자 닉네임과 프로필 사진이, 리뷰에는 닉네임이 표시됩니다'
                            '(닉네임 공개 설정이 꺼져 있으면 \'익명\'). 승인된 제보의 매장 정보와 첨부 사진도 '
                            '다른 이용자에게 보입니다.',
                      ),
                      _PolicyLine(
                        strong: '카카오 로그인',
                        body:
                            ' · 이용자가 카카오에 직접 로그인하며, 얼마고?는 카카오에서 회원번호와 이용자가 동의한 이메일·프로필 사진만 받습니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[4],
                    number: '5',
                    title: '처리 위탁 및 국외 이전',
                    lines: const [
                      _PolicyLine(body: '서비스 제공을 위해 아래 업체에 개인정보 처리를 맡기고 있습니다.'),
                      _PolicyLine(
                        strong: 'Google LLC',
                        body:
                            ' · 회원·이용 기록 저장(Firebase Cloud Firestore), 푸시 알림 발송(Firebase 클라우드 메시징), '
                            'AI 채팅 답변 생성(Gemini API: 입력 메시지·최근 대화·주변 매장 정보), '
                            '영수증 글자 판독(Cloud Vision API: 영수증 사진)',
                      ),
                      _PolicyLine(
                        strong: 'Cloudinary',
                        body: ' · 제보·문의·영수증 사진 저장과 전송',
                      ),
                      _PolicyLine(
                        strong: 'Render',
                        body: ' · 서버 운영(모든 API 요청 처리)',
                      ),
                      _PolicyLine(strong: 'Vercel', body: ' · 웹 앱 제공'),
                      _PolicyLine(
                        strong: '(주)카카오',
                        body: ' · 카카오 로그인, 지도 표시, 주소·장소 검색과 위치 좌표의 동네 이름 변환',
                      ),
                      _PolicyLine(
                        strong: '국외 이전',
                        body:
                            ' · Google, Cloudinary, Render, Vercel은 해외 사업자로, 서비스를 이용할 때 위 정보가 '
                            '네트워크를 통해 각 사업자의 해외 서버로 전송·보관될 수 있습니다. Firestore·Cloudinary에 '
                            '저장된 정보는 회원 탈퇴 또는 위탁 종료 시까지 보관하며, AI 채팅 내용은 얼마고? 서버에 '
                            '저장하지 않습니다(Google 측 처리는 Google 약관을 따릅니다). '
                            '원하지 않으면 AI 채팅·사진 첨부·푸시 알림을 이용하지 않거나 회원 탈퇴를 할 수 있습니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[5],
                    number: '6',
                    title: '위치 정보 처리',
                    lines: const [
                      _PolicyLine(
                        body: '위치 정보는 ',
                        strong: '주변 매장 검색·추천과 방문 인증',
                        tail: '에만 사용하며, 서버는 위치 좌표를 저장하지 않습니다.',
                      ),
                      _PolicyLine(
                        body:
                            '· 좌표가 서버로 전송되는 경우: 오늘의 픽·추천 루트, AI 채팅의 주변 매장 찾기, 방문 위치 인증, '
                            '동네를 현재 위치로 설정하거나 커뮤니티에서 현재 위치로 볼 때, 제보 시 장소 검색',
                      ),
                      _PolicyLine(body: '· 방문 위치 인증에는 매장과의 거리(미터)만 기록합니다.'),
                      _PolicyLine(
                        body:
                            '· 동네 이름 변환과 장소 검색에는 카카오 로컬 API를, 날씨 확인에는 좌표를 약 5km 격자로 바꿔 '
                            '기상청 단기예보 API를 이용합니다.',
                      ),
                      _PolicyLine(
                        body:
                            '· 위치 권한은 선택입니다. 거부해도 지도와 검색은 이용할 수 있고, 권한은 브라우저 사이트 설정 또는 '
                            '기기 설정에서 바꿀 수 있습니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[6],
                    number: '7',
                    title: '이용자의 권리',
                    lines: const [
                      _PolicyLine(
                        strong: '열람·정정',
                        body:
                            ' · 닉네임은 마이페이지 프로필 수정에서 바꿀 수 있고, 동네·관심 카테고리 정정은 1:1 문의로 요청할 수 있습니다. '
                            '이메일·프로필 사진은 카카오 계정 정보를 따릅니다.',
                      ),
                      _PolicyLine(
                        strong: '삭제·탈퇴',
                        body:
                            ' · 마이페이지 계정 관리의 회원 탈퇴로 계정과 연관 데이터 삭제를 요청할 수 있습니다.',
                      ),
                      _PolicyLine(
                        strong: '권한 철회',
                        body:
                            ' · 브라우저 사이트 설정 또는 기기 설정에서 위치·알림·사진 권한 변경, '
                            '마이페이지 알림 설정에서 푸시 알림 수신 변경',
                      ),
                      _PolicyLine(body: '기타 권리 행사는 앱 내 1:1 문의를 통해 접수할 수 있습니다.'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PolicyChapter(
                    key: _chapterKeys[7],
                    number: '8',
                    title: '회원 탈퇴 시 데이터 처리',
                    lines: const [
                      _PolicyLine(
                        body:
                            '탈퇴하면 서버에서 회원 정보, 리뷰, 검토 중이거나 반려된 제보, 방문·영수증 인증 기록, '
                            '찜·가격 알림 설정, 1:1 문의, 댓글·좋아요, 알림 내역과 설정, 기기 토큰, 올린 사진을 삭제합니다.',
                      ),
                      _PolicyLine(
                        body: '',
                        strong: '승인된 제보는 작성자 연결과 첨부 사진을 지운 뒤',
                        tail: ' 매장 정보로 계속 공개됩니다.',
                      ),
                      _PolicyLine(body: '탈퇴가 끝나면 카카오 계정과 얼마고?의 연결 끊기도 요청합니다.'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PrivacyManagerCard(
                    onInquiry: () => context.push(AppRoutes.inquiry),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      '2026.10.06 개정: 처리 위탁·국외 이전, 위치·사진·알림 처리 내용 보완',
                      textAlign: TextAlign.center,
                      style: _captionText,
                    ),
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
      ..showSnackBar(HowmuchSnackBar(content: Text(message)));
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
              left: 8,
              top: topOffset,
              width: 48,
              height: 48.877838134765625,
              // The bare icons had no name (QA 10/7 #50).
              child: Semantics(
                button: true,
                label: '뒤로가기',
                child: Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    hoverColor: AppColors.primaryLight,
                    onTap: onBack,
                    child: const Padding(
                      padding: EdgeInsets.zero,
                      child: Align(
                        alignment: Alignment.center,
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
              child: Semantics(
                button: true,
                label: '개인정보 처리방침 안내 복사',
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1647B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x24FFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 26,
                  color: AppColors.white,
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('얼마고? 개인정보 처리방침', style: _introTitleText),
                  SizedBox(height: 6),
                  Text('버전 2.5  ·  시행 2026.10.06', style: _introCaptionText),
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
    '5. 처리 위탁 및 국외 이전',
    '6. 위치 정보 처리',
    '7. 이용자의 권리',
    '8. 회원 탈퇴 시 데이터 처리',
  ];

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 18,
                  color: _PrivacyPolicyScreenState.blue,
                ),
                SizedBox(width: 8),
                Text('목차', style: _tocHeadingText),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < items.length; index++)
              _TocRow(
                index: index,
                title: items[index],
                onTap: () => onItemTap(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.index,
    required this.title,
    required this.onTap,
  });

  final int index;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: index == _TableOfContents.items.length - 1
                    ? AppColors.transparent
                    : const Color(0xFFEFF2F7),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Text('${index + 1}', style: _tocNumberText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.substring(3),
                  key: ValueKey('privacy-toc-$index'),
                  style: _bodyText.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: const Color(0xFFE5E9F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _PrivacyPolicyScreenState.blue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(number, style: _numberText),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    key: ValueKey('privacy-chapter-$number-title'),
                    style: _chapterTitleText,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 10),
              child: Divider(height: 1, color: Color(0xFFEFF2F7)),
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF172554),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('개인정보 보호 책임자', style: _managerEyebrowText),
            const SizedBox(height: 5.994),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('개인정보 보호 문의 담당', style: _managerNameText),
                      SizedBox(height: .994),
                      Text('앱 내 1:1 문의로 접수', style: _managerCaptionText),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onInquiry,
                    child: SizedBox(
                      key: const ValueKey('privacy-inquiry-button'),
                      width: 68,
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            key: ValueKey('privacy-inquiry-icon'),
                            size: 14,
                            color: _PrivacyPolicyScreenState.blue,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            '문의',
                            key: ValueKey('privacy-inquiry-label'),
                            style: _inquiryText,
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

const _introTitleText = TextStyle(
  color: AppColors.white,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w800,
  height: 1.4,
);

const _introCaptionText = TextStyle(
  color: Color(0xD9FFFFFF),
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _tocHeadingText = TextStyle(
  color: _PrivacyPolicyScreenState.ink,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _tocNumberText = TextStyle(
  color: _PrivacyPolicyScreenState.blue,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  height: 1.5,
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
  color: AppColors.white,
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
  color: AppColors.white,
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _managerEyebrowText = TextStyle(
  color: Color(0xFF93C5FD),
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .3,
);

const _managerCaptionText = TextStyle(
  color: Color(0xFFD7E3FF),
  fontFamily: _PrivacyPolicyScreenState.fontFamily,
  fontFamilyFallback: _PrivacyPolicyScreenState.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w400,
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

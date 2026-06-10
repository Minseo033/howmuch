import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  const CommunityPostDetailScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF4F6FA);
  static const commentSurface = Color(0xFFF8FAFC);
  static const softBlue = Color(0xFFEFF4FF);
  static const softOrange = Color(0xFFFFF3EA);
  static const contentLeft = 20.0;
  static const contentRight = 20.0;
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
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _controller = TextEditingController();
  final _comments = <_CommentData>[
    const _CommentData(
      avatar: '동',
      author: '동네탐험가',
      time: '10분 전',
      text: '저도 어제 갔었는데 맞아요! 메뉴판에 2,500원이라고 써 있더라고요.',
      likes: 4,
    ),
    const _CommentData(
      avatar: '절',
      author: '절약왕민수',
      time: '1시간 전',
      text: '제보 감사해요. 빨리 앱에 반영됐으면 좋겠네요.',
      likes: 2,
    ),
  ];

  bool _notifyEnabled = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _comments.insert(
        0,
        _CommentData(
          avatar: '나',
          author: '나',
          time: '방금 전',
          text: text,
          likes: 0,
        ),
      );
      _controller.clear();
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom > 24 ? safePadding.bottom : 24.0;
    final designScale = FigmaMobileCanvas.designScaleFor(context);
    final keyboardInset = designScale <= 0
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom / designScale;
    final composerBottomGap =
        (keyboardInset > 0 ? keyboardInset : bottomOffset) + 34;
    const composerTopPadding = 10.0;
    const composerHeight = 43.991;
    final bottomBarHeight =
        composerTopPadding + composerHeight + composerBottomGap;

    void goBack() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutes.communityFeed);
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: FigmaMobileCanvas(
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: FigmaMobileCanvas.width,
              height: topOffset,
              child: const ColoredBox(color: Colors.white),
            ),
            Positioned(
              left: 0,
              top: topOffset,
              width: FigmaMobileCanvas.width,
              height: 48.878,
              child: _PostHeader(onBack: goBack),
            ),
            Positioned(
              left: 0,
              top: topOffset + 48.878,
              width: FigmaMobileCanvas.width,
              height: FigmaMobileCanvas.height - topOffset - 48.878,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  CommunityPostDetailScreen.contentLeft,
                  15.99,
                  CommunityPostDetailScreen.contentRight,
                  bottomBarHeight + 24,
                ),
                children: [
                  _PostCard(
                    notifyEnabled: _notifyEnabled,
                    onNotifyTap: () =>
                        setState(() => _notifyEnabled = !_notifyEnabled),
                  ),
                  const SizedBox(height: 14.66),
                  Text(
                    '댓글 ${_comments.length}개',
                    style: const TextStyle(
                      color: CommunityPostDetailScreen.muted,
                      fontFamily: CommunityPostDetailScreen.fontFamily,
                      fontFamilyFallback:
                          CommunityPostDetailScreen.fontFallback,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 8.5),
                  ..._comments.map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 11.989),
                      child: _CommentCard(comment: comment),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              width: FigmaMobileCanvas.width,
              height: bottomBarHeight,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: CommunityPostDetailScreen.border,
                      width: .909,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    CommunityPostDetailScreen.contentLeft,
                    composerTopPadding,
                    CommunityPostDetailScreen.contentRight,
                    composerBottomGap,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: composerHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: CommunityPostDetailScreen.commentSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: CommunityPostDetailScreen.border,
                                width: .909,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.909,
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textSelectionTheme:
                                    const TextSelectionThemeData(
                                      cursorColor:
                                          CommunityPostDetailScreen.blue,
                                      selectionColor: Color(0x332563EB),
                                      selectionHandleColor: Colors.transparent,
                                    ),
                              ),
                              child: TextField(
                                controller: _controller,
                                cursorColor: CommunityPostDetailScreen.blue,
                                enableSuggestions: false,
                                autocorrect: false,
                                style: const TextStyle(
                                  color: CommunityPostDetailScreen.ink,
                                  fontFamily:
                                      CommunityPostDetailScreen.fontFamily,
                                  fontFamilyFallback:
                                      CommunityPostDetailScreen.fontFallback,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: '댓글을 입력하세요.',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontFamily:
                                        CommunityPostDetailScreen.fontFamily,
                                    fontFamilyFallback:
                                        CommunityPostDetailScreen.fontFallback,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitComment(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7.997),
                      SizedBox(
                        width: 43.991,
                        height: composerHeight,
                        child: FilledButton(
                          onPressed: _submitComment,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: CommunityPostDetailScreen.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
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

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: CommunityPostDetailScreen.border),
        ),
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
                color: CommunityPostDetailScreen.ink,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 11.99,
            child: Center(
              child: Text(
                '게시글 상세',
                style: TextStyle(
                  color: CommunityPostDetailScreen.black,
                  fontFamily: CommunityPostDetailScreen.fontFamily,
                  fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.notifyEnabled, required this.onNotifyTap});

  final bool notifyEnabled;
  final VoidCallback onNotifyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13.99, 13.99, 13.99, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CommunityPostDetailScreen.border,
          width: .909,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _AvatarBadge(
                label: '강',
                backgroundColor: CommunityPostDetailScreen.softOrange,
                textColor: CommunityPostDetailScreen.orange,
                size: 31.989,
                fontSize: 13,
              ),
              SizedBox(width: 7.997),
              Expanded(child: _AuthorMeta()),
              _PostStatusBadge(),
            ],
          ),
          const SizedBox(height: 11.989),
          const Text(
            '동네카페 아메리카노 2,500원으로 가격 인상됐어요',
            style: TextStyle(
              color: CommunityPostDetailScreen.ink,
              fontFamily: CommunityPostDetailScreen.fontFamily,
              fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8.99),
          const Text(
            '어제 갔더니 2,000원에서 2,500원으로 올랐어요. 메뉴판 사진도 찍어왔어요. 앱에 아직 반영이 안 된 것 같아서 제보합니다.',
            style: TextStyle(
              color: CommunityPostDetailScreen.ink,
              fontFamily: CommunityPostDetailScreen.fontFamily,
              fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CommunityPostDetailScreen.softOrange,
                  CommunityPostDetailScreen.softBlue,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_outlined,
              color: CommunityPostDetailScreen.muted,
              size: 22,
            ),
          ),
          const SizedBox(height: 11.989),
          Row(
            children: [
              const _PostMetric(
                icon: Icons.thumb_up_alt_outlined,
                label: '도움이 돼요 12',
              ),
              const SizedBox(width: 16),
              const _PostMetric(
                icon: Icons.mode_comment_outlined,
                label: '댓글 2',
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNotifyTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      notifyEnabled
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_off_outlined,
                      size: 12,
                      color: CommunityPostDetailScreen.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notifyEnabled ? '알림' : '해제',
                      style: const TextStyle(
                        color: CommunityPostDetailScreen.blue,
                        fontFamily: CommunityPostDetailScreen.fontFamily,
                        fontFamilyFallback:
                            CommunityPostDetailScreen.fontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthorMeta extends StatelessWidget {
  const _AuthorMeta();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '강남직장인',
          style: TextStyle(
            color: CommunityPostDetailScreen.ink,
            fontFamily: CommunityPostDetailScreen.fontFamily,
            fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        Text(
          '2026.05.14 · 역삼동',
          style: TextStyle(
            color: CommunityPostDetailScreen.muted,
            fontFamily: CommunityPostDetailScreen.fontFamily,
            fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PostStatusBadge extends StatelessWidget {
  const _PostStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70.497,
      height: 20.994,
      decoration: BoxDecoration(
        color: CommunityPostDetailScreen.softOrange,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: CommunityPostDetailScreen.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '가격 변동',
            style: TextStyle(
              color: CommunityPostDetailScreen.orange,
              fontFamily: CommunityPostDetailScreen.fontFamily,
              fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
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

class _PostMetric extends StatelessWidget {
  const _PostMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: CommunityPostDetailScreen.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: CommunityPostDetailScreen.muted,
            fontFamily: CommunityPostDetailScreen.fontFamily,
            fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final _CommentData comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvatarBadge(
          label: comment.avatar,
          backgroundColor: CommunityPostDetailScreen.softBlue,
          textColor: CommunityPostDetailScreen.blue,
          size: 27.997,
          fontSize: 10,
        ),
        const SizedBox(width: 7.997),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  11.989,
                  11.989,
                  11.988,
                  11.989,
                ),
                decoration: BoxDecoration(
                  color: CommunityPostDetailScreen.commentSurface,
                  border: Border.all(
                    color: CommunityPostDetailScreen.border,
                    width: .909,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.author,
                          style: const TextStyle(
                            color: CommunityPostDetailScreen.ink,
                            fontFamily: CommunityPostDetailScreen.fontFamily,
                            fontFamilyFallback:
                                CommunityPostDetailScreen.fontFallback,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.time,
                          style: const TextStyle(
                            color: CommunityPostDetailScreen.muted,
                            fontFamily: CommunityPostDetailScreen.fontFamily,
                            fontFamilyFallback:
                                CommunityPostDetailScreen.fontFallback,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3.991),
                    Text(
                      comment.text,
                      style: const TextStyle(
                        color: CommunityPostDetailScreen.ink,
                        fontFamily: CommunityPostDetailScreen.fontFamily,
                        fontFamilyFallback:
                            CommunityPostDetailScreen.fontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 3.992, top: 3.991),
                child: Row(
                  children: [
                    const Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 10,
                      color: CommunityPostDetailScreen.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likes}',
                      style: const TextStyle(
                        color: CommunityPostDetailScreen.muted,
                        fontFamily: CommunityPostDetailScreen.fontFamily,
                        fontFamilyFallback:
                            CommunityPostDetailScreen.fontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(width: 11.989),
                    const Text(
                      '답글 달기',
                      style: TextStyle(
                        color: CommunityPostDetailScreen.muted,
                        fontFamily: CommunityPostDetailScreen.fontFamily,
                        fontFamilyFallback:
                            CommunityPostDetailScreen.fontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.size,
    required this.fontSize,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontFamily: CommunityPostDetailScreen.fontFamily,
          fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
    );
  }
}

class _CommentData {
  const _CommentData({
    required this.avatar,
    required this.author,
    required this.time,
    required this.text,
    required this.likes,
  });

  final String avatar;
  final String author;
  final String time;
  final String text;
  final int likes;
}

import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/community_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final String postId;
  const CommunityPostDetailScreen({super.key, this.postId = ''});

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
  final CommunityService _service = const CommunityService();

  bool _isLoading = false;
  bool _hasError = false;
  bool _commentsLoading = false;
  bool _commentsUnavailable = false;
  bool _isSubmitting = false;
  bool _likeInFlight = false;
  bool _notificationInFlight = false;
  bool _likedByMe = false;
  bool _notificationEnabled = false;
  Map<String, dynamic>? _postData;
  List<CommunityComment> _comments = const [];
  CommunityComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (widget.postId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final decoded = await _service.fetchFeedDetail(widget.postId);
      if (!mounted) return;
      setState(() {
        _postData = decoded;
        _likedByMe = _readBool(decoded, const ['likedByMe', 'liked']) ?? false;
        _notificationEnabled =
            _readBool(decoded, const [
              'notificationEnabled',
              'subscribed',
              'notified',
            ]) ??
            false;
        _isLoading = false;
      });
      await _fetchComments();
    } catch (e) {
      debugPrint('게시글 상세 조회 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchComments() async {
    if (widget.postId.isEmpty) return;
    setState(() {
      _commentsLoading = true;
      _commentsUnavailable = false;
    });

    try {
      final comments = await _service.fetchComments(widget.postId);
      final commentsWithReplies = await Future.wait(
        comments.map((comment) async {
          if (comment.replyCount <= 0) return comment;
          try {
            final replies = await _service.fetchReplies(comment.id);
            return comment.copyWith(replies: replies);
          } catch (e) {
            debugPrint('답글 목록 조회 오류: $e');
            return comment;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _comments = commentsWithReplies;
        _commentsLoading = false;
      });
    } catch (e) {
      debugPrint('댓글 목록 조회 오류: $e');
      if (!mounted) return;
      setState(() {
        _comments = const [];
        _commentsLoading = false;
        _commentsUnavailable = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) {
      return;
    }
    if (!_requireAuthentication()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);

    try {
      final replyTarget = _replyTarget;
      if (replyTarget == null) {
        final created = await _service.createComment(widget.postId, text);
        if (!mounted) return;
        setState(() {
          _controller.clear();
          if (created != null) {
            _comments = [..._comments, created];
          }
          _bumpCommentCount();
          _isSubmitting = false;
        });
      } else {
        final created = await _service.createReply(replyTarget.id, text);
        if (!mounted) return;
        setState(() {
          _controller.clear();
          _replyTarget = null;
          if (created != null) {
            _comments = _comments.map((comment) {
              if (comment.id != replyTarget.id) return comment;
              return comment.copyWith(
                replyCount: comment.replyCount + 1,
                replies: [...comment.replies, created],
              );
            }).toList();
          }
          _bumpCommentCount();
          _isSubmitting = false;
        });
      }
      await _fetchComments();
      await _refreshDetailCounts();
    } catch (e) {
      debugPrint('댓글 등록 오류: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar('댓글 등록에 실패했습니다. 다시 시도해주세요.');
    }
  }

  int get _commentCount {
    final data = _postData;
    final loadedCount = _comments.fold<int>(
      0,
      (sum, comment) => sum + 1 + comment.replies.length,
    );
    if (data == null) return loadedCount;
    final serverCount = (data['comments'] as num?)?.toInt() ?? 0;
    return serverCount > loadedCount ? serverCount : loadedCount;
  }

  Widget _buildCommentSection() {
    final count = _commentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 $count개',
          style: const TextStyle(
            color: CommunityPostDetailScreen.muted,
            fontFamily: CommunityPostDetailScreen.fontFamily,
            fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.5,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 8.5),
        if (_commentsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: CircularProgressIndicator(
                color: CommunityPostDetailScreen.blue,
              ),
            ),
          )
        else if (_commentsUnavailable)
          const _CommentEmptyState(text: '댓글을 불러오지 못했어요.')
        else if (_comments.isEmpty)
          const _CommentEmptyState(text: '아직 댓글이 없어요.')
        else
          ..._comments.map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CommentCard(
                comment: comment,
                onReply: () => setState(() => _replyTarget = comment),
              ),
            ),
          ),
      ],
    );
  }

  void _bumpCommentCount() {
    final data = _postData;
    if (data == null) return;
    final next = Map<String, dynamic>.from(data);
    next['comments'] = ((next['comments'] as num?)?.toInt() ?? 0) + 1;
    _postData = next;
  }

  Future<void> _refreshDetailCounts() async {
    try {
      final decoded = await _service.fetchFeedDetail(widget.postId);
      if (!mounted) return;
      setState(() {
        _postData = decoded;
        _likedByMe =
            _readBool(decoded, const ['likedByMe', 'liked']) ?? _likedByMe;
        _notificationEnabled =
            _readBool(decoded, const [
              'notificationEnabled',
              'subscribed',
              'notified',
            ]) ??
            _notificationEnabled;
      });
    } catch (_) {
      // 상세 재조회 실패는 작성 성공 흐름을 막지 않습니다.
    }
  }

  Future<void> _toggleLike() async {
    if (_likeInFlight || _postData == null) return;
    if (!_requireAuthentication()) return;
    final currentCount = (_postData!['likes'] as num?)?.toInt() ?? 0;
    final nextLiked = !_likedByMe;

    setState(() => _likeInFlight = true);
    try {
      final result = await _service.setLike(
        postId: widget.postId,
        liked: nextLiked,
        currentCount: currentCount,
      );
      if (!mounted) return;
      setState(() {
        _likedByMe = result.enabled;
        _postData = {...?_postData, 'likes': result.count};
        _likeInFlight = false;
      });
    } catch (e) {
      debugPrint('도움이돼요 처리 오류: $e');
      if (!mounted) return;
      setState(() => _likeInFlight = false);
      _showSnackBar('도움이돼요 처리에 실패했습니다.');
    }
  }

  Future<void> _toggleNotification() async {
    if (_notificationInFlight || _postData == null) return;
    if (!_requireAuthentication()) return;
    final nextEnabled = !_notificationEnabled;

    setState(() => _notificationInFlight = true);
    try {
      final enabled = await _service.setNotification(
        postId: widget.postId,
        enabled: nextEnabled,
      );
      if (!mounted) return;
      setState(() {
        _notificationEnabled = enabled;
        _notificationInFlight = false;
      });
    } catch (e) {
      debugPrint('알림 처리 오류: $e');
      if (!mounted) return;
      setState(() => _notificationInFlight = false);
      _showSnackBar('알림 설정에 실패했습니다.');
    }
  }

  bool _requireAuthentication() {
    if (ApiClient.isAuthenticated) return true;
    _showSnackBar('로그인이 필요해요.');
    return false;
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
    final replyTarget = _replyTarget;
    final replyBannerHeight = replyTarget == null ? 0.0 : 24.0;
    final bottomBarHeight =
        composerTopPadding +
        replyBannerHeight +
        composerHeight +
        composerBottomGap;
    final inputHint = replyTarget == null
        ? '댓글을 입력하세요.'
        : '${replyTarget.author}님에게 답글 입력';

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
              right: 0,
              height: topOffset,
              child: const ColoredBox(color: Colors.white),
            ),
            Positioned(
              left: 0,
              top: topOffset,
              right: 0,
              height: 48.878,
              child: _PostHeader(onBack: goBack),
            ),
            Positioned(
              left: 0,
              top: topOffset + 48.878,
              right: 0,
              bottom: 0,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : _hasError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            color: CommunityPostDetailScreen.muted,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '게시글을 불러오지 못했어요',
                            style: TextStyle(
                              color: CommunityPostDetailScreen.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '네트워크 상태를 확인하고 다시 시도해주세요',
                            style: TextStyle(
                              color: CommunityPostDetailScreen.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _fetchDetail,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : _postData == null
                  ? const Center(child: Text('게시글을 찾을 수 없습니다.'))
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        CommunityPostDetailScreen.contentLeft,
                        15.99,
                        CommunityPostDetailScreen.contentRight,
                        bottomBarHeight + 24,
                      ),
                      children: [
                        _PostCard(
                          postData: _postData,
                          likedByMe: _likedByMe,
                          notificationEnabled: _notificationEnabled,
                          likeInFlight: _likeInFlight,
                          notificationInFlight: _notificationInFlight,
                          onLikeTap: _toggleLike,
                          onNotifyTap: _toggleNotification,
                        ),
                        const SizedBox(height: 14.66),
                        _buildCommentSection(),
                      ],
                    ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (replyTarget != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${replyTarget.author}님에게 답글',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CommunityPostDetailScreen.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyTarget = null),
                              behavior: HitTestBehavior.opaque,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: CommunityPostDetailScreen.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: composerHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      CommunityPostDetailScreen.commentSurface,
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
                                          selectionHandleColor:
                                              Colors.transparent,
                                        ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    cursorColor: CommunityPostDetailScreen.blue,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    enabled: !_isSubmitting,
                                    style: const TextStyle(
                                      color: CommunityPostDetailScreen.ink,
                                      fontFamily:
                                          CommunityPostDetailScreen.fontFamily,
                                      fontFamilyFallback:
                                          CommunityPostDetailScreen
                                              .fontFallback,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      height: 1.5,
                                    ),
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      isCollapsed: true,
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      hintText: inputHint,
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontFamily: CommunityPostDetailScreen
                                            .fontFamily,
                                        fontFamilyFallback:
                                            CommunityPostDetailScreen
                                                .fontFallback,
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
                              onPressed: _isSubmitting ? null : _submitComment,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: CommunityPostDetailScreen.blue,
                                disabledBackgroundColor:
                                    CommunityPostDetailScreen.muted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            left: AppSizes.horizontalPadding,
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
  const _PostCard({
    required this.postData,
    required this.likedByMe,
    required this.notificationEnabled,
    required this.likeInFlight,
    required this.notificationInFlight,
    required this.onLikeTap,
    required this.onNotifyTap,
  });

  final Map<String, dynamic>? postData;
  final bool likedByMe;
  final bool notificationEnabled;
  final bool likeInFlight;
  final bool notificationInFlight;
  final VoidCallback onLikeTap;
  final VoidCallback onNotifyTap;

  @override
  Widget build(BuildContext context) {
    if (postData == null) return const SizedBox.shrink();

    final String title = postData!['title']?.toString() ?? '';
    final String author = postData!['author']?.toString() ?? '알 수 없음';
    final String location = postData!['location']?.toString() ?? '알 수 없음';
    final String createdAt = postData!['createdAt']?.toString() ?? '';
    final String rawStatus = postData!['status']?.toString() ?? 'PENDING';
    final int likes = (postData!['likes'] as num?)?.toInt() ?? 0;
    final int comments = (postData!['comments'] as num?)?.toInt() ?? 0;

    final String storeName = postData!['storeName']?.toString() ?? '';
    final String address = postData!['address']?.toString() ?? '';
    final String phoneNumber = postData!['phoneNumber']?.toString() ?? '';
    final String menu1 = postData!['menu1']?.toString() ?? '';
    final String price1 = postData!['price1']?.toString() ?? '';
    final String menu2 = postData!['menu2']?.toString() ?? '';
    final String price2 = postData!['price2']?.toString() ?? '';
    final String menu3 = postData!['menu3']?.toString() ?? '';
    final String price3 = postData!['price3']?.toString() ?? '';
    final String menu4 = postData!['menu4']?.toString() ?? '';
    final String price4 = postData!['price4']?.toString() ?? '';
    final bool visitedRecently = postData!['visitedRecently'] == true;
    final bool checkedMenuPrice = postData!['checkedMenuPrice'] == true;
    final List<dynamic> imageUrls = postData!['imageUrls'] ?? [];

    final String authorInitial = author.isNotEmpty ? author[0] : '알';
    final Color avatarBg = rawStatus.toUpperCase() == 'PENDING'
        ? CommunityPostDetailScreen.softBlue
        : CommunityPostDetailScreen.softOrange;
    final Color avatarText = rawStatus.toUpperCase() == 'PENDING'
        ? CommunityPostDetailScreen.blue
        : CommunityPostDetailScreen.orange;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.horizontalPadding,
        AppSizes.itemSpacing,
        AppSizes.horizontalPadding,
        15,
      ),
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
            children: [
              _AvatarBadge(
                label: authorInitial,
                backgroundColor: avatarBg,
                textColor: avatarText,
                size: 31.989,
                fontSize: 13,
              ),
              const SizedBox(width: 7.997),
              Expanded(
                child: _AuthorMeta(
                  author: author,
                  date: createdAt,
                  location: location,
                ),
              ),
              _PostStatusBadge(status: rawStatus),
            ],
          ),
          const SizedBox(height: 11.989),
          Text(
            title,
            style: const TextStyle(
              color: CommunityPostDetailScreen.ink,
              fontFamily: CommunityPostDetailScreen.fontFamily,
              fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8.99),
          if (imageUrls.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrls.first.toString(),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _NoImagePlaceholder(),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const _NoImagePlaceholder(),
            const SizedBox(height: 10),
          ],

          if (storeName.isNotEmpty) ...[
            const Divider(color: CommunityPostDetailScreen.border, height: 24),
            Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: CommunityPostDetailScreen.blue,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  '제보 매장 정보',
                  style: TextStyle(
                    color: CommunityPostDetailScreen.ink,
                    fontFamily: CommunityPostDetailScreen.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              storeName,
              style: const TextStyle(
                color: CommunityPostDetailScreen.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: CommunityPostDetailScreen.muted,
                  fontSize: 11,
                ),
              ),
            ],
            if (phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '전화번호: $phoneNumber',
                style: const TextStyle(
                  color: CommunityPostDetailScreen.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ],

          if (menu1.isNotEmpty) ...[
            const Divider(color: CommunityPostDetailScreen.border, height: 24),
            Row(
              children: [
                const Icon(
                  Icons.sell_outlined,
                  color: CommunityPostDetailScreen.orange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  '제보 가격 정보',
                  style: TextStyle(
                    color: CommunityPostDetailScreen.ink,
                    fontFamily: CommunityPostDetailScreen.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMenuRow(menu1, price1),
            if (menu2.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildMenuRow(menu2, price2),
            ],
            if (menu3.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildMenuRow(menu3, price3),
            ],
            if (menu4.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildMenuRow(menu4, price4),
            ],
          ],

          if (visitedRecently || checkedMenuPrice) ...[
            const Divider(color: CommunityPostDetailScreen.border, height: 24),
            Row(
              children: [
                if (visitedRecently) ...[
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '최근 방문',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (checkedMenuPrice) ...[
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '메뉴판 직접 확인',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],

          const Divider(color: CommunityPostDetailScreen.border, height: 24),
          Row(
            children: [
              _PostMetric(
                icon: likedByMe
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                label: '도움이 돼요 $likes',
                active: likedByMe,
                busy: likeInFlight,
                onTap: onLikeTap,
              ),
              const SizedBox(width: AppSizes.itemSpacing),
              _PostMetric(
                icon: Icons.mode_comment_outlined,
                label: '댓글 $comments',
              ),
              const Spacer(),
              GestureDetector(
                onTap: notificationInFlight ? null : onNotifyTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      notificationEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: 12,
                      color: CommunityPostDetailScreen.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notificationEnabled ? '알림 중' : '알림',
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

  Widget _buildMenuRow(String name, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: CommunityPostDetailScreen.ink,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: CommunityPostDetailScreen.blue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AuthorMeta extends StatelessWidget {
  const _AuthorMeta({
    required this.author,
    required this.date,
    required this.location,
  });

  final String author;
  final String date;
  final String location;

  @override
  Widget build(BuildContext context) {
    final displayDate = date.isNotEmpty && date.length >= 10
        ? date.substring(0, 10).replaceAll('-', '.')
        : date;
    final metaText = displayDate.isNotEmpty
        ? '$displayDate · $location'
        : location;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          author,
          style: const TextStyle(
            color: CommunityPostDetailScreen.ink,
            fontFamily: CommunityPostDetailScreen.fontFamily,
            fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        Text(
          metaText,
          style: const TextStyle(
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

class _NoImagePlaceholder extends StatelessWidget {
  const _NoImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CommunityPostDetailScreen.commentSurface,
        border: Border.all(color: CommunityPostDetailScreen.border),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: CommunityPostDetailScreen.muted,
            size: 24,
          ),
          SizedBox(height: 6),
          Text(
            '이미지 없음',
            style: TextStyle(
              color: CommunityPostDetailScreen.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostStatusBadge extends StatelessWidget {
  const _PostStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String label = switch (status.toUpperCase()) {
      'APPROVED' => '승인 완료',
      'PENDING' => '검토 중',
      _ => '가격 변동',
    };

    final Color color = switch (status.toUpperCase()) {
      'APPROVED' => const Color(0xFF10B981),
      'PENDING' => CommunityPostDetailScreen.orange,
      _ => CommunityPostDetailScreen.orange,
    };

    final Color bgColor = switch (status.toUpperCase()) {
      'APPROVED' => const Color(0xFFE8F8F1),
      'PENDING' => CommunityPostDetailScreen.softOrange,
      _ => CommunityPostDetailScreen.softOrange,
    };

    return Container(
      width: 70.497,
      height: 20.994,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
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
  const _PostMetric({
    required this.icon,
    required this.label,
    this.active = false,
    this.busy = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? CommunityPostDetailScreen.blue
        : CommunityPostDetailScreen.muted;

    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (busy)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: CommunityPostDetailScreen.blue,
              ),
            )
          else
            Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: CommunityPostDetailScreen.fontFamily,
              fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.onReply});

  final CommunityComment comment;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarBadge(
                label: comment.initial,
                backgroundColor: CommunityPostDetailScreen.softBlue,
                textColor: CommunityPostDetailScreen.blue,
                size: 28,
                fontSize: 12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        ),
                        if (comment.createdAt.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatCommentDate(comment.createdAt),
                            style: const TextStyle(
                              color: CommunityPostDetailScreen.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comment.content,
                      style: const TextStyle(
                        color: CommunityPostDetailScreen.ink,
                        fontFamily: CommunityPostDetailScreen.fontFamily,
                        fontFamilyFallback:
                            CommunityPostDetailScreen.fontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: const Text(
                        '답글',
                        style: TextStyle(
                          color: CommunityPostDetailScreen.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...comment.replies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(left: 36, top: 6),
                child: _ReplyCard(reply: reply),
              ),
            ),
          ] else if (comment.replyCount > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                '답글 ${comment.replyCount}개',
                style: const TextStyle(
                  color: CommunityPostDetailScreen.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final CommunityComment reply;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvatarBadge(
          label: reply.initial,
          backgroundColor: CommunityPostDetailScreen.softOrange,
          textColor: CommunityPostDetailScreen.orange,
          size: 24,
          fontSize: 10,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      reply.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CommunityPostDetailScreen.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (reply.createdAt.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      _formatCommentDate(reply.createdAt),
                      style: const TextStyle(
                        color: CommunityPostDetailScreen.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                reply.content,
                style: const TextStyle(
                  color: CommunityPostDetailScreen.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentEmptyState extends StatelessWidget {
  const _CommentEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: CommunityPostDetailScreen.commentSurface,
        border: Border.all(
          color: CommunityPostDetailScreen.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: CommunityPostDetailScreen.muted,
          fontFamily: CommunityPostDetailScreen.fontFamily,
          fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }
}

bool? _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
  }
  return null;
}

String _formatCommentDate(String value) {
  if (value.length >= 10) return value.substring(0, 10).replaceAll('-', '.');
  return value;
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

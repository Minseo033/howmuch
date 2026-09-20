import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/community_service.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';

@visibleForTesting
List<String> communityPostImageUrls(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .where((value) => value != null)
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

class CommunityPostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const CommunityPostDetailScreen({super.key, this.postId = ''});

  static const blue = Color(0xFF315F52);
  static const orange = Color(0xFFA76546);
  static const ink = Color(0xFF1F342D);
  static const black = Color(0xFF1F342D);
  static const muted = Color(0xFF707A70);
  static const border = Color(0xFFD9DDD2);
  static const surface = Color(0xFFF7F5EE);
  static const commentSurface = Color(0xFFF7F5EE);
  static const softBlue = Color(0xFFE7EEE7);
  static const softOrange = Color(0xFFF6EDE4);
  static const contentLeft = 20.0;
  static const contentRight = 20.0;
  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  ConsumerState<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends ConsumerState<CommunityPostDetailScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final CommunityService _service = const CommunityService();

  bool _isLoading = false;
  bool _hasError = false;
  bool _commentsLoading = false;
  bool _commentsUnavailable = false;
  bool _isSubmitting = false;
  bool _likeInFlight = false;
  bool _notificationInFlight = false;
  bool _liveRefreshInFlight = false;
  bool _likedByMe = false;
  bool _notificationEnabled = false;
  Map<String, dynamic>? _postData;
  List<CommunityComment> _comments = const [];
  CommunityComment? _replyTarget;
  final Set<String> _expandedReplyIds = <String>{};
  final Set<String> _replyLoadingIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDetail();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLiveData();
    }
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
    if (widget.postId.isEmpty || _commentsLoading || _liveRefreshInFlight) {
      return;
    }
    setState(() {
      _commentsLoading = true;
      _commentsUnavailable = false;
    });

    try {
      final comments = await _service.fetchComments(widget.postId);
      final previousById = {for (final item in _comments) item.id: item};
      final commentsWithLoadedReplies = comments.map((comment) {
        final previous = previousById[comment.id];
        if (previous == null || previous.replies.isEmpty) return comment;
        return comment.copyWith(replies: previous.replies);
      }).toList();
      if (!mounted) return;
      setState(() {
        _comments = commentsWithLoadedReplies;
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshLiveData() async {
    if (!mounted ||
        widget.postId.isEmpty ||
        _isLoading ||
        _commentsLoading ||
        _isSubmitting ||
        _likeInFlight ||
        _notificationInFlight ||
        _liveRefreshInFlight) {
      return;
    }

    _liveRefreshInFlight = true;
    try {
      final detailFuture = _service.fetchFeedDetail(widget.postId);
      final commentsFuture = _service.fetchComments(widget.postId);
      final decoded = await detailFuture;
      final comments = await commentsFuture;
      final previousById = {for (final item in _comments) item.id: item};
      final commentsWithLoadedReplies = comments.map((comment) {
        final previous = previousById[comment.id];
        if (previous == null || previous.replies.isEmpty) return comment;
        return comment.copyWith(replies: previous.replies);
      }).toList();
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
        _comments = commentsWithLoadedReplies;
        _commentsUnavailable = false;
      });
    } catch (e) {
      debugPrint('게시글 갱신 오류: $e');
    } finally {
      _liveRefreshInFlight = false;
    }
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
            _expandedReplyIds.add(replyTarget.id);
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

  Future<void> _toggleReplies(CommunityComment comment) async {
    if (_expandedReplyIds.contains(comment.id)) {
      setState(() => _expandedReplyIds.remove(comment.id));
      return;
    }
    if (comment.replies.isNotEmpty) {
      setState(() => _expandedReplyIds.add(comment.id));
      return;
    }
    if (_replyLoadingIds.contains(comment.id)) return;

    setState(() => _replyLoadingIds.add(comment.id));
    try {
      final replies = await _service.fetchReplies(comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.map((item) {
          return item.id == comment.id ? item.copyWith(replies: replies) : item;
        }).toList();
        _replyLoadingIds.remove(comment.id);
        _expandedReplyIds.add(comment.id);
      });
    } catch (e) {
      debugPrint('답글 목록 조회 오류: $e');
      if (!mounted) return;
      setState(() => _replyLoadingIds.remove(comment.id));
      _showSnackBar('답글을 불러오지 못했어요. 다시 시도해주세요.');
    }
  }

  Widget _buildCommentSection({
    required String myProfileImageUrl,
    required String myNickname,
  }) {
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
                repliesExpanded: _expandedReplyIds.contains(comment.id),
                repliesLoading: _replyLoadingIds.contains(comment.id),
                onToggleReplies: () => _toggleReplies(comment),
                myProfileImageUrl: myProfileImageUrl,
                myNickname: myNickname,
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
      await _refreshDetailCounts();
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
      await _refreshDetailCounts();
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
    final profile = ref.watch(userProfileProvider);
    final auth = ref.watch(authStateProvider);
    final myProfileImageUrl = profile.profileImageUrl.isNotEmpty
        ? profile.profileImageUrl
        : auth.profileImageUrl;
    final myNickname = profile.nickname;
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom > 24 ? safePadding.bottom : 24.0;
    final designScale = FigmaMobileCanvas.designScaleFor(context);
    final keyboardInset = designScale <= 0
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom / designScale;
    final composerBottomGap = keyboardInset > 0
        ? keyboardInset
        : (bottomOffset + 12);
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
        backgroundColor: const Color(0xFFF7F5EE),
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
              height: HowmuchTopBar.height,
              child: _PostHeader(onBack: goBack),
            ),
            Positioned(
              left: 0,
              top: topOffset + HowmuchTopBar.height,
              right: 0,
              bottom: 0,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF315F52),
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
                  : RefreshIndicator(
                      onRefresh: _refreshLiveData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
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
                            myProfileImageUrl: myProfileImageUrl,
                            myNickname: myNickname,
                          ),
                          const SizedBox(height: 14.66),
                          _buildCommentSection(
                            myProfileImageUrl: myProfileImageUrl,
                            myNickname: myNickname,
                          ),
                        ],
                      ),
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
                                        color: Color(0xFFA8AEA4),
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
    return HowmuchTopBar(title: '게시글 상세', onBack: onBack);
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
    this.myProfileImageUrl,
    this.myNickname,
  });

  final Map<String, dynamic>? postData;
  final bool likedByMe;
  final bool notificationEnabled;
  final bool likeInFlight;
  final bool notificationInFlight;
  final VoidCallback onLikeTap;
  final VoidCallback onNotifyTap;
  final String? myProfileImageUrl;
  final String? myNickname;

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
    final String? serverAuthorImg =
        postData!['authorProfileImageUrl']?.toString() ??
        postData!['profileImageUrl']?.toString();
    final String? authorProfileImageUrl =
        (serverAuthorImg != null && serverAuthorImg.isNotEmpty)
        ? serverAuthorImg
        : ((myNickname != null &&
                  myNickname!.isNotEmpty &&
                  author == myNickname &&
                  myProfileImageUrl != null &&
                  myProfileImageUrl!.isNotEmpty)
              ? myProfileImageUrl
              : null);

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
    final Object? imageUrls = postData!['imageUrls'];

    final String authorInitial = author.isNotEmpty ? author[0] : '알';
    final Color avatarBg = rawStatus.toUpperCase() == 'PENDING'
        ? CommunityPostDetailScreen.softBlue
        : CommunityPostDetailScreen.softOrange;
    final Color avatarText = rawStatus.toUpperCase() == 'PENDING'
        ? CommunityPostDetailScreen.blue
        : CommunityPostDetailScreen.orange;

    String displayStoreTitle = storeName;
    String displaySubhead = '';

    if (displayStoreTitle.isEmpty) {
      final tokens = title
          .trim()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.isNotEmpty) {
        if (tokens.length >= 2 && RegExp(r'^\d+원?$').hasMatch(tokens.last)) {
          tokens.removeLast();
        }
        displayStoreTitle = tokens.join(' ');
      } else {
        displayStoreTitle = title;
      }
    }

    if (menu1.isNotEmpty && price1.isNotEmpty) {
      displaySubhead = '$menu1 · ${_formatPriceDisplay(price1)}';
    } else if (menu1.isNotEmpty) {
      displaySubhead = menu1;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.horizontalPadding,
        AppSizes.itemSpacing,
        AppSizes.horizontalPadding,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF2EC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
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
                imageUrl: authorProfileImageUrl,
                size: 38,
                fontSize: 15,
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          Text(
            displayStoreTitle,
            style: const TextStyle(
              color: CommunityPostDetailScreen.ink,
              fontFamily: CommunityPostDetailScreen.fontFamily,
              fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.3,
            ),
          ),
          if (displaySubhead.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              displaySubhead,
              style: const TextStyle(
                fontFamily: CommunityPostDetailScreen.fontFamily,
                fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: CommunityPostDetailScreen.blue,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (communityPostImageUrls(imageUrls).isNotEmpty) ...[
            _PostImageGallery(imageUrls: communityPostImageUrls(imageUrls)),
            const SizedBox(height: 14),
          ],

          if (storeName.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFAF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7EEE7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EEE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: CommunityPostDetailScreen.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: const TextStyle(
                            color: CommunityPostDetailScreen.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            address,
                            style: const TextStyle(
                              color: CommunityPostDetailScreen.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (phoneNumber.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            phoneNumber,
                            style: const TextStyle(
                              color: Color(0xFFA8AEA4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (menu1.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFAF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7EEE7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: CommunityPostDetailScreen.orange,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
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
                  const SizedBox(height: 10),
                  _buildMenuRow(menu1, price1),
                  if (menu2.isNotEmpty) ...[
                    const Divider(color: Color(0xFFE7EEE7), height: 16),
                    _buildMenuRow(menu2, price2),
                  ],
                  if (menu3.isNotEmpty) ...[
                    const Divider(color: Color(0xFFE7EEE7), height: 16),
                    _buildMenuRow(menu3, price3),
                  ],
                  if (menu4.isNotEmpty) ...[
                    const Divider(color: Color(0xFFE7EEE7), height: 16),
                    _buildMenuRow(menu4, price4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (visitedRecently || checkedMenuPrice) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (visitedRecently)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF5EF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE7F0E8)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF39705C),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '최근 방문 인증',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF39705C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (checkedMenuPrice)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF5EF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE7F0E8)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF39705C),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '메뉴판 직접 확인',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF39705C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const Divider(color: Color(0xFFEEF2EC), height: 16),
          const SizedBox(height: 4),
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
                icon: Icons.chat_bubble_outline_rounded,
                label: '댓글 $comments',
              ),
              const Spacer(),
              GestureDetector(
                onTap: notificationInFlight ? null : onNotifyTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: notificationEnabled
                        ? const Color(0xFFE7EEE7)
                        : const Color(0xFFFBFAF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: notificationEnabled
                          ? const Color(0xFFE0EBE1)
                          : const Color(0xFFD9DDD2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        notificationEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: 14,
                        color: notificationEnabled
                            ? CommunityPostDetailScreen.blue
                            : CommunityPostDetailScreen.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notificationEnabled ? '알림 켜짐' : '새 댓글 알림',
                        style: TextStyle(
                          color: notificationEnabled
                              ? CommunityPostDetailScreen.blue
                              : CommunityPostDetailScreen.muted,
                          fontFamily: CommunityPostDetailScreen.fontFamily,
                          fontFamilyFallback:
                              CommunityPostDetailScreen.fontFallback,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow(String name, String price) {
    final formattedPrice = _formatPriceDisplay(price);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFF46564D),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formattedPrice,
          style: const TextStyle(
            color: CommunityPostDetailScreen.blue,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _PostImageGallery extends StatefulWidget {
  const _PostImageGallery({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_PostImageGallery> createState() => _PostImageGalleryState();
}

class _PostImageGalleryState extends State<_PostImageGallery> {
  int _currentPage = 0;

  void _openFullScreen(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogContext) {
        return _FullScreenImageViewer(
          imageUrls: widget.imageUrls,
          initialIndex: initialIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();
    final count = widget.imageUrls.length;
    return Semantics(
      label: '게시글 사진 갤러리, ${_currentPage + 1} / $count',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(
              height: 240,
              width: double.infinity,
              child: PageView.builder(
                itemCount: count,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => _openFullScreen(context, index),
                  child: Container(
                    color: const Color(0xFF1F342D),
                    alignment: Alignment.center,
                    child: Image.network(
                      widget.imageUrls[index],
                      fit: BoxFit.contain,
                      semanticLabel: '게시글 사진 ${index + 1} / $count',
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFEEF2EC),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFFA8AEA4),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 좌측 하단: 클릭 시 크게보기 힌트
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 3),
                    Text(
                      '크게보기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (count > 1)
              Positioned(
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Text(
                      '${_currentPage + 1} / $count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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

/// 사진 클릭 시 화면 가득 띄워주는 풀스크린 확대 뷰어
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 줌 가능한 이미지 PageView
          PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (page) => setState(() => _currentIndex = page),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. 상단 헤더 (닫기 버튼 + 페이지 카운터)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (count > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / $count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
    final displayDate = _formatDetailRelativeDate(date);
    final metaText = displayDate.isNotEmpty
        ? '$location · $displayDate'
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        Text(
          metaText,
          style: const TextStyle(
            color: CommunityPostDetailScreen.muted,
            fontFamily: CommunityPostDetailScreen.fontFamily,
            fontFamilyFallback: CommunityPostDetailScreen.fontFallback,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PostStatusBadge extends StatelessWidget {
  const _PostStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status.toUpperCase() == 'APPROVED') {
      return const SizedBox.shrink();
    }

    final String label = switch (status.toUpperCase()) {
      'PENDING' => '검토 중',
      _ => '가격 변동',
    };

    final Color color = switch (status.toUpperCase()) {
      'PENDING' => const Color(0xFF9B6541),
      _ => CommunityPostDetailScreen.orange,
    };

    final Color bgColor = switch (status.toUpperCase()) {
      'PENDING' => const Color(0xFFF6EDE4),
      _ => const Color(0xFFF6EDE4),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: status.toUpperCase() == 'PENDING'
              ? const Color(0xFFE7CDAF)
              : const Color(0xFFF6EDE4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: CommunityPostDetailScreen.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatPriceDisplay(String price) {
  if (price.isEmpty) return '';
  final pNum = int.tryParse(price.replaceAll(RegExp(r'[^0-9]'), ''));
  if (pNum != null) {
    return '${_formatNumberComma(pNum)}원';
  }
  return price.endsWith('원') ? price : '$price원';
}

String _formatNumberComma(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

String _formatDetailRelativeDate(String rawDate) {
  if (rawDate.isEmpty) return '';
  try {
    final parsed = DateTime.parse(rawDate).toLocal();
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return rawDate.length >= 10
        ? rawDate.substring(0, 10).replaceAll('-', '.')
        : rawDate;
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
  const _CommentCard({
    required this.comment,
    required this.onReply,
    required this.repliesExpanded,
    required this.repliesLoading,
    required this.onToggleReplies,
    this.myProfileImageUrl,
    this.myNickname,
  });

  final CommunityComment comment;
  final VoidCallback onReply;
  final bool repliesExpanded;
  final bool repliesLoading;
  final VoidCallback onToggleReplies;
  final String? myProfileImageUrl;
  final String? myNickname;

  @override
  Widget build(BuildContext context) {
    final String? commentImg =
        (comment.authorProfileImageUrl != null &&
            comment.authorProfileImageUrl!.isNotEmpty)
        ? comment.authorProfileImageUrl
        : ((comment.isMine ||
                  (myNickname != null &&
                      myNickname!.isNotEmpty &&
                      comment.author == myNickname))
              ? myProfileImageUrl
              : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CommunityPostDetailScreen.commentSurface,
        border: Border.all(
          color: CommunityPostDetailScreen.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(22),
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
                imageUrl: commentImg,
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
          if (repliesExpanded && comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...comment.replies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(left: 36, top: 6),
                child: _ReplyCard(
                  reply: reply,
                  myProfileImageUrl: myProfileImageUrl,
                  myNickname: myNickname,
                ),
              ),
            ),
          ],
          if (comment.replyCount > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Semantics(
                button: true,
                label: repliesExpanded
                    ? '답글 ${comment.replyCount}개 접기'
                    : '답글 ${comment.replyCount}개 보기',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: repliesLoading ? null : onToggleReplies,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 2,
                      ),
                      child: repliesLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              repliesExpanded
                                  ? '답글 접기'
                                  : '답글 ${comment.replyCount}개 보기',
                              style: const TextStyle(
                                color: CommunityPostDetailScreen.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
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
  const _ReplyCard({
    required this.reply,
    this.myProfileImageUrl,
    this.myNickname,
  });

  final CommunityComment reply;
  final String? myProfileImageUrl;
  final String? myNickname;

  @override
  Widget build(BuildContext context) {
    final String? replyImg =
        (reply.authorProfileImageUrl != null &&
            reply.authorProfileImageUrl!.isNotEmpty)
        ? reply.authorProfileImageUrl
        : ((reply.isMine ||
                  (myNickname != null &&
                      myNickname!.isNotEmpty &&
                      reply.author == myNickname))
              ? myProfileImageUrl
              : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvatarBadge(
          label: reply.initial,
          backgroundColor: CommunityPostDetailScreen.softOrange,
          textColor: CommunityPostDetailScreen.orange,
          imageUrl: replyImg,
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
        borderRadius: BorderRadius.circular(22),
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
  if (value.isEmpty) return '';
  try {
    final parsed = DateTime.parse(value).toLocal();
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inSeconds < 45) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return value.length >= 10
        ? value.substring(0, 10).replaceAll('-', '.')
        : value;
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.size,
    required this.fontSize,
    this.imageUrl,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double size;
  final double fontSize;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        imageUrl != null &&
        imageUrl!.isNotEmpty &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    if (hasImage) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD9DDD2), width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) => Center(
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
          ),
        ),
      );
    }

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

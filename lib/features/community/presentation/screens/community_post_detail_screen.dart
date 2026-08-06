import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:howmuch/core/network/api_client.dart';

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
  bool _isLoading = false;
  Map<String, dynamic>? _postData;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (widget.postId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        ApiClient.uri('/api/community/feed/${widget.postId}'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _postData = decoded;
          _isLoading = false;
        });
      } else {
        _loadFallbackData();
      }
    } catch (e) {
      debugPrint('게시글 상세 조회 오류: $e');
      _loadFallbackData();
    }
  }

  void _loadFallbackData() {
    setState(() {
      if (widget.postId == 'mock-1') {
        _postData = {
          'id': 'mock-1',
          'location': '합정동',
          'title': '골목밥상 제육덮밥 6,000원',
          'author': '절약왕민수',
          'likes': 32,
          'comments': 8,
          'status': 'APPROVED',
          'createdAt': '2026.05.10',
          'storeName': '골목밥상 합정점',
          'address': '서울시 마포구 독막로 456',
          'phoneNumber': '02-987-6543',
          'industry': '한식',
          'menu1': '제육덮밥',
          'price1': '6,000원',
          'menu2': '김치찌개',
          'price2': '6,500원',
          'menu3': '',
          'price3': '',
          'menu4': '',
          'price4': '',
          'visitedRecently': true,
          'checkedMenuPrice': false,
          'imageUrls': [],
        };
      } else if (widget.postId == 'mock-3') {
        _postData = {
          'id': 'mock-3',
          'location': '역삼동',
          'title': '착한미용실 남성컷 8,000원',
          'author': '동네탐험가',
          'likes': 21,
          'comments': 6,
          'status': 'PENDING',
          'createdAt': '2026.05.15',
          'storeName': '착한미용실 역삼점',
          'address': '서울시 강남구 역삼로 789',
          'phoneNumber': '02-456-7890',
          'industry': '미용',
          'menu1': '남성컷',
          'price1': '8,000원',
          'menu2': '여성컷',
          'price2': '12,000원',
          'menu3': '',
          'price3': '',
          'menu4': '',
          'price4': '',
          'visitedRecently': false,
          'checkedMenuPrice': true,
          'imageUrls': [],
        };
      } else {
        _postData = {
          'id': widget.postId,
          'location': '역삼동',
          'title': '동네카페 아메리카노 2,500원으로 가격 인상됐어요',
          'author': '강남직장인',
          'likes': 12,
          'comments': 2,
          'status': 'NEEDS_EDIT',
          'createdAt': '2026.05.14',
          'storeName': '동네카페 역삼점',
          'address': '서울시 강남구 테헤란로 123',
          'phoneNumber': '02-123-4567',
          'industry': '카페',
          'menu1': '아메리카노',
          'price1': '2,500원',
          'menu2': '카페라떼',
          'price2': '3,500원',
          'menu3': '',
          'price3': '',
          'menu4': '',
          'price4': '',
          'visitedRecently': true,
          'checkedMenuPrice': true,
          'imageUrls': [],
        };
      }
      _isLoading = false;
    });
  }

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
                              notifyEnabled: _notifyEnabled,
                              onNotifyTap: () => setState(
                                  () => _notifyEnabled = !_notifyEnabled),
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
    required this.notifyEnabled,
    required this.onNotifyTap,
  });

  final Map<String, dynamic>? postData;
  final bool notifyEnabled;
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
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
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
            const SizedBox(height: 10),
          ],

          if (storeName.isNotEmpty) ...[
            const Divider(color: CommunityPostDetailScreen.border, height: 24),
            Row(
              children: [
                const Icon(Icons.storefront_rounded, color: CommunityPostDetailScreen.blue, size: 16),
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
                const Icon(Icons.sell_outlined, color: CommunityPostDetailScreen.orange, size: 14),
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
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 14),
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
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 14),
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
                icon: Icons.thumb_up_alt_outlined,
                label: '도움이 돼요 $likes',
              ),
              const SizedBox(width: AppSizes.itemSpacing),
              _PostMetric(
                icon: Icons.mode_comment_outlined,
                label: '댓글 $comments',
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
    final displayDate = date.isNotEmpty && date.length >= 10 ? date.substring(0, 10).replaceAll('-', '.') : date;
    final metaText = displayDate.isNotEmpty ? '$displayDate · $location' : location;

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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
                        const SizedBox(width: AppSizes.smallSpacing),
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

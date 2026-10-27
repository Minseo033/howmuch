import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_text_formatter.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/store/store_catalog_loader.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/recommendation_radius_button.dart';
import 'package:geolocator/geolocator.dart';

/// Separates numbered store recommendations from the free-form explanation.
/// Non-list AI replies keep the original text untouched.
@visibleForTesting
(String, List<(String, String)>)? splitAiRecommendationText(String text) {
  final pattern = RegExp(r'^\s*\d+[.)]\s+(.+?)\s+[—–-]\s+(.+?)\s*$');
  final intro = <String>[];
  final stores = <(String, String)>[];
  String plainText(String value) => parseAiChatDisplayText(
    value,
  ).map((segment) => segment.text).join().trim();
  for (final line in text.split('\n')) {
    final match = pattern.firstMatch(line);
    if (match == null) {
      intro.add(line);
    } else {
      stores.add((plainText(match.group(1)!), plainText(match.group(2)!)));
    }
  }
  if (stores.length < 2) return null;
  final description = intro.join('\n').trim();
  return (description.isEmpty ? '추천 매장을 확인해보세요.' : description, stores);
}

class AiRecommendChatScreen extends ConsumerStatefulWidget {
  const AiRecommendChatScreen({super.key});

  @override
  ConsumerState<AiRecommendChatScreen> createState() =>
      _AiRecommendChatScreenState();
}

final aiChatHistoryProvider = StateProvider<List<_ChatMessage>>((ref) {
  ref.watch(
    authStateProvider.select(
      (auth) => (auth.isLoggedIn, auth.firebaseUid, auth.sessionToken),
    ),
  );
  return [];
});

/// Non-null while an AI reply for the current conversation is pending. It
/// outlives the chat screen, so a reopened screen still shows the typing
/// indicator and blocks a second question until the first answer lands.
/// Resetting the conversation (or switching accounts) clears it.
final aiChatPendingRequestProvider = StateProvider<Object?>((ref) {
  ref.watch(aiChatHistoryProvider.notifier);
  return null;
});

/// Same limit as the server (AiController rejects longer messages). Counted
/// in UTF-16 code units like Java's String.length().
const aiChatMaxMessageLength = 1000;

@visibleForTesting
Future<List<Store>> loadAiFallbackCandidates({
  StoreCatalogLoader catalogLoader = loadStoreCatalog,
}) async {
  final catalog = HomeMapScreen.globalSearchCatalog;
  if (catalog.isNotEmpty) return catalog;

  // The map already holds a small, server-validated viewport cache in the
  // common flow. Use it immediately instead of blocking the recovery path on
  // the nationwide catalog (currently several MB on web/Safari).
  final mapStores = HomeMapScreen.globalAllStores
      .where((store) => store.hasValidCoordinates)
      .toList(growable: false);
  if (mapStores.isNotEmpty) return mapStores;

  try {
    final loaded = await catalogLoader();
    HomeMapScreen.setSearchCatalog(loaded);
    return loaded;
  } catch (error) {
    debugPrint('AI 로컬 추천용 전체 매장 목록 로드 실패: $error');
    return HomeMapScreen.globalAllStores;
  }
}

class _AiRecommendChatScreenState extends ConsumerState<AiRecommendChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = [
    _QuickPrompt(
      icon: Icons.account_balance_wallet_outlined,
      label: '10,000원 이하 점심',
    ),
    _QuickPrompt(icon: Icons.umbrella_outlined, label: '비 오는 날 국물'),
    _QuickPrompt(icon: Icons.restaurant_outlined, label: '혼밥 분식 추천'),
    _QuickPrompt(icon: Icons.location_on_outlined, label: '근처 오후 코스'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // A reopened conversation (possibly with a reply that arrived while the
    // screen was closed) starts at the latest message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(aiChatHistoryProvider).isEmpty) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setPrompt(String prompt) {
    setState(() {
      _controller.text = prompt;
      _controller.selection = TextSelection.collapsed(offset: prompt.length);
    });
  }

  /// Prefer the small viewport cache for an immediate real-store fallback;
  /// only fetch the complete catalog when the chat was opened directly.
  Future<List<Store>> _candidateStoresForFallback() =>
      loadAiFallbackCandidates();

  Future<void> _sendMessage() async {
    if (ref.read(aiChatPendingRequestProvider) != null) return;

    final messageText = _controller.text.trim();
    if (messageText.isEmpty) return;
    if (messageText.length > aiChatMaxMessageLength) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          HowmuchSnackBar(content: Text('메시지는 1000자 이내로 입력해주세요.')),
        );
      return;
    }

    final userMessage = _ChatMessage(text: messageText, isBot: false);
    // Everything the request needs is captured now: the reply must still be
    // recorded if the user leaves this screen while waiting.
    final historyNotifier = ref.read(aiChatHistoryProvider.notifier);
    final pendingNotifier = ref.read(aiChatPendingRequestProvider.notifier);
    final radiusNotifier = ref.read(recommendationRadiusProvider.notifier);
    final aiService = ref.read(aiChatServiceProvider);
    final pendingToken = Object();

    historyNotifier.update((list) => [...list, userMessage]);
    pendingNotifier.state = pendingToken;
    setState(_controller.clear);

    FocusManager.instance.primaryFocus?.unfocus();

    // 💡 최근 대화 내역 추출 (최대 6개, 방금 추가한 본인 메시지 제외)
    final allMessages = historyNotifier.state;
    final previousMessages = allMessages.take(allMessages.length - 1).toList();
    final history = previousMessages
        .skip(previousMessages.length > 6 ? previousMessages.length - 6 : 0)
        .map((m) => {'role': m.isBot ? 'model' : 'user', 'text': m.text})
        .toList();

    try {
      final reply = await _replyTo(
        messageText,
        history: history,
        historyNotifier: historyNotifier,
        radiusNotifier: radiusNotifier,
        aiService: aiService,
      );
      // The conversation outlives this screen; only a reset discards the reply.
      if (reply != null && historyNotifier.mounted) {
        historyNotifier.update((list) => [...list, reply]);
      }
    } catch (error) {
      // Never leave the question unanswered or the composer locked.
      debugPrint('AI 답변 처리 오류: $error');
      if (historyNotifier.mounted) {
        historyNotifier.update(
          (list) => [
            ...list,
            const _ChatMessage(
              text: '답변을 불러오지 못했어요. 잠시 후 다시 질문해주세요.',
              isBot: true,
            ),
          ],
        );
      }
    } finally {
      if (pendingNotifier.mounted &&
          identical(pendingNotifier.state, pendingToken)) {
        pendingNotifier.state = null;
      }
    }
  }

  /// Builds the bot reply for [messageText]. Returns null when the
  /// conversation was reset (or the account changed) while waiting.
  Future<_ChatMessage?> _replyTo(
    String messageText, {
    required List<Map<String, String>> history,
    required StateController<List<_ChatMessage>> historyNotifier,
    required RecommendationRadiusNotifier radiusNotifier,
    required AiChatService aiService,
  }) async {
    // 서버가 실제 매장 정보를 다시 확인할 수 있도록 ID와 현재 위치만 전달합니다.
    var position = HomeMapScreen.globalUserPosition;
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
        HomeMapScreen.globalUserPosition = position;
      } catch (_) {
        /* Missing location is handled without inventing a city. */
      }
    }
    await radiusNotifier.ready;
    // A reset or account switch disposes the conversation; drop this request.
    if (!historyNotifier.mounted || !radiusNotifier.mounted) return null;
    final radiusMeters = radiusNotifier.radiusMeters;
    final nearbyStoreIds = buildNearbyStoreIds(
      stores: HomeMapScreen.globalAllStores,
      lat: position?.latitude,
      lng: position?.longitude,
      limit: 10,
      radiusMeters: radiusMeters,
    );

    // 💡 Gemini API 호출
    final aiReply = await aiService.getGeminiResponse(
      messageText,
      history: history,
      nearbyStoreIds: nearbyStoreIds,
      latitude: position?.latitude,
      longitude: position?.longitude,
      radiusMeters: radiusMeters,
    );
    var botResponse = aiReply.text;
    List<Store> recommendedStores = const [];
    List<RecommendationMenuSelection> menuSelections = const [];
    if (isAiUnavailableResponse(botResponse)) {
      final position = HomeMapScreen.globalUserPosition;
      final candidateStores = await _candidateStoresForFallback();
      final fallbackResult = buildLocalAiFallbackResult(
        stores: candidateStores,
        query: messageText,
        lat: position?.latitude,
        lng: position?.longitude,
        radiusMeters: radiusMeters,
      );
      if (fallbackResult != null) {
        botResponse = fallbackResult.text;
        recommendedStores = fallbackResult.stores;
        menuSelections = fallbackResult.menuSelections;
      } else {
        botResponse = 'AI 연결이 원활하지 않습니다. 지도에서 위치를 확인한 뒤 다시 요청해주세요.';
      }
    } else {
      final candidateStores = HomeMapScreen.globalSearchCatalog.isNotEmpty
          ? HomeMapScreen.globalSearchCatalog
          : HomeMapScreen.globalAllStores;
      final verified = resolveVerifiedAiRecommendations(
        recommendations: aiReply.recommendations,
        catalog: candidateStores,
        latitude: position?.latitude,
        longitude: position?.longitude,
        radiusMeters: radiusMeters,
      );
      recommendedStores = verified.map((item) => item.store).toList();
      menuSelections = verified.map((item) => item.selection).toList();
    }
    final recommendedStoreIds = recommendedStores
        .map((s) => s.id)
        .where((id) => id.isNotEmpty)
        .toList();

    return _ChatMessage(
      text: botResponse,
      isBot: true,
      recommendedStores: recommendedStores,
      recommendedStoreIds: recommendedStoreIds,
      menuSelections: menuSelections,
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Follow new messages, including a reply to a question sent from an
    // earlier visit to this screen.
    ref.listen<List<_ChatMessage>>(aiChatHistoryProvider, (previous, next) {
      if (next.length > (previous?.length ?? 0)) _scrollToLatest();
    });
    ref.listen<Object?>(aiChatPendingRequestProvider, (previous, next) {
      if (next != null) _scrollToLatest();
    });
    final messages = ref.watch(aiChatHistoryProvider);
    final isTyping = ref.watch(aiChatPendingRequestProvider) != null;
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // 키보드가 열렸을 때만 키보드 상단과의 최소 간격을 둡니다.
    final bottomOffset = isKeyboardOpen ? 8.0 : safePadding.bottom;
    final composerHeight = 48.0 + 20.0 + bottomOffset;
    final contentTop = topOffset + 57;
    final contentBottomPadding = composerHeight + 12.0;

    // Tapping outside the composer closes the keyboard. Kept out of the
    // semantics tree: as a tap action it merged the header text into one
    // tappable element that held the whole screen.
    return GestureDetector(
      excludeFromSemantics: true,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: FigmaMobileCanvas(
        backgroundColor: const Color(0xFFF9FAFB),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: topOffset + 58,
              child: _ChatHeader(
                topPadding: topOffset,
                onResetChat: messages.isEmpty
                    ? null
                    : () => ref.invalidate(aiChatHistoryProvider),
              ),
            ),
            Positioned(
              left: 0,
              top: topOffset + 57,
              right: 0,
              height: 1,
              child: const ColoredBox(color: Color(0xFFEEF2FF)),
            ),
            Positioned(
              left: 0,
              top: contentTop,
              right: 0,
              bottom: 0,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(20, 25, 20, contentBottomPadding),
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: RecommendationRadiusButton(),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 34, height: 34, child: _BotAvatar()),
                      SizedBox(width: 10),
                      Expanded(child: _GreetingBubble()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '이렇게 물어보세요',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: _AiUi.fontFamily,
                      fontFamilyFallback: _AiUi.fontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chipWidth = constraints.maxWidth < 300
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          for (final prompt in _quickPrompts)
                            _PromptChip(
                              prompt: prompt,
                              width: chipWidth,
                              onTap: () => _setPrompt(prompt.label),
                            ),
                        ],
                      );
                    },
                  ),
                  for (final message in messages) ...[
                    const SizedBox(height: 14),
                    if (message.isBot)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: _BotAvatar(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _BotMessageBubble(message: message)),
                        ],
                      )
                    else
                      _UserMessageBubble(message: message),
                  ],
                  if (isTyping) ...[
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        SizedBox(width: 34, height: 34, child: _BotAvatar()),
                        SizedBox(width: 10),
                        // Narrow phones wrap the status text instead of overflowing.
                        Flexible(child: _TypingIndicator()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: _Composer(
                controller: _controller,
                onSend: _sendMessage,
                hasText: _controller.text.trim().isNotEmpty,
                isSending: isTyping,
                bottomPadding: bottomOffset,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.topPadding, this.onResetChat});

  final double topPadding;
  final VoidCallback? onResetChat;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: topPadding + 9,
            width: 40,
            height: 40,
            child: IconButton(
              // Unnamed before (QA 10/7 #50); same name as the app bars.
              tooltip: '뒤로가기',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _AiUi.ink,
                size: 23,
              ),
            ),
          ),
          Positioned(
            left: 64,
            top: topPadding + 10,
            width: 34,
            height: 34,
            child: const _HeaderAvatar(),
          ),
          Positioned(
            left: 106,
            top: topPadding + 9,
            child: const Text(
              '얼마고 AI',
              style: TextStyle(
                color: _AiUi.ink,
                fontFamily: _AiUi.fontFamily,
                fontFamilyFallback: _AiUi.fontFallback,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
          Positioned(
            left: 106,
            top: topPadding + 30,
            child: const _OnlineCaption(),
          ),
          if (onResetChat != null)
            Positioned(
              right: 12,
              top: topPadding + 9,
              child: IconButton(
                onPressed: onResetChat,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: _AiUi.ink,
                  size: 22,
                ),
                tooltip: '새 대화 시작',
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) {
    return const _BotAvatar();
  }
}

class _OnlineCaption extends StatelessWidget {
  const _OnlineCaption();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '공공데이터 + 내 활동 기반',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontFamily: _AiUi.fontFamily,
            fontFamilyFallback: _AiUi.fontFallback,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF10B981)],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 17,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final narrow =
        FigmaMobileCanvas.webContentWidthFor(MediaQuery.sizeOf(context).width) <
        350;
    return Container(
      padding: const EdgeInsets.fromLTRB(23, 21, 23, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEEF2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2563EB),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'AI 추천',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontFamily: _AiUi.fontFamily,
                  fontFamilyFallback: _AiUi.fontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            narrow ? '오늘은 뭘\n드시고 싶으세요?' : '오늘은 뭘 드시고 싶으세요?',
            style: const TextStyle(
              color: _AiUi.ink,
              fontFamily: _AiUi.fontFamily,
              fontFamilyFallback: _AiUi.fontFallback,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '현재 위치의 실제 매장과 가격을 바탕으로\n합리적인 한 끼를 추천해드려요.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontFamily: _AiUi.fontFamily,
              fontFamilyFallback: _AiUi.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingBubble extends StatelessWidget {
  const _GreetingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        '안녕하세요! 동네 절약 가이드 고미예요.\n오늘 어떤 음식을 찾으시나요?\n\n날씨나 기분, 예산에 딱 맞는 메뉴와\n주변 착한가격 매장을 알맞게 추천해드릴게요!',
        style: TextStyle(
          color: _AiUi.ink,
          fontFamily: _AiUi.fontFamily,
          fontFamilyFallback: _AiUi.fontFallback,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.55,
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt, required this.onTap, this.width});

  final _QuickPrompt prompt;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    // Read as a button rather than text with a tap action (QA 10/7 #54).
    return Semantics(
      container: true,
      button: true,
      child: SizedBox(
        width: width ?? 163.5,
        height: 52,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFEEF2FF)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(prompt.icon, color: const Color(0xFF2563EB), size: 16),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      prompt.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _AiUi.ink,
                        fontFamily: _AiUi.fontFamily,
                        fontFamilyFallback: _AiUi.fontFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.hasText,
    required this.bottomPadding,
    this.isSending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool hasText;
  final double bottomPadding;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEF2FF))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
      child: Row(
        children: [
          Expanded(
            // Screen readers get the field's name here. As a labelText it
            // floated up and cut a notch into the pill outline.
            child: Semantics(
              label: 'AI에게 질문',
              child: TextField(
                controller: controller,
                // Matches the server limit; the send path re-checks UTF-16
                // length.
                inputFormatters: [
                  LengthLimitingTextInputFormatter(aiChatMaxMessageLength),
                ],
                onSubmitted: (_) {
                  if (hasText && !isSending) onSend();
                },
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: const TextStyle(
                    color: AppColors.muted,
                    fontFamily: _AiUi.fontFamily,
                    fontFamilyFallback: _AiUi.fontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(
                  color: _AiUi.ink,
                  fontFamily: _AiUi.fontFamily,
                  fontFamilyFallback: _AiUi.fontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: FilledButton(
              onPressed: hasText && !isSending ? onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: hasText
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE5E7EB),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: Semantics(
                label: 'AI 질문 전송',
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 252),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: _AiUi.fontFamily,
                fontFamilyFallback: _AiUi.fontFallback,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotMessageBubble extends StatelessWidget {
  const _BotMessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final structured = splitAiRecommendationText(message.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEF2FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                buildAiChatDisplayTextSpan(
                  structured == null ? message.text : structured.$1,
                  const TextStyle(
                    color: _AiUi.ink,
                    fontFamily: _AiUi.fontFamily,
                    fontFamilyFallback: _AiUi.fontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
              ),
              if (structured != null) ...[
                const SizedBox(height: 12),
                for (final item in structured.$2) ...[
                  // Each store card is its own element. Before, the cards,
                  // the summary and the copy chip were one tappable element,
                  // so a double tap on the answer copied it (QA 10/7 #54).
                  Semantics(
                    container: true,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AiUi.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            children: [
                              for (final detail
                                  in item.$2
                                      .split(' · ')
                                      .where((value) => value.isNotEmpty))
                                Text(
                                  detail,
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.recommendedStores.isNotEmpty)
              _MessageActionChip(
                icon: Icons.map_outlined,
                label: '지도에서 찾기',
                onTap: () {
                  final result = AiMapRecommendationResult(
                    storeIds: message.recommendedStoreIds,
                    stores: message.recommendedStores,
                    menuSelections: message.menuSelections,
                    queryText: message.text,
                  );

                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(result);
                  } else {
                    context.go(AppRoutes.home, extra: result);
                  }
                },
              ),
            const SizedBox(width: 8),
            _MessageActionChip(
              icon: Icons.copy_rounded,
              label: '복사',
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  HowmuchSnackBar(
                    content: Text('추천 답변을 복사했어요.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageActionChip extends StatelessWidget {
  const _MessageActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Its own button: before, a single chip ('복사') merged into the whole
    // answer, which a double tap then copied (QA 10/7 #54).
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFEEF2FF)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: _AiUi.fontFamily,
                    fontFamilyFallback: _AiUi.fontFallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2FF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              '고미가 착한가격 매장을 찾고 있어요...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontFamily: _AiUi.fontFamily,
                fontFamilyFallback: _AiUi.fontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ChatMessage = AiChatMessage;

class _QuickPrompt {
  const _QuickPrompt({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _AiUi {
  const _AiUi._();

  static const ink = Color(0xFF0F172A);
  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];
}

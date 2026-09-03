import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class AiRecommendChatScreen extends ConsumerStatefulWidget {
  const AiRecommendChatScreen({super.key});

  @override
  ConsumerState<AiRecommendChatScreen> createState() =>
      _AiRecommendChatScreenState();
}

class _AiRecommendChatScreenState extends ConsumerState<AiRecommendChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  static const _quickPrompts = [
    _QuickPrompt(
      icon: Icons.account_balance_wallet_outlined,
      label: '만원 이하 점심 추천',
    ),
    _QuickPrompt(icon: Icons.umbrella_outlined, label: '비 오는 날 따뜻한 국물'),
    _QuickPrompt(icon: Icons.restaurant_outlined, label: '혼밥하기 좋은 분식'),
    _QuickPrompt(icon: Icons.location_on_outlined, label: '이 근처 오후 코스 짜줘'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
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

  Future<void> _sendMessage() async {
    if (_isTyping) return;

    final messageText = _controller.text.trim();
    if (messageText.isEmpty) return;

    final userMessage = _ChatMessage(text: messageText, isBot: false);

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isTyping = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    _scrollToLatest();

    // 💡 최근 대화 내역 추출 (최대 6개, 방금 추가한 본인 메시지 제외)
    final previousMessages = _messages.take(_messages.length - 1).toList();
    final history = previousMessages
        .skip(previousMessages.length > 6 ? previousMessages.length - 6 : 0)
        .map((m) => {'role': m.isBot ? 'model' : 'user', 'text': m.text})
        .toList();

    // 서버가 실제 매장 정보를 다시 확인할 수 있도록 ID와 현재 위치만 전달합니다.
    final position = HomeMapScreen.globalUserPosition;
    final nearbyStoreIds = buildNearbyStoreIds(
      stores: HomeMapScreen.globalAllStores,
      lat: position?.latitude,
      lng: position?.longitude,
      limit: 10,
    );

    // 💡 Gemini API 호출
    var botResponse = await ref
        .read(aiChatServiceProvider)
        .getGeminiResponse(
          messageText,
          history: history,
          nearbyStoreIds: nearbyStoreIds,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
    if (isAiUnavailableResponse(botResponse)) {
      final position = HomeMapScreen.globalUserPosition;
      botResponse =
          buildLocalAiFallback(
            stores: HomeMapScreen.globalAllStores,
            lat: position?.latitude,
            lng: position?.longitude,
          ) ??
          botResponse;
    }

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(text: botResponse, isBot: true));
        _isTyping = false;
      });
      _scrollToLatest();
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final rawKeyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = rawKeyboard > 0;
    final designScale = FigmaMobileCanvas.designScaleFor(context);
    final keyboardOffset = designScale <= 0 ? 0.0 : rawKeyboard / designScale;

    // 키보드가 켜졌을 때는 홈 인디케이터 여백을 제외하고 10px로 밀착
    final bottomOffset = isKeyboardOpen
        ? 10.0
        : (safePadding.bottom > 16 ? safePadding.bottom : 16.0);
    final composerLift = isKeyboardOpen ? 0.0 : 12.0;
    final composerHeight = 48.0 + 20.0 + bottomOffset;
    final contentTop = topOffset + 57;
    final contentBottomPadding =
        composerHeight + keyboardOffset + composerLift + 10;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: FigmaMobileCanvas(
        backgroundColor: const Color(0xFFF3F6FA),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: topOffset + 58,
              child: _ChatHeader(topPadding: topOffset),
            ),
            Positioned(
              left: 0,
              top: topOffset + 57,
              right: 0,
              height: 1,
              child: const ColoredBox(color: Color(0xFFE1E6EF)),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      for (final prompt in _quickPrompts)
                        _PromptChip(
                          prompt: prompt,
                          onTap: () => _setPrompt(prompt.label),
                        ),
                    ],
                  ),
                  for (final message in _messages) ...[
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
                  if (_isTyping) ...[
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        SizedBox(width: 34, height: 34, child: _BotAvatar()),
                        SizedBox(width: 10),
                        _TypingIndicator(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: keyboardOffset + composerLift,
              right: 0,
              child: _Composer(
                controller: _controller,
                onSend: _sendMessage,
                hasText: _controller.text.trim().isNotEmpty,
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
  const _ChatHeader({required this.topPadding});

  final double topPadding;

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
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(23, 21, 23, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2D8FA)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          SizedBox(height: 10),
          Text(
            '오늘은 뭘 드시고 싶으세요?',
            style: TextStyle(
              color: _AiUi.ink,
              fontFamily: _AiUi.fontFamily,
              fontFamilyFallback: _AiUi.fontFallback,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '현재 위치의 실제 매장과 가격을 바탕으로 합리적인 한 끼를 추천해드려요.',
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
        border: Border.all(color: const Color(0xFFE1E6EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        '안녕하세요, 동네 절약 가이드 고미예요.\n현재 위치에서 확인된 매장만 솔직하게 추천해드릴게요.\n아래에서 골라보시거나 직접 입력해 주세요.',
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
  const _PromptChip({required this.prompt, required this.onTap});

  final _QuickPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 163.5,
      height: 42,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE1E6EF)),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.hasText,
    required this.bottomPadding,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool hasText;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E6EF))),
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
            child: TextField(
              controller: controller,
              cursorColor: const Color(0xFF2563EB),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontFamily: _AiUi.fontFamily,
                  fontFamilyFallback: _AiUi.fontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
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
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: FilledButton(
              onPressed: hasText ? onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: hasText
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E6EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message.text,
        style: const TextStyle(
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_AiUi.ink),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isBot});

  final String text;
  final bool isBot;
}

class _QuickPrompt {
  const _QuickPrompt({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _AiUi {
  const _AiUi._();

  static const ink = Color(0xFF0F172A);
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];
}

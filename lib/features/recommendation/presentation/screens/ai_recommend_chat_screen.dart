import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:image_picker/image_picker.dart';

class AiRecommendChatScreen extends StatefulWidget {
  const AiRecommendChatScreen({super.key});

  @override
  State<AiRecommendChatScreen> createState() => _AiRecommendChatScreenState();
}

class _AiRecommendChatScreenState extends State<AiRecommendChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final List<_ChatMessage> _messages = [];
  XFile? _attachedPhoto;

  // TODO(박지환 BE): AI 추천 API가 붙으면 추천 질문/입력값을 서버 요청으로 교체하세요.
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

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty && _attachedPhoto == null) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: message, photo: _attachedPhoto));
      _controller.clear();
      _attachedPhoto = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _removePhoto() {
    setState(() => _attachedPhoto = null);
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted || photo == null) {
        return;
      }
      setState(() => _attachedPhoto = photo);
    } on PlatformException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진 접근 권한을 확인해주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom > 24 ? safePadding.bottom : 24.0;
    final designScale = FigmaMobileCanvas.designScaleFor(context);
    final keyboardOffset = designScale <= 0
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom / designScale;
    const composerLift = 18.0;
    final hasAttachment = _attachedPhoto != null;
    final composerHeight = (hasAttachment ? 142 : 78) + bottomOffset;
    final contentTop = topOffset + 57;
    final contentBottomPadding =
        composerHeight + keyboardOffset + composerLift + 24;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: FigmaMobileCanvas(
        backgroundColor: const Color(0xFFF3F6FA),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: FigmaMobileCanvas.width,
              height: topOffset + 58,
              child: _ChatHeader(topPadding: topOffset),
            ),
            Positioned(
              left: 0,
              top: topOffset + 57,
              width: FigmaMobileCanvas.width,
              height: 1,
              child: const ColoredBox(color: Color(0xFFE1E6EF)),
            ),
            Positioned(
              left: 0,
              top: contentTop,
              width: FigmaMobileCanvas.width,
              height: FigmaMobileCanvas.height - contentTop,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(20, 25, 20, contentBottomPadding),
                children: [
                  const SizedBox(height: 156, child: _HeroCard()),
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
                    _UserMessageBubble(message: message),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: keyboardOffset + composerLift,
              width: FigmaMobileCanvas.width,
              height: composerHeight,
              child: _Composer(
                controller: _controller,
                onSend: _sendMessage,
                onAddPhoto: _pickPhoto,
                onRemovePhoto: _removePhoto,
                attachedPhoto: _attachedPhoto,
                hasText: _controller.text.trim().isNotEmpty || hasAttachment,
                hasAttachment: hasAttachment,
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
      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(23, 25, 23, 20),
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
          SizedBox(height: 14),
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
          SizedBox(height: 12),
          Text(
            '예산·날씨·위치·취향을 종합해 가장 합리적인 한 끼를 추천해드려요.',
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
        '안녕하세요 민준님 👋\n현재 위치 서울 마포구 합정동 근처에서 추천드릴게요.\n아래에서 골라보시거나 직접 입력하셔도 돼요.',
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
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.attachedPhoto,
    required this.hasText,
    required this.hasAttachment,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;
  final XFile? attachedPhoto;
  final bool hasText;
  final bool hasAttachment;

  @override
  Widget build(BuildContext context) {
    final controlsTop = hasAttachment ? 79.0 : 15.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E6EF))),
      ),
      child: Stack(
        children: [
          if (attachedPhoto != null)
            Positioned(
              left: 16,
              top: 12,
              right: 16,
              height: 52,
              child: _AttachmentPreview(
                photo: attachedPhoto!,
                onRemove: onRemovePhoto,
              ),
            ),
          Positioned(
            left: 16,
            top: controlsTop,
            width: 48,
            height: 48,
            child: Material(
              color: hasAttachment
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF1F5F9),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAddPhoto,
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.add_rounded,
                  color: hasAttachment ? const Color(0xFF2563EB) : _AiUi.ink,
                  size: 25,
                ),
              ),
            ),
          ),
          Positioned(
            left: 72,
            top: controlsTop,
            width: 220,
            height: 48,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
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
          Positioned(
            right: 16,
            top: controlsTop,
            width: 48,
            height: 48,
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
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.photo, required this.onRemove});

  final XFile photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Image.file(
                File(photo.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.image_outlined,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '이미지 첨부됨',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _AiUi.ink,
                fontFamily: _AiUi.fontFamily,
                fontFamilyFallback: _AiUi.fontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF64748B),
              size: 18,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 236,
                    height: 132,
                    child: Image.file(
                      File(message.photo!.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0xFFEFF6FF),
                          child: Icon(
                            Icons.image_outlined,
                            color: Color(0xFF2563EB),
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (message.text.isNotEmpty) ...[
                if (message.photo != null) const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.photo});

  final String text;
  final XFile? photo;
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

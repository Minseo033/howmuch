import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class ChatbotIntroScreen extends StatelessWidget {
  const ChatbotIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '8-2',
      title: '챗봇 첫 화면 · 추천 질문',
      owner: '오태관',
      feature: 'AI 추천',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '7-6',
      title: '세션 만료 · 재로그인',
      owner: '김민서',
      feature: '공통 상태',
    );
  }
}

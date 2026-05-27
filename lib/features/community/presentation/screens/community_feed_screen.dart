import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '3-1',
      title: '동네 제보 커뮤니티 피드',
      owner: '오태관',
      feature: '커뮤니티',
    );
  }
}

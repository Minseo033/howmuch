import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class PermissionSetupScreen extends StatelessWidget {
  const PermissionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '1-5',
      title: '권한 설정',
      owner: '김민서',
      feature: '인증',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/status_message.dart';

class NetworkErrorScreen extends StatelessWidget {
  const NetworkErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('7-1 네트워크 오류')),
      body: StatusMessage(
        icon: Icons.wifi_off,
        title: '연결이 불안정해요',
        message: '네트워크 상태를 확인한 뒤 다시 시도해주세요. 현재 화면은 오류 상태 확인용 더미 화면입니다.',
        actionLabel: '다시 시도',
        onAction: () => context.go(AppRoutes.home),
        secondaryLabel: '마이페이지로 이동',
        onSecondaryAction: () => context.go(AppRoutes.mypage),
      ),
    );
  }
}

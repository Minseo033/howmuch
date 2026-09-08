import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';

Future<bool> showLoginRequiredDialog(
  BuildContext context, {
  String message = '이 기능은 로그인 후 이용할 수 있어요.',
}) async {
  final shouldLogin = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => HowmuchDialog(
      key: const Key('login_required_dialog'),
      title: '로그인이 필요해요',
      description: message,
      cancelLabel: '나중에',
      confirmLabel: '카카오로 로그인',
      confirmKey: const Key('login_required_confirm'),
      confirmColor: AppColors.kakaoYellow,
      confirmForeground: AppColors.kakaoBrown,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );

  return shouldLogin ?? false;
}

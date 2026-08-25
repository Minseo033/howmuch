import 'package:flutter/material.dart';

Future<bool> showLoginRequiredDialog(
  BuildContext context, {
  String message = '이 기능은 로그인 후 이용할 수 있어요.',
}) async {
  final shouldLogin = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      key: const Key('login_required_dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 10),
          Text(
            '로그인이 필요해요',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          height: 1.55,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          key: const Key('login_required_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFEE500),
            foregroundColor: const Color(0xFF191600),
          ),
          child: const Text('카카오로 로그인'),
        ),
      ],
    ),
  );

  return shouldLogin ?? false;
}

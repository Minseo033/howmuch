import 'package:flutter/material.dart';

import 'package:howmuch/core/theme/app_colors.dart';

class LoginRequiredState extends StatelessWidget {
  const LoginRequiredState({
    super.key,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.muted,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              '로그인이 필요해요',
              style: TextStyle(
                fontFamily: 'Noto Sans KR',
                fontFamilyFallback: ['Noto Sans KR'],
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Noto Sans KR',
                fontFamilyFallback: ['Noto Sans KR'],
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontFamilyFallback: ['Noto Sans KR'],
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

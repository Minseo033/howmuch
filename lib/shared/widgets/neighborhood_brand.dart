import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';

/// Shared decorative brand elements. They do not own navigation or state.
class NeighborhoodWordmark extends StatelessWidget {
  const NeighborhoodWordmark({
    super.key,
    this.light = false,
    this.compact = false,
  });

  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ink = light ? AppColors.cream : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 28 : 38,
          height: compact ? 28 : 38,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(compact ? 9 : 12),
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: AppColors.primary,
            size: compact ? 19 : 26,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          '얼마고?',
          style: TextStyle(
            color: ink,
            fontSize: compact ? 22 : 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class NeighborhoodIntro extends StatelessWidget {
  const NeighborhoodIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.dark = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dark ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: dark ? AppColors.lime : AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: TextStyle(
                    color: dark ? AppColors.cream : AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: dark ? const Color(0xFFE0EBE1) : AppColors.muted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.spa_outlined,
            color: dark ? AppColors.lime : AppColors.primary,
            size: 36,
          ),
        ],
      ),
    );
  }
}

class NeighborhoodDesktopEditorial extends StatelessWidget {
  const NeighborhoodDesktopEditorial({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 48, 36, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NeighborhoodWordmark(),
            const Spacer(),
            const Text(
              'YOUR NEIGHBORHOOD GUIDE',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '가까이에서\n발견하는\n기분 좋은 가격.',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '우리 동네의 작은 가게부터\n매일 쌓이는 나의 절약까지.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.9,
              ),
            ),
            const Spacer(),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 18),
            const Text(
              'LOCAL FINDS. LITTLE SAVINGS.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

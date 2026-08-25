import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ServicePreparationScreen extends StatelessWidget {
  const ServicePreparationScreen.preparing({super.key})
    : delayed = false,
      onRetry = null;

  const ServicePreparationScreen.delayed({super.key, required this.onRetry})
    : delayed = true;

  final bool delayed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: delayed
                ? '연결이 평소보다 늦어지고 있어요. 다시 연결할 수 있어요.'
                : '서비스를 준비하고 있어요. 준비가 끝나면 자동으로 시작해요.',
            child: delayed
                ? _DelayedContent(onRetry: onRetry!)
                : const _PreparingContent(),
          ),
        ),
      ),
    );
  }
}

class _PreparingContent extends StatelessWidget {
  const _PreparingContent();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!reduceMotion)
                    const SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                        backgroundColor: AppColors.primaryLight,
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _StatusCopy(
              title: '서비스를 준비하고 있어요',
              body: '잠시만 기다려 주세요.\n준비가 끝나면 자동으로 시작해요.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DelayedContent extends StatelessWidget {
  const _DelayedContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 28),
          const _StatusCopy(
            title: '연결이 평소보다 늦어지고 있어요',
            body: '로그인 상태는 그대로예요.\n잠시 후 다시 연결해 주세요.',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('다시 연결'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCopy extends StatelessWidget {
  const _StatusCopy({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.4,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.65,
          ),
        ),
      ],
    );
  }
}

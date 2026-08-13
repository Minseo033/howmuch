import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

/// Shows a single, dismissible web entry prompt when the signed-in user has
/// unread in-app notifications. Native apps retain their existing push flow.
class WebNotificationPrompt extends ConsumerStatefulWidget {
  const WebNotificationPrompt({
    super.key,
    required this.child,
    required this.onOpenNotifications,
  });

  final Widget child;
  final VoidCallback onOpenNotifications;

  @override
  ConsumerState<WebNotificationPrompt> createState() =>
      _WebNotificationPromptState();
}

class _WebNotificationPromptState extends ConsumerState<WebNotificationPrompt> {
  int? _dismissedUnreadCount;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;
    if (!isLoggedIn) return widget.child;

    final notifications = ref.watch(notificationsProvider);
    final unreadCount =
        notifications.valueOrNull
            ?.where((notification) => notification.isUnread)
            .length ??
        0;
    final shouldShow = unreadCount > 0 && _dismissedUnreadCount != unreadCount;

    if (!shouldShow) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: FigmaMobileCanvas.maxWebWidth,
                ),
                child: _UnreadNotificationBanner(
                  unreadCount: unreadCount,
                  onDismiss: () =>
                      setState(() => _dismissedUnreadCount = unreadCount),
                  onOpen: () {
                    setState(() => _dismissedUnreadCount = unreadCount);
                    widget.onOpenNotifications();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnreadNotificationBanner extends StatelessWidget {
  const _UnreadNotificationBanner({
    required this.unreadCount,
    required this.onDismiss,
    required this.onOpen,
  });

  final int unreadCount;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final countText = unreadCount == 1
        ? '새 알림이 있어요'
        : '새 알림 $unreadCount개가 있어요';

    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: .24)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    countText,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '알림함에서 확인해 보세요.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '알림함 보기',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: '알림 안내 닫기',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.muted,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

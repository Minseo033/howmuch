import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows a single, dismissible web entry prompt when the signed-in user has
/// unread in-app notifications. Native apps retain their existing push flow.
class WebNotificationPrompt extends ConsumerStatefulWidget {
  const WebNotificationPrompt({
    super.key,
    required this.child,
    required this.onOpenNotifications,
    required this.isHome,
  });

  final Widget child;
  final VoidCallback onOpenNotifications;
  final bool isHome;

  @override
  ConsumerState<WebNotificationPrompt> createState() =>
      _WebNotificationPromptState();
}

class _WebNotificationPromptState extends ConsumerState<WebNotificationPrompt> {
  String? _dismissedUnreadSignature;
  String? _dismissedNoticeId;
  String? _pendingNoticeId;

  void _scheduleNoticePopup(NotificationModel notice) {
    if (_dismissedNoticeId == notice.id || _pendingNoticeId == notice.id) {
      return;
    }
    _pendingNoticeId = notice.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final preferences = await SharedPreferences.getInstance();
      final hiddenToday = preferences.getString(noticeHiddenDateKey(notice.id));
      if (!mounted) return;
      if (hiddenToday == noticeLocalDate(DateTime.now())) {
        setState(() {
          _dismissedNoticeId = notice.id;
          _pendingNoticeId = null;
        });
        return;
      }

      final action = await showDialog<_NoticeDialogAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _NoticePopup(notice: notice),
      );
      if (!mounted) return;
      if (action == _NoticeDialogAction.hideToday) {
        await preferences.setString(
          noticeHiddenDateKey(notice.id),
          noticeLocalDate(DateTime.now()),
        );
      }
      if (!mounted) return;
      setState(() {
        _dismissedNoticeId = notice.id;
        _pendingNoticeId = null;
      });
      if (action == _NoticeDialogAction.openNotifications) {
        widget.onOpenNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;
    if (!isLoggedIn) return widget.child;

    final notifications = ref.watch(notificationsProvider);
    final allNotifications = notifications.valueOrNull ?? const [];
    final unreadNotifications = allNotifications
        .where((notification) => notification.isUnread)
        .toList(growable: false);
    final unreadCount = unreadNotifications.length;
    final unreadSignature = notificationSignature(unreadNotifications);
    final notices = allNotifications
        .where((notification) => notification.type == '공지사항')
        .toList(growable: false);
    if (notices.isNotEmpty) _scheduleNoticePopup(notices.first);
    final shouldShow =
        unreadCount > 0 && _dismissedUnreadSignature != unreadSignature;
    final bannerTop = notificationPromptTop(
      isHome: widget.isHome,
      safeTop: MediaQuery.paddingOf(context).top,
    );

    if (!shouldShow) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: bannerTop,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: FigmaMobileCanvas.maxWebWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _UnreadNotificationBanner(
                  key: const ValueKey('web-notification-banner'),
                  unreadCount: unreadCount,
                  onDismiss: () => setState(
                    () => _dismissedUnreadSignature = unreadSignature,
                  ),
                  onOpen: () {
                    setState(() => _dismissedUnreadSignature = unreadSignature);
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

String noticeHiddenDateKey(String noticeId) =>
    'howmuch_notice_hidden_date_$noticeId';

String noticeLocalDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
}

enum _NoticeDialogAction { close, hideToday, openNotifications }

class _NoticePopup extends StatelessWidget {
  const _NoticePopup({required this.notice});

  final NotificationModel notice;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('notice-popup'),
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '공지사항',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notice.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          notice.messageText,
          style: const TextStyle(
            color: AppColors.textBody,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_NoticeDialogAction.openNotifications),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '공지사항 보기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_NoticeDialogAction.hideToday),
                    child: const Text('오늘 하루 보지 않기'),
                  ),
                ),
                Container(width: 1, height: 16, color: AppColors.border),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_NoticeDialogAction.close),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Keeps the prompt below the home search field or the standard page header.
double notificationPromptTop({required bool isHome, required double safeTop}) {
  return safeTop + (isHome ? 74 : 66);
}

String notificationCountLabel(int unreadCount) => '읽지 않은 알림 $unreadCount건';

/// Produces a stable identity for the current unread set. Using only the count
/// would miss a newly arrived notification that replaces one just read.
String notificationSignature(Iterable<NotificationModel> notifications) {
  final ids =
      notifications
          .map((notification) => notification.id)
          .where((id) => id.isNotEmpty)
          .toList(growable: false)
        ..sort();
  return ids.join('\u0000');
}

class _UnreadNotificationBanner extends StatelessWidget {
  const _UnreadNotificationBanner({
    super.key,
    required this.unreadCount,
    required this.onDismiss,
    required this.onOpen,
  });

  final int unreadCount;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final countText = notificationCountLabel(unreadCount);

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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows a single, dismissible web entry prompt when the signed-in user has
/// in-app notifications. Native apps retain their existing push flow.
class WebNotificationPrompt extends ConsumerStatefulWidget {
  const WebNotificationPrompt({
    super.key,
    required this.child,
    required this.onOpenNotifications,
    required this.isHome,
    required this.navigatorKey,
  });

  final Widget child;
  final VoidCallback onOpenNotifications;
  final bool isHome;
  final GlobalKey<NavigatorState> navigatorKey;

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

      final navigatorContext = widget.navigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) {
        setState(() => _pendingNoticeId = null);
        return;
      }

      final action = await showDialog<_NoticeDialogAction>(
        context: navigatorContext,
        barrierDismissible: false,
        barrierColor: const Color(0x990F172A),
        barrierLabel: '공지사항 닫기',
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
    final timeText = notice.timeText.trim();

    return Dialog(
      key: const ValueKey('notice-popup'),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceOverlay,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x1A0F172A)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x290F172A),
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          '얼마고 소식',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        if (timeText.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: const BoxDecoration(
                              color: AppColors.disabled,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            timeText,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          tooltip: '공지사항 닫기',
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_NoticeDialogAction.close),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: AppColors.textMuted,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 21),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      notice.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .28,
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          notice.messageText,
                          style: const TextStyle(
                            color: AppColors.textBody,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_NoticeDialogAction.openNotifications),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '알림함에서 자세히 보기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 7),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(_NoticeDialogAction.hideToday),
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            icon: const Icon(Icons.schedule_rounded, size: 17),
                            label: const Text(
                              '오늘 하루 보지 않기',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_NoticeDialogAction.close),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(56, 44),
                            foregroundColor: AppColors.textMuted,
                          ),
                          child: const Text(
                            '닫기',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

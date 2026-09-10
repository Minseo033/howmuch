import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
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
  bool _suppressNoticePopup = false;

  void _scheduleNoticePopup(NotificationModel notice) {
    if (_suppressNoticePopup ||
        _dismissedNoticeId == notice.id ||
        _pendingNoticeId == notice.id) {
      return;
    }
    _pendingNoticeId = notice.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final preferences = await SharedPreferences.getInstance();
      final hiddenToday = preferences.getString(noticeHiddenDateKey(notice.id));
      if (!mounted) return;
      if (_suppressNoticePopup || _dismissedNoticeId == notice.id) {
        _pendingNoticeId = null;
        return;
      }
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
        barrierColor: const Color(0x660F172A),
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

  void _dismissUnreadPrompt(String unreadSignature) {
    setState(() {
      _dismissedUnreadSignature = unreadSignature;
      _suppressNoticePopup = true;
      _pendingNoticeId = null;
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
    final shouldShow =
        unreadCount > 0 && _dismissedUnreadSignature != unreadSignature;
    if (notices.isNotEmpty && !shouldShow) {
      _scheduleNoticePopup(notices.first);
    }
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
                  onDismiss: () => _dismissUnreadPrompt(unreadSignature),
                  onOpen: () {
                    _dismissUnreadPrompt(unreadSignature);
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
    final actionTextStyle = Theme.of(context).textTheme.labelLarge;

    return Dialog(
      key: const ValueKey('notice-popup'),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceOverlay,
            borderRadius: BorderRadius.circular(AppRadii.overlay),
            boxShadow: AppElevation.overlay,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.overlay),
            child: Material(
              color: AppColors.surfaceOverlay,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                '공지사항',
                                style: TextStyle(
                                  color: AppColors.textBody,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (timeText.isNotEmpty)
                                Text(
                                  timeText,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '공지사항 닫기',
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_NoticeDialogAction.close),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: AppColors.textMuted,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              notice.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.4,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            notice.messageText,
                            style: const TextStyle(
                              color: AppColors.textBody,
                              fontSize: 15,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_NoticeDialogAction.openNotifications),
                      style: FilledButton.styleFrom(
                        textStyle: actionTextStyle,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      child: const Text(
                        '공지사항 보기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(_NoticeDialogAction.hideToday),
                            style: TextButton.styleFrom(
                              textStyle: actionTextStyle,
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: AppSpacing.xs,
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: const Text(
                              '오늘 하루 보지 않기',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_NoticeDialogAction.close),
                          style: TextButton.styleFrom(
                            textStyle: actionTextStyle,
                            minimumSize: const Size(48, 44),
                            foregroundColor: AppColors.textBody,
                          ),
                          child: const Text(
                            '닫기',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

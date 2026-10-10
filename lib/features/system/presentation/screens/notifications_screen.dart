import 'dart:async';

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';
import 'package:howmuch/shared/widgets/login_required_state.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedTab = '전체';
  bool _markingAllRead = false;
  bool _openingNotification = false;

  @override
  void initState() {
    super.initState();
    // Polling only runs while the app is active, so a first visit may find
    // nothing loaded yet. Load on entry instead of spinning forever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(authStateProvider).isLoggedIn) return;
      final current = ref.read(notificationsProvider);
      if (current.valueOrNull == null && !current.hasError) {
        ref.read(notificationsProvider.notifier).loadNotifications();
      }
    });
  }

  /// Login opens on top of the inbox and comes back here. Logging in starts
  /// a new inbox that polling may not have loaded yet, so load it here
  /// instead of spinning. A visitor who comes back as a guest (left login, or
  /// a new account that left profile setup) gets the login prompt, which
  /// follows the login state.
  Future<void> _logIn() async {
    await openLoginFlow(context);
    if (!mounted || !ApiClient.isAuthenticated) return;
    if (ref.read(notificationsProvider).valueOrNull == null) {
      ref.read(notificationsProvider.notifier).loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    // Every login state change starts a new inbox. Load one that belongs to
    // an account, also when a login finishes after the visitor left it
    // (polling may load it too; one load runs at a time).
    ref.listen(notificationsProvider.notifier, (_, notifier) {
      if (ApiClient.isAuthenticated) notifier.loadNotifications();
    });
    final isLoggedIn = ref.watch(
      authStateProvider.select((auth) => auth.isLoggedIn),
    );
    final notificationsAsync = ref.watch(notificationsProvider);
    final hasUnread =
        isLoggedIn &&
        (notificationsAsync.valueOrNull?.any(
              (notification) =>
                  notification.isUnread && notification.id.isNotEmpty,
            ) ??
            false);

    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: FigmaMobileCanvas(
        backgroundColor: const Color(0xFFF4F6FA),
        child: Stack(
          children: [
            // Content Scroll
            Positioned.fill(
              child: !isLoggedIn
                  ? LoginRequiredState(
                      description: '로그인하면 가격 변동, 제보 결과, 댓글, 문의 답변 알림을 볼 수 있어요.',
                      actionLabel: '로그인하기',
                      onAction: _logIn,
                    )
                  : notificationsAsync.when(
                      skipError: true,
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      error: (err, stack) {
                        // Only a guest can fix an error by logging in. A
                        // member turned down (403) would come straight back
                        // from login, so they get the retry below.
                        if (!ApiClient.isAuthenticated) {
                          return LoginRequiredState(
                            description: '로그인한 뒤 다시 확인해 주세요.',
                            actionLabel: '로그인하기',
                            onAction: _logIn,
                          );
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE5E7EB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFF64748B),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '알림을 불러오지 못했어요',
                                  style: TextStyle(
                                    fontFamily: 'Noto Sans KR',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '인터넷 연결 상태를 확인하고 다시 시도해보세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Noto Sans KR',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: 140,
                                  height: 40,
                                  child: FilledButton(
                                    onPressed: () => ref
                                        .read(notificationsProvider.notifier)
                                        .loadNotifications(),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      '다시 시도',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      data: (notifications) {
                        final filteredNotifications = notifications.where((
                          notif,
                        ) {
                          if (_selectedTab == '전체') return true;
                          return notif.tabCategory == _selectedTab;
                        }).toList();

                        final todayNotifications = filteredNotifications
                            .where((n) => n.section == '오늘')
                            .toList();
                        final pastNotifications = filteredNotifications
                            .where((n) => n.section == '이전')
                            .toList();
                        final refreshEdge =
                            topOffset +
                            HowmuchTopBar.height +
                            HowmuchTopBar.height;

                        if (filteredNotifications.isEmpty) {
                          final emptyState = Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (notificationsAsync.hasError)
                                    _buildRefreshError(),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE5E7EB),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_off_outlined,
                                      color: Color(0xFF64748B),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '받은 알림이 없어요',
                                    style: TextStyle(
                                      fontFamily: 'Noto Sans KR',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          return _pullToRefresh(
                            edgeOffset: refreshEdge,
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    physics: _refreshPhysics,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: emptyState,
                                    ),
                                  ),
                            ),
                          );
                        }

                        final list = SingleChildScrollView(
                          physics: _refreshPhysics,
                          padding: EdgeInsets.only(
                            top:
                                topOffset +
                                HowmuchTopBar.height +
                                HowmuchTopBar.height,
                            bottom: 40 + bottomOffset,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (notificationsAsync.hasError)
                                _buildRefreshError(),
                              if (todayNotifications.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    '오늘',
                                    style: TextStyle(
                                      fontFamily: 'Noto Sans KR',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      height: 16.5 / 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    children: todayNotifications.map((notif) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _buildNotificationItem(notif),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                              if (pastNotifications.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    '이전',
                                    style: TextStyle(
                                      fontFamily: 'Noto Sans KR',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      height: 16.5 / 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    children: pastNotifications.map((notif) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _buildNotificationItem(notif),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                        return _pullToRefresh(
                          edgeOffset: refreshEdge,
                          child: list,
                        );
                      },
                    ),
            ),
            // Tabs
            Positioned(
              left: 0,
              right: 0,
              top: topOffset + HowmuchTopBar.height,
              child: Container(
                height: HowmuchTopBar.height,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTab(label: '전체'),
                    _buildTab(label: '가격 변동'),
                    _buildTab(label: '제보'),
                    _buildTab(label: '추천'),
                  ],
                ),
              ),
            ),
            // Custom AppBar
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: topOffset + HowmuchTopBar.height,
                padding: EdgeInsets.only(top: topOffset),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 0,
                      width: HowmuchTopBar.actionSize,
                      height: HowmuchTopBar.height,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                        onPressed: () => _closeNotificationInbox(context),
                        tooltip: '뒤로가기',
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: HowmuchTopBar.iconSize,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: Center(
                        child: Text(
                          '알림',
                          style: TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontFamilyFallback: ['Noto Sans KR'],
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            height: 24 / 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      height: HowmuchTopBar.height,
                      child: TextButton(
                        onPressed: _markingAllRead || !hasUnread
                            ? null
                            : _markAllRead,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(72, HowmuchTopBar.height),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _markingAllRead ? '처리 중…' : '모두 읽음',
                          style: TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontFamilyFallback: ['Noto Sans KR'],
                            fontWeight: FontWeight.w600,
                            color: _markingAllRead || !hasUnread
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF2563EB),
                            fontSize: 11,
                            height: 16.5 / 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeNotificationInbox(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  static const _refreshPhysics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );

  /// Pull down to reload the inbox, like the other lists. On the web the app
  /// lets a mouse drag the list too, so this also works there (QA #22).
  Widget _pullToRefresh({required double edgeOffset, required Widget child}) {
    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      edgeOffset: edgeOffset,
      onRefresh: () => ref
          .read(notificationsProvider.notifier)
          .loadNotifications(isRefresh: true),
      child: child,
    );
  }

  Widget _buildRefreshError() => Padding(
    padding: const EdgeInsets.all(16),
    child: Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('최신 알림을 불러오지 못했어요. 기존 목록은 유지됩니다.'),
          TextButton.icon(
            onPressed: () => ref
                .read(notificationsProvider.notifier)
                .loadNotifications(isRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('알림 다시 불러오기'),
          ),
        ],
      ),
    ),
  );

  Widget _buildTab({required String label}) {
    final isSelected = _selectedTab == label;
    // Hand-drawn tabs: tell screen readers which one is selected.
    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = label;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.63),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontFamilyFallback: const ['Noto Sans KR'],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                    fontSize: 13,
                    height: 19.5 / 13,
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1.989,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notif) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(notif),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.bgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: notif.borderColor, width: 0.909),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Vertically center!
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: notif.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(notif.iconData, color: notif.iconColor, size: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            notif.type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Noto Sans KR',
                              fontFamilyFallback: const ['Noto Sans KR'],
                              fontWeight: FontWeight.bold,
                              color: notif.categoryColor,
                              fontSize: 11,
                              height: 16.5 / 11,
                            ),
                          ),
                        ),
                        if (notif.timeText.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            notif.timeText,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Noto Sans KR',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              height: 15 / 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2.997),
                    if (notif.title.isNotEmpty &&
                        notif.title != notif.messageText) ...[
                      Text(
                        notif.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans KR',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          height: 18.85 / 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      notif.messageText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Noto Sans KR',
                        fontFamilyFallback: ['Noto Sans KR'],
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        height: 18.85 / 13,
                      ),
                    ),
                    if (notificationDestinationFor(notif) == null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        '전체 내용 보기',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (notif.isUnread) ...[
                const SizedBox(width: 12),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                ),
              ] else ...[
                // Placeholder to keep spacing the same when read
                const SizedBox(width: 12),
                const SizedBox(width: 7, height: 7),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    if (_openingNotification) return;
    _openingNotification = true;
    try {
      if (notification.isUnread) {
        // Reading the content must not depend on the read receipt: mark it
        // in the background and let a failure simply leave it unread.
        unawaited(
          ref
              .read(notificationsProvider.notifier)
              .markRead(notification.id)
              .catchError((Object _) {}),
        );
      }

      if (!mounted) return;

      final destination = notificationDestinationFor(notification);
      final storeId = destination?.storeId;
      final route = destination?.route;
      if (storeId != null) {
        await _openStore(storeId);
      } else if (route != null) {
        await context.push<void>(route);
      } else {
        await _showNotificationDetail(notification);
      }
    } finally {
      _openingNotification = false;
    }
  }

  Future<void> _openStore(String storeId) async {
    final store = await ref
        .read(notificationApiServiceProvider)
        .fetchStore(storeId);
    if (!mounted) return;
    if (store == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          HowmuchSnackBar(content: Text('매장 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      return;
    }
    await context.push<void>(AppRoutes.storeDetail, extra: store);
  }

  Future<void> _showNotificationDetail(NotificationModel notification) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(
        maxWidth: FigmaMobileCanvas.maxWebWidth,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.overlay),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            key: const ValueKey('notification-detail'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.type.isEmpty ? '알림' : notification.type,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '알림 상세 닫기',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (notification.title.isNotEmpty &&
                            notification.title != notification.messageText) ...[
                          Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Text(
                          notification.messageText.isEmpty
                              ? '추가 안내 내용이 없어요.'
                              : notification.messageText,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.6),
                        ),
                        if (notification.timeText.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            notification.timeText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead) return;
    setState(() => _markingAllRead = true);
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          HowmuchSnackBar(
            content: Text(
              error is NotificationBatchReadException
                  ? error.toString()
                  : error is NotificationApiException && error.isUnauthorized
                  ? '로그인한 뒤 다시 시도해 주세요.'
                  : '알림 상태를 변경하지 못했어요. 다시 시도해 주세요.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }
}

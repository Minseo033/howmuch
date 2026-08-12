import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class NotificationModel {
  final String id;
  final String section; // '오늘', '이전'
  final String type; // '가격 변동', '제보 승인', '오늘의 픽', '리뷰 반응', '공지사항'
  final String tabCategory; // '가격 변동', '제보', '추천', '전체' (implicitly all)
  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final Color borderColor;
  final Color bgColor;
  final Color categoryColor;
  final String timeText;
  final String messageText;
  bool isUnread;

  NotificationModel({
    required this.id,
    required this.section,
    required this.type,
    required this.tabCategory,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.borderColor,
    this.bgColor = Colors.white,
    required this.categoryColor,
    required this.timeText,
    required this.messageText,
    this.isUnread = false,
  });
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedTab = '전체';

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final notificationsAsync = ref.watch(notificationsProvider);

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          // Content Scroll
          Positioned.fill(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2563EB),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFF64748B),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '알림을 불러오지 못했어요',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '인터넷 연결 상태를 확인하고 다시 시도해보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
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
                          onPressed: () => ref.read(notificationsProvider.notifier).loadNotifications(),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '다시 시도',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (notifications) {
                final filteredNotifications = notifications.where((notif) {
                  if (_selectedTab == '전체') return true;
                  return notif.tabCategory == _selectedTab;
                }).toList();

                final todayNotifications = filteredNotifications
                    .where((n) => n.section == '오늘')
                    .toList();
                final pastNotifications = filteredNotifications
                    .where((n) => n.section == '이전')
                    .toList();

                if (filteredNotifications.isEmpty) {
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
                              color: Color(0xFFE2E8F0),
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
                              fontFamily: 'Inter',
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
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: topOffset + 57.869 + 48.878, // Below header and tabs
                    bottom: 40 + bottomOffset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (todayNotifications.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '오늘',
                            style: TextStyle(
                              fontFamily: 'Inter',
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: todayNotifications.map((notif) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
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
                              fontFamily: 'Inter',
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: pastNotifications.map((notif) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildNotificationItem(notif),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          // Tabs
          Positioned(
            left: 0,
            right: 0,
            top: topOffset + 57.869,
            child: Container(
              height: 48.878,
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
              height: topOffset + 57.869,
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
                    left: 20,
                    top: 18.48,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        '알림',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0A0A),
                          fontSize: 16,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 20.49,
                    child: GestureDetector(
                      onTap: () => ref.read(notificationsProvider.notifier).markAllRead(),
                      behavior: HitTestBehavior.opaque,
                      child: const Text(
                        '모두 읽음',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
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
    );
  }

  Widget _buildTab({required String label}) {
    final isSelected = _selectedTab == label;
    return GestureDetector(
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
                  fontFamily: 'Inter',
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
    );
  }

  Widget _buildNotificationItem(NotificationModel notif) {
    return GestureDetector(
      onTap: () {
        if (notif.isUnread) {
          ref.read(notificationsProvider.notifier).markRead(notif.id);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.bgColor,
          borderRadius: BorderRadius.circular(16),
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
                      Text(
                        notif.type,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: const ['Noto Sans KR'],
                          fontWeight: FontWeight.bold,
                          color: notif.categoryColor,
                          fontSize: 11,
                          height: 16.5 / 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notif.timeText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          height: 15 / 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2.997),
                  Text(
                    notif.messageText,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: ['Noto Sans KR'],
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      height: 18.85 / 13,
                    ),
                  ),
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
    );
  }
}

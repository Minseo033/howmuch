import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedTab = '전체';

  final List<NotificationModel> _allNotifications = [
    NotificationModel(
      id: '1',
      section: '오늘',
      type: '가격 변동',
      tabCategory: '가격 변동',
      iconData: Icons.trending_up_rounded,
      iconColor: const Color(0xFFF97316),
      iconBgColor: const Color.fromRGBO(249, 115, 22, 0.09),
      borderColor: const Color.fromRGBO(249, 115, 22, 0.2),
      categoryColor: const Color(0xFFF97316),
      timeText: '· 10분 전',
      messageText: '찜한 동네카페의 아메리카노 가격이 2,000원으로 제보되었어요',
      isUnread: true,
    ),
    NotificationModel(
      id: '2',
      section: '오늘',
      type: '제보 승인',
      tabCategory: '제보',
      iconData: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF10B981),
      iconBgColor: const Color.fromRGBO(16, 185, 129, 0.09),
      borderColor: const Color.fromRGBO(16, 185, 129, 0.2),
      categoryColor: const Color(0xFF10B981),
      timeText: '· 1시간 전',
      messageText: '제보한 골목밥상이 검토 완료되어 지도에 표시되었어요',
      isUnread: true,
    ),
    NotificationModel(
      id: '3',
      section: '오늘',
      type: '오늘의 픽',
      tabCategory: '추천',
      iconData: Icons.lightbulb_outline_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBgColor: const Color.fromRGBO(37, 99, 235, 0.09),
      borderColor: const Color(0xFFE5E7EB),
      bgColor: const Color(0xFFFAFBFC),
      categoryColor: const Color(0xFF2563EB),
      timeText: '· 오전 9:00',
      messageText: '비 오는 날 근처 착한칼국수를 추천해요',
      isUnread: false,
    ),
    NotificationModel(
      id: '4',
      section: '이전',
      type: '리뷰 반응',
      tabCategory:
          '추천', // Could belong to another or be filtered out depending on rules, assuming '전체'
      iconData: Icons.thumb_up_outlined,
      iconColor: const Color(0xFF2563EB),
      iconBgColor: const Color.fromRGBO(37, 99, 235, 0.09),
      borderColor: const Color(0xFFE5E7EB),
      bgColor: const Color(0xFFFAFBFC),
      categoryColor: const Color(0xFF2563EB),
      timeText: '· 어제',
      messageText: '작성한 리뷰가 ‘도움이 돼요’ 5개를 받았어요',
      isUnread: false,
    ),
    NotificationModel(
      id: '5',
      section: '이전',
      type: '공지사항',
      tabCategory: '공지',
      iconData: Icons.campaign_outlined,
      iconColor: const Color(0xFF64748B),
      iconBgColor: const Color.fromRGBO(100, 116, 139, 0.09),
      borderColor: const Color(0xFFE5E7EB),
      bgColor: const Color(0xFFFAFBFC),
      categoryColor: const Color(0xFF64748B),
      timeText: '· 2일 전',
      messageText: '공공데이터 업데이트로 50개 매장 정보가 새로 추가되었어요',
      isUnread: false,
    ),
  ];

  void _markAllAsRead() {
    setState(() {
      for (var notif in _allNotifications) {
        notif.isUnread = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    final filteredNotifications = _allNotifications.where((notif) {
      if (_selectedTab == '전체') return true;
      return notif.tabCategory == _selectedTab;
    }).toList();

    final todayNotifications = filteredNotifications
        .where((n) => n.section == '오늘')
        .toList();
    final pastNotifications = filteredNotifications
        .where((n) => n.section == '이전')
        .toList();

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          // Content Scroll
          Positioned.fill(
            child: SingleChildScrollView(
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
                      onTap: _markAllAsRead,
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
          setState(() {
            notif.isUnread = false;
          });
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:howmuch/features/system/presentation/screens/notifications_screen.dart';

class NotificationApiService {
  Future<List<NotificationModel>> fetchNotifications() async {
    try {
      final response = await http.get(
        ApiClient.uri('/api/notifications'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        debugPrint('알림 API 응답 실패 (${response.statusCode}): 샘플 데이터로 폴백');
        return _getFallbackNotifications();
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return [];

      return decoded.map((item) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString() ?? '';
        final title = map['title']?.toString() ?? '';
        final body = map['body']?.toString() ?? '';
        final type = map['type']?.toString() ?? '기타';
        final isRead = map['isRead'] is bool ? map['isRead'] as bool : false;
        final createdAt = map['createdAt']?.toString() ?? '';
        return _mapToModel(id, title, body, type, isRead, createdAt);
      }).toList();
    } catch (e) {
      debugPrint('알림 API 통신 실패: $e -> 샘플 알림 리스트 표출');
      return _getFallbackNotifications();
    }
  }

  NotificationModel _mapToModel(
    String id,
    String title,
    String body,
    String type,
    bool isRead,
    String createdAt,
  ) {
    // 시간 파싱 및 Section 분류 ('오늘', '이전')
    String section = '이전';
    String timeText = '· $createdAt';
    try {
      if (createdAt.isNotEmpty) {
        final parsed = DateTime.tryParse(createdAt);
        if (parsed != null) {
          final now = DateTime.now();
          final difference = now.difference(parsed);
          if (difference.inDays == 0 && parsed.day == now.day) {
            section = '오늘';
            if (difference.inMinutes < 60) {
              timeText =
                  '· ${difference.inMinutes < 1 ? 1 : difference.inMinutes}분 전';
            } else {
              timeText = '· ${difference.inHours}시간 전';
            }
          } else if (difference.inDays == 1 ||
              (now.day - parsed.day == 1 && difference.inDays < 2)) {
            section = '이전';
            timeText = '· 어제';
          } else {
            section = '이전';
            timeText = '· ${difference.inDays}일 전';
          }
        }
      }
    } catch (_) {}

    // 알림 유형별 카테고리 분류 및 스타일 디자인 맵핑
    String tabCategory = '전체';
    IconData iconData = Icons.notifications_none_rounded;
    Color iconColor = const Color(0xFF64748B);
    Color iconBgColor = const Color.fromRGBO(100, 116, 139, 0.09);
    Color borderColor = const Color(0xFFE5E7EB);
    Color bgColor = const Color(0xFFFAFBFC);
    Color categoryColor = const Color(0xFF64748B);

    final normalizedType = type.trim();
    if (normalizedType == '가격 변동') {
      tabCategory = '가격 변동';
      iconData = Icons.trending_up_rounded;
      iconColor = const Color(0xFFF97316);
      iconBgColor = const Color.fromRGBO(249, 115, 22, 0.09);
      borderColor = const Color.fromRGBO(249, 115, 22, 0.2);
      bgColor = Colors.white;
      categoryColor = const Color(0xFFF97316);
    } else if (normalizedType == '제보 승인' ||
        normalizedType == '제보 반려' ||
        normalizedType == '제보') {
      tabCategory = '제보';
      iconData = Icons.check_circle_outline_rounded;
      iconColor = const Color(0xFF10B981);
      iconBgColor = const Color.fromRGBO(16, 185, 129, 0.09);
      borderColor = const Color.fromRGBO(16, 185, 129, 0.2);
      bgColor = Colors.white;
      categoryColor = const Color(0xFF10B981);
    } else if (normalizedType == '오늘의 픽' || normalizedType == '추천') {
      tabCategory = '추천';
      iconData = Icons.lightbulb_outline_rounded;
      iconColor = const Color(0xFF2563EB);
      iconBgColor = const Color.fromRGBO(37, 99, 235, 0.09);
      borderColor = const Color(0xFFE5E7EB);
      categoryColor = const Color(0xFF2563EB);
    } else if (normalizedType == '리뷰 반응') {
      tabCategory = '추천';
      iconData = Icons.thumb_up_outlined;
      iconColor = const Color(0xFF2563EB);
      iconBgColor = const Color.fromRGBO(37, 99, 235, 0.09);
      borderColor = const Color(0xFFE5E7EB);
      categoryColor = const Color(0xFF2563EB);
    } else if (normalizedType == '공지사항' || normalizedType == '공지') {
      tabCategory = '전체';
      iconData = Icons.campaign_outlined;
      iconColor = const Color(0xFF64748B);
      iconBgColor = const Color.fromRGBO(100, 116, 139, 0.09);
      borderColor = const Color(0xFFE5E7EB);
      categoryColor = const Color(0xFF64748B);
    }

    final messageText = body.isNotEmpty ? body : title;

    return NotificationModel(
      id: id,
      section: section,
      type: type,
      tabCategory: tabCategory,
      iconData: iconData,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      borderColor: borderColor,
      bgColor: bgColor,
      categoryColor: categoryColor,
      timeText: timeText,
      messageText: messageText,
      isUnread: !isRead,
    );
  }

  List<NotificationModel> _getFallbackNotifications() {
    return [
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
        tabCategory: '추천',
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
        tabCategory: '전체',
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
  }

  Future<void> markAsRead(String id) async {
    final response = await http.post(
      ApiClient.uri('/api/notifications/$id/read'),
      headers: ApiClient.jsonHeaders(auth: true),
    ).timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception('알림 읽음 처리에 실패했습니다. (${response.statusCode})');
    }
  }
}

final notificationApiServiceProvider = Provider((ref) => NotificationApiService());

class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier(this._api) : super(const AsyncValue.loading());

  final NotificationApiService _api;

  Future<void> loadNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _api.fetchNotifications();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String id) async {
    final currentList = state.valueOrNull ?? [];
    // 낙관적 업데이트
    state = AsyncValue.data([
      for (final n in currentList)
        if (n.id == id)
          NotificationModel(
            id: n.id,
            section: n.section,
            type: n.type,
            tabCategory: n.tabCategory,
            iconData: n.iconData,
            iconColor: n.iconColor,
            iconBgColor: n.iconBgColor,
            borderColor: n.borderColor,
            bgColor: n.bgColor,
            categoryColor: n.categoryColor,
            timeText: n.timeText,
            messageText: n.messageText,
            isUnread: false,
          )
        else
          n
    ]);

    try {
      await _api.markAsRead(id);
    } catch (e) {
      state = AsyncValue.data(currentList);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final currentList = state.valueOrNull ?? [];
    final unreadIds = currentList.where((n) => n.isUnread).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    // 낙관적 업데이트
    state = AsyncValue.data([
      for (final n in currentList)
        NotificationModel(
          id: n.id,
          section: n.section,
          type: n.type,
          tabCategory: n.tabCategory,
          iconData: n.iconData,
          iconColor: n.iconColor,
          iconBgColor: n.iconBgColor,
          borderColor: n.borderColor,
          bgColor: n.bgColor,
          categoryColor: n.categoryColor,
          timeText: n.timeText,
          messageText: n.messageText,
          isUnread: false,
        )
    ]);

    try {
      for (final id in unreadIds) {
        await _api.markAsRead(id);
      }
    } catch (e) {
      state = AsyncValue.data(currentList);
      rethrow;
    }
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, AsyncValue<List<NotificationModel>>>((ref) {
  final api = ref.watch(notificationApiServiceProvider);
  return NotificationsNotifier(api)..loadNotifications();
});

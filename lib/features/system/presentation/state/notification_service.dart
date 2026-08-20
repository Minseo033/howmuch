import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;

String? notificationRouteForType(String type) {
  final normalized = type.trim().toLowerCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );

  switch (normalized) {
    case '문의_답변':
    case 'inquiry':
    case 'inquiry_answer':
      return AppRoutes.inquiryHistory;
    case '가격_변동':
    case 'price':
    case 'price_change':
    case 'price_alert':
      return AppRoutes.priceAlertSubscription;
    case '제보':
    case '제보_승인':
    case '제보_반려':
    case 'report':
    case 'report_approved':
    case 'report_rejected':
      return AppRoutes.myReportsV2;
    case '새_댓글':
    case 'feed_comment':
    case '리뷰_반응':
    case 'review_reaction':
      return AppRoutes.communityFeed;
    case '추천':
    case '오늘의_픽':
    case 'recommendation':
    case 'today_pick':
      return AppRoutes.todaysPick;
    default:
      return null;
  }
}

@immutable
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.section,
    required this.type,
    required this.tabCategory,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.borderColor,
    required this.bgColor,
    required this.categoryColor,
    required this.timeText,
    required this.title,
    required this.messageText,
    required this.isUnread,
  });

  final String id;
  final String section;
  final String type;
  final String tabCategory;
  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final Color borderColor;
  final Color bgColor;
  final Color categoryColor;
  final String timeText;
  final String title;
  final String messageText;
  final bool isUnread;

  NotificationModel copyWith({bool? isUnread}) {
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
      title: title,
      messageText: messageText,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

class NotificationApiException implements Exception {
  const NotificationApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class NotificationApiService {
  NotificationApiService(this._client);

  final http.Client _client;

  Future<List<NotificationModel>> fetchNotifications() async {
    final response = await _client
        .get(
          ApiClient.uri('/api/notifications'),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw NotificationApiException(
        response.statusCode == 401 || response.statusCode == 403
            ? '알림을 확인하려면 로그인이 필요합니다.'
            : '알림을 불러오지 못했습니다.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('알림 응답 형식이 올바르지 않습니다.');
    }

    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('알림 항목 형식이 올바르지 않습니다.');
      }
      return _mapToModel(Map<String, dynamic>.from(item));
    }).toList();
  }

  NotificationModel _mapToModel(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final body = json['body']?.toString().trim() ?? '';
    final rawType = json['type']?.toString().trim() ?? '';
    final isRead = json['isRead'] == true;
    final createdAt = json['createdAt']?.toString() ?? '';
    final style = _styleFor(rawType);
    final time = _formatCreatedAt(createdAt);

    return NotificationModel(
      id: id,
      section: time.section,
      type: style.label,
      tabCategory: style.tabCategory,
      iconData: style.iconData,
      iconColor: style.iconColor,
      iconBgColor: style.iconBgColor,
      borderColor: style.borderColor,
      bgColor: style.bgColor,
      categoryColor: style.categoryColor,
      timeText: time.text,
      title: title,
      messageText: body.isNotEmpty ? body : title,
      isUnread: !isRead,
    );
  }

  _NotificationTime _formatCreatedAt(String createdAt) {
    final parsed = DateTime.tryParse(createdAt)?.toLocal();
    if (parsed == null) {
      return const _NotificationTime(section: '이전', text: '');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final createdDay = DateTime(parsed.year, parsed.month, parsed.day);
    final dayDifference = today.difference(createdDay).inDays;
    final elapsed = now.isBefore(parsed)
        ? Duration.zero
        : now.difference(parsed);

    if (dayDifference <= 0) {
      if (elapsed.inMinutes < 60) {
        final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
        return _NotificationTime(section: '오늘', text: '· $minutes분 전');
      }
      return _NotificationTime(section: '오늘', text: '· ${elapsed.inHours}시간 전');
    }
    if (dayDifference == 1) {
      return const _NotificationTime(section: '이전', text: '· 어제');
    }
    return _NotificationTime(section: '이전', text: '· $dayDifference일 전');
  }

  _NotificationStyle _styleFor(String rawType) {
    final type = rawType.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

    if (rawType == '문의 답변' || type == 'inquiry' || type == 'inquiry_answer') {
      return const _NotificationStyle(
        label: '문의 답변',
        tabCategory: '전체',
        iconData: Icons.support_agent_outlined,
        iconColor: Color(0xFF7C3AED),
        iconBgColor: Color.fromRGBO(124, 58, 237, 0.09),
        borderColor: Color.fromRGBO(124, 58, 237, 0.2),
        bgColor: Colors.white,
        categoryColor: Color(0xFF7C3AED),
      );
    }

    if (rawType == '가격 변동' ||
        type == 'price' ||
        type == 'price_change' ||
        type == 'price_alert') {
      return const _NotificationStyle(
        label: '가격 변동',
        tabCategory: '가격 변동',
        iconData: Icons.trending_up_rounded,
        iconColor: Color(0xFFF97316),
        iconBgColor: Color.fromRGBO(249, 115, 22, 0.09),
        borderColor: Color.fromRGBO(249, 115, 22, 0.2),
        bgColor: Colors.white,
        categoryColor: Color(0xFFF97316),
      );
    }
    if (type == 'feed_comment') {
      return const _NotificationStyle(
        label: '새 댓글',
        tabCategory: '전체',
        iconData: Icons.chat_bubble_outline_rounded,
        iconColor: Color(0xFF2563EB),
        iconBgColor: Color.fromRGBO(37, 99, 235, 0.09),
        borderColor: Color(0xFFE5E7EB),
        bgColor: Color(0xFFFAFBFC),
        categoryColor: Color(0xFF2563EB),
      );
    }
    if (rawType == '제보 승인' ||
        rawType == '제보 반려' ||
        rawType == '제보' ||
        type == 'report' ||
        type == 'report_approved' ||
        type == 'report_rejected') {
      return _NotificationStyle(
        label: rawType == '제보 반려' || type == 'report_rejected' ? '제보 반려' : '제보',
        tabCategory: '제보',
        iconData: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color.fromRGBO(16, 185, 129, 0.09),
        borderColor: const Color.fromRGBO(16, 185, 129, 0.2),
        bgColor: Colors.white,
        categoryColor: const Color(0xFF10B981),
      );
    }
    if (rawType == '오늘의 픽' ||
        rawType == '추천' ||
        rawType == '리뷰 반응' ||
        type == 'today_pick' ||
        type == 'recommendation' ||
        type == 'review_reaction') {
      return _NotificationStyle(
        label: rawType.isNotEmpty ? rawType : '추천',
        tabCategory: '추천',
        iconData: rawType == '리뷰 반응' || type == 'review_reaction'
            ? Icons.thumb_up_outlined
            : Icons.lightbulb_outline_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color.fromRGBO(37, 99, 235, 0.09),
        borderColor: const Color(0xFFE5E7EB),
        bgColor: const Color(0xFFFAFBFC),
        categoryColor: const Color(0xFF2563EB),
      );
    }

    final isNotice =
        rawType == '공지사항' ||
        rawType == '공지' ||
        type == 'admin' ||
        type == 'notice';
    return _NotificationStyle(
      label: isNotice ? '공지사항' : (rawType.isEmpty ? '알림' : rawType),
      tabCategory: '전체',
      iconData: isNotice
          ? Icons.campaign_outlined
          : Icons.notifications_none_rounded,
      iconColor: const Color(0xFF64748B),
      iconBgColor: const Color.fromRGBO(100, 116, 139, 0.09),
      borderColor: const Color(0xFFE5E7EB),
      bgColor: const Color(0xFFFAFBFC),
      categoryColor: const Color(0xFF64748B),
    );
  }

  Future<void> markAsRead(String id) async {
    final response = await _client
        .post(
          ApiClient.uri('/api/notifications/$id/read'),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw NotificationApiException(
        '알림 읽음 처리에 실패했습니다.',
        statusCode: response.statusCode,
      );
    }
  }
}

class _NotificationTime {
  const _NotificationTime({required this.section, required this.text});

  final String section;
  final String text;
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.label,
    required this.tabCategory,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.borderColor,
    required this.bgColor,
    required this.categoryColor,
  });

  final String label;
  final String tabCategory;
  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final Color borderColor;
  final Color bgColor;
  final Color categoryColor;
}

final notificationHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final notificationApiServiceProvider = Provider<NotificationApiService>((ref) {
  return NotificationApiService(ref.watch(notificationHttpClientProvider));
});

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier(this._api) : super(const AsyncValue.loading()) {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => loadNotifications(isRefresh: true),
    );
  }

  final NotificationApiService _api;
  Timer? _refreshTimer;
  bool _isLoading = false;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadNotifications({bool isRefresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    final previousList = state.valueOrNull;
    if (!isRefresh) {
      state = const AsyncValue.loading();
    }
    try {
      state = AsyncValue.data(await _api.fetchNotifications());
    } catch (error, stackTrace) {
      if (isRefresh && previousList != null) {
        state = AsyncValue.data(previousList);
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> markRead(String id) async {
    final currentList = state.valueOrNull ?? const [];
    final target = currentList.where((item) => item.id == id).firstOrNull;
    if (target == null || !target.isUnread) return;

    state = AsyncValue.data([
      for (final notification in currentList)
        notification.id == id
            ? notification.copyWith(isUnread: false)
            : notification,
    ]);

    try {
      await _api.markAsRead(id);
    } catch (_) {
      state = AsyncValue.data(currentList);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final currentList = state.valueOrNull ?? const [];
    final unreadIds = currentList
        .where((notification) => notification.isUnread)
        .map((notification) => notification.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (unreadIds.isEmpty) return;

    state = AsyncValue.data([
      for (final notification in currentList)
        notification.copyWith(isUnread: false),
    ]);

    try {
      for (final id in unreadIds) {
        await _api.markAsRead(id);
      }
    } catch (_) {
      await loadNotifications(isRefresh: true);
      rethrow;
    }
  }
}

final notificationsProvider =
    StateNotifierProvider.autoDispose<
      NotificationsNotifier,
      AsyncValue<List<NotificationModel>>
    >((ref) {
      return NotificationsNotifier(ref.watch(notificationApiServiceProvider))
        ..loadNotifications();
    });

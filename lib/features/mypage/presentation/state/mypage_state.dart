import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  const UserProfile({
    required this.nickname,
    required this.email,
    required this.level,
    required this.region,
    required this.favoriteCategories,
    required this.savedAmount,
    required this.visitCount,
    required this.reportCount,
    required this.favoriteStoreCount,
    required this.nicknamePublic,
    required this.activityPublic,
  });

  final String nickname;
  final String email;
  final String level;
  final String region;
  final List<String> favoriteCategories;
  final int savedAmount;
  final int visitCount;
  final int reportCount;
  final int favoriteStoreCount;
  final bool nicknamePublic;
  final bool activityPublic;

  String get savedAmountText {
    final text = savedAmount.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  UserProfile copyWith({
    String? nickname,
    String? email,
    String? level,
    String? region,
    List<String>? favoriteCategories,
    int? savedAmount,
    int? visitCount,
    int? reportCount,
    int? favoriteStoreCount,
    bool? nicknamePublic,
    bool? activityPublic,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      level: level ?? this.level,
      region: region ?? this.region,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      savedAmount: savedAmount ?? this.savedAmount,
      visitCount: visitCount ?? this.visitCount,
      reportCount: reportCount ?? this.reportCount,
      favoriteStoreCount: favoriteStoreCount ?? this.favoriteStoreCount,
      nicknamePublic: nicknamePublic ?? this.nicknamePublic,
      activityPublic: activityPublic ?? this.activityPublic,
    );
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.all,
    required this.review,
    required this.report,
    required this.price,
    required this.todayPick,
    required this.quietHours,
    required this.quietStart,
    required this.quietEnd,
  });

  final bool all;
  final bool review;
  final bool report;
  final bool price;
  final bool todayPick;
  final bool quietHours;
  final String quietStart;
  final String quietEnd;

  NotificationSettings copyWith({
    bool? all,
    bool? review,
    bool? report,
    bool? price,
    bool? todayPick,
    bool? quietHours,
    String? quietStart,
    String? quietEnd,
  }) {
    return NotificationSettings(
      all: all ?? this.all,
      review: review ?? this.review,
      report: report ?? this.report,
      price: price ?? this.price,
      todayPick: todayPick ?? this.todayPick,
      quietHours: quietHours ?? this.quietHours,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }
}

class PriceAlertStore {
  const PriceAlertStore({
    required this.storeName,
    required this.menuName,
    required this.enabled,
  });

  final String storeName;
  final String menuName;
  final bool enabled;

  PriceAlertStore copyWith({bool? enabled}) {
    return PriceAlertStore(
      storeName: storeName,
      menuName: menuName,
      enabled: enabled ?? this.enabled,
    );
  }
}

class UserReportStatus {
  const UserReportStatus({
    required this.id,
    required this.store,
    required this.menu,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.textColor,
  });

  final String id;
  final String store;
  final String menu;
  final String status;
  final int statusColor;
  final int statusBg;
  final int textColor;
}

class PriceAlertSettings {
  const PriceAlertSettings({
    required this.all,
    required this.stores,
    required this.notifyOnDrop,
    required this.notifyOnRise,
    required this.notifyOnNewMenu,
  });

  final bool all;
  final List<PriceAlertStore> stores;
  final bool notifyOnDrop;
  final bool notifyOnRise;
  final bool notifyOnNewMenu;

  PriceAlertSettings copyWith({
    bool? all,
    List<PriceAlertStore>? stores,
    bool? notifyOnDrop,
    bool? notifyOnRise,
    bool? notifyOnNewMenu,
  }) {
    return PriceAlertSettings(
      all: all ?? this.all,
      stores: stores ?? this.stores,
      notifyOnDrop: notifyOnDrop ?? this.notifyOnDrop,
      notifyOnRise: notifyOnRise ?? this.notifyOnRise,
      notifyOnNewMenu: notifyOnNewMenu ?? this.notifyOnNewMenu,
    );
  }
}

class SocialAccount {
  const SocialAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.connected,
    required this.connectedAt,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final String email;
  final bool connected;
  final String connectedAt;
  final bool isPrimary;

  SocialAccount copyWith({
    String? email,
    bool? connected,
    String? connectedAt,
    bool? isPrimary,
  }) {
    return SocialAccount(
      id: id,
      name: name,
      email: email ?? this.email,
      connected: connected ?? this.connected,
      connectedAt: connectedAt ?? this.connectedAt,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

// TODO(박지환 BE): 사용자 프로필 API 응답으로 교체하세요.
final userProfileProvider = StateProvider<UserProfile>(
  (ref) => const UserProfile(
    nickname: '절약왕 민서',
    email: 'minseo@email.com',
    level: 'LV.3 절약러',
    region: '서울시 강남구 역삼동',
    favoriteCategories: ['한식', '분식', '카페'],
    savedAmount: 24500,
    visitCount: 12,
    reportCount: 2,
    favoriteStoreCount: 12,
    nicknamePublic: true,
    activityPublic: false,
  ),
);

// TODO(박지환 BE): 내 제보 목록/상태 API 응답으로 교체하세요.
final userReportsProvider = StateProvider<List<UserReportStatus>>(
  (ref) => const [
    UserReportStatus(
      id: 'report-golmok',
      store: '골목밥상',
      menu: '제육덮밥 6,000원',
      status: '검토 중',
      statusColor: 0xFFF59E0B,
      statusBg: 0xFFFEF3C7,
      textColor: 0xFF92400E,
    ),
    UserReportStatus(
      id: 'report-cafe',
      store: '동네카페',
      menu: '아메리카노 2,000원',
      status: '승인 완료',
      statusColor: 0xFF10B981,
      statusBg: 0xFFE8F8F1,
      textColor: 0xFF10B981,
    ),
  ],
);

final notificationSettingsProvider = StateProvider<NotificationSettings>(
  (ref) => const NotificationSettings(
    all: true,
    review: false,
    report: true,
    price: true,
    todayPick: true,
    quietHours: true,
    quietStart: '오후 10:00',
    quietEnd: '오전 08:00',
  ),
);

final priceAlertSettingsProvider = StateProvider<PriceAlertSettings>(
  (ref) => const PriceAlertSettings(
    all: true,
    stores: [
      PriceAlertStore(
        storeName: '착한분식',
        menuName: '김치찌개 5,500원',
        enabled: true,
      ),
      PriceAlertStore(
        storeName: '동네카페',
        menuName: '아메리카노 2,000원',
        enabled: true,
      ),
      PriceAlertStore(
        storeName: '착한미용실',
        menuName: '남성컷 8,000원',
        enabled: false,
      ),
    ],
    notifyOnDrop: true,
    notifyOnRise: true,
    notifyOnNewMenu: false,
  ),
);

final socialAccountsProvider = StateProvider<List<SocialAccount>>(
  (ref) => const [
    SocialAccount(
      id: 'kakao',
      name: '카카오',
      email: 'minseo@email.com',
      connected: true,
      connectedAt: '2025.10.04',
      isPrimary: true,
    ),
    SocialAccount(
      id: 'apple',
      name: 'Apple ID',
      email: 'minseo@privaterelay.apple',
      connected: true,
      connectedAt: '2026.02.18',
      isPrimary: false,
    ),
    SocialAccount(
      id: 'naver',
      name: '네이버',
      email: '',
      connected: false,
      connectedAt: '',
      isPrimary: false,
    ),
    SocialAccount(
      id: 'google',
      name: 'Google',
      email: '',
      connected: false,
      connectedAt: '',
      isPrimary: false,
    ),
  ],
);

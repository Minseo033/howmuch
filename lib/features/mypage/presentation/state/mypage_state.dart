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

class UserReportMenuPrice {
  const UserReportMenuPrice({required this.menu, required this.price});

  final String menu;
  final String price;

  String get displayText {
    if (menu.isEmpty && price.isEmpty) return '';
    final displayPrice = price.endsWith('원') ? price : '$price원';
    if (menu.isEmpty) return displayPrice;
    if (price.isEmpty) return menu;
    return '$menu $displayPrice';
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
    this.category = '',
    this.address = '',
    this.menuPrices = const [],
    this.imageUrls = const [],
    this.visitedRecently = true,
    this.checkedMenuPrice = true,
    this.createdAt = '',
    this.rejectReason = '',
  });

  final String id;
  final String store;
  final String menu;
  final String status;
  final int statusColor;
  final int statusBg;
  final int textColor;
  final String category;
  final String address;
  final List<UserReportMenuPrice> menuPrices;
  final List<String> imageUrls;
  final bool visitedRecently;
  final bool checkedMenuPrice;
  final String createdAt;
  final String rejectReason;

  factory UserReportStatus.fromJson(Map<String, dynamic> json) {
    final status = _statusLabel(json['status']?.toString() ?? '');
    final colors = _statusColors(status);
    final menuPrices = _menuPricesFromJson(json);
    final menu = menuPrices.isNotEmpty ? menuPrices.first.displayText : '';

    return UserReportStatus(
      id: json['id']?.toString() ?? '',
      store: json['storeName']?.toString() ?? '',
      menu: menu,
      status: status,
      statusColor: colors.statusColor,
      statusBg: colors.statusBg,
      textColor: colors.textColor,
      category: json['industry']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      menuPrices: menuPrices,
      imageUrls: _stringList(json['imageUrls']),
      visitedRecently: json['visitedRecently'] is bool
          ? json['visitedRecently'] as bool
          : true,
      checkedMenuPrice: json['checkedMenuPrice'] is bool
          ? json['checkedMenuPrice'] as bool
          : true,
      createdAt: json['createdAt']?.toString() ?? '',
      rejectReason: json['rejectReason']?.toString() ?? '',
    );
  }

  UserReportStatus copyWith({
    String? id,
    String? store,
    String? menu,
    String? status,
    int? statusColor,
    int? statusBg,
    int? textColor,
    String? category,
    String? address,
    List<UserReportMenuPrice>? menuPrices,
    List<String>? imageUrls,
    bool? visitedRecently,
    bool? checkedMenuPrice,
    String? createdAt,
    String? rejectReason,
  }) {
    return UserReportStatus(
      id: id ?? this.id,
      store: store ?? this.store,
      menu: menu ?? this.menu,
      status: status ?? this.status,
      statusColor: statusColor ?? this.statusColor,
      statusBg: statusBg ?? this.statusBg,
      textColor: textColor ?? this.textColor,
      category: category ?? this.category,
      address: address ?? this.address,
      menuPrices: menuPrices ?? this.menuPrices,
      imageUrls: imageUrls ?? this.imageUrls,
      visitedRecently: visitedRecently ?? this.visitedRecently,
      checkedMenuPrice: checkedMenuPrice ?? this.checkedMenuPrice,
      createdAt: createdAt ?? this.createdAt,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static List<UserReportMenuPrice> _menuPricesFromJson(
    Map<String, dynamic> json,
  ) {
    return [
      for (var index = 1; index <= 4; index++)
        UserReportMenuPrice(
          menu: json['menu$index']?.toString() ?? '',
          price: json['price$index']?.toString() ?? '',
        ),
    ].where((item) => item.menu.isNotEmpty || item.price.isNotEmpty).toList();
  }

  static String _statusLabel(String value) {
    final normalized = value.toUpperCase();
    if (normalized.contains('APPROVED') || value.contains('승인')) {
      return '승인 완료';
    }
    if (normalized.contains('NEEDS') ||
        normalized.contains('REVISION') ||
        value.contains('보완')) {
      return '보완 요청';
    }
    if (normalized.contains('REJECTED') || value.contains('반려')) {
      return '반려';
    }
    return '검토 중';
  }

  static ({int statusColor, int statusBg, int textColor}) _statusColors(
    String status,
  ) {
    if (status.contains('승인')) {
      return (
        statusColor: 0xFF10B981,
        statusBg: 0xFFE8F8F1,
        textColor: 0xFF047857,
      );
    }
    if (status.contains('보완')) {
      return (
        statusColor: 0xFFF97316,
        statusBg: 0xFFFEF3C7,
        textColor: 0xFF92400E,
      );
    }
    if (status.contains('반려')) {
      return (
        statusColor: 0xFFEF4444,
        statusBg: 0xFFFEE2E2,
        textColor: 0xFF991B1B,
      );
    }
    return (
      statusColor: 0xFFF59E0B,
      statusBg: 0xFFFEF3C7,
      textColor: 0xFF92400E,
    );
  }
}

class UserReportsNotifier extends StateNotifier<List<UserReportStatus>> {
  UserReportsNotifier(super.initialState);

  void addReport(UserReportStatus report) {
    state = [report, ...state];
  }

  void updateReport(UserReportStatus report) {
    state = [
      for (final current in state)
        if (current.id == report.id) report else current,
    ];
  }

  void removeReport(String id) {
    state = state.where((report) => report.id != id).toList();
  }

  void setReports(List<UserReportStatus> reports) {
    state = reports;
  }

  void mergeFetchedReports(List<UserReportStatus> reports) {
    final temporaryReports = state.where((report) {
      if (!report.id.startsWith('report-')) return false;
      return !reports.any(
        (fetched) =>
            fetched.store == report.store && fetched.menu == report.menu,
      );
    });

    state = [...temporaryReports, ...reports];
  }
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

class FavoriteStoreModel {
  const FavoriteStoreModel({
    required this.id,
    required this.category,
    required this.iconEmoji,
    required this.iconBgColor,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBgColor,
    required this.distance,
    required this.storeName,
    required this.menu,
    required this.price,
    required this.priceColor,
    this.alertText,
    this.alertColor,
    required this.buttonText,
    required this.buttonColor,
    required this.buttonTextColor,
    this.isFavorite = true,
  });

  final String id;
  final String category;
  final String iconEmoji;
  final int iconBgColor;
  final String badgeText;
  final int badgeColor;
  final int badgeBgColor;
  final String distance;
  final String storeName;
  final String menu;
  final String price;
  final int priceColor;
  final String? alertText;
  final int? alertColor;
  final String buttonText;
  final int buttonColor;
  final int buttonTextColor;
  final bool isFavorite;

  FavoriteStoreModel copyWith({bool? isFavorite}) {
    return FavoriteStoreModel(
      id: id,
      category: category,
      iconEmoji: iconEmoji,
      iconBgColor: iconBgColor,
      badgeText: badgeText,
      badgeColor: badgeColor,
      badgeBgColor: badgeBgColor,
      distance: distance,
      storeName: storeName,
      menu: menu,
      price: price,
      priceColor: priceColor,
      alertText: alertText,
      alertColor: alertColor,
      buttonText: buttonText,
      buttonColor: buttonColor,
      buttonTextColor: buttonTextColor,
      isFavorite: isFavorite ?? this.isFavorite,
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
    reportCount: 3,
    favoriteStoreCount: 12,
    nicknamePublic: true,
    activityPublic: false,
  ),
);

// TODO(박지환 BE): 내 제보 목록/상태 API 응답으로 교체하세요.
final userReportsProvider =
    StateNotifierProvider<UserReportsNotifier, List<UserReportStatus>>(
      (ref) => UserReportsNotifier(const []),
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

// TODO(박지환 BE): 찜한 매장 API 응답으로 교체하세요.
final favoriteStoresProvider = StateProvider<List<FavoriteStoreModel>>(
  (ref) => const [
    FavoriteStoreModel(
      id: '1',
      category: '음식점',
      iconEmoji: '🍚',
      iconBgColor: 0xFFDBEAFE, // AppColors.primaryLight
      badgeText: '정부 인증',
      badgeColor: 0xFF2563EB, // AppColors.primary
      badgeBgColor: 0xFFDBEAFE, // AppColors.primaryLight
      distance: '320m',
      storeName: '착한분식',
      menu: '김치찌개',
      price: '5,500원',
      priceColor: 0xFF2563EB, // AppColors.primary
      alertText: '✓ 최근 가격 변동 없음',
      alertColor: 0xFF64748B, // AppColors.muted
      buttonText: '길찾기',
      buttonColor: 0xFF2563EB, // AppColors.primary
      buttonTextColor: 0xFFFFFFFF, // AppColors.white
    ),
    FavoriteStoreModel(
      id: '2',
      category: '카페',
      iconEmoji: '☕',
      iconBgColor: 0xFFFFEDD5, // AppColors.warningLight
      badgeText: '사용자 제보',
      badgeColor: 0xFFF97316, // AppColors.warning
      badgeBgColor: 0xFFFFEDD5, // AppColors.warningLight
      distance: '540m',
      storeName: '동네카페',
      menu: '아메리카노',
      price: '2,000원',
      priceColor: 0xFFF97316, // AppColors.warning
      alertText: '⚠️ 가격 변동 제보 1건',
      alertColor: 0xFFF97316, // AppColors.warning
      buttonText: '상세보기',
      buttonColor: 0xFFF8FAFC, // AppColors.background
      buttonTextColor: 0xFF0F172A, // AppColors.ink
    ),
    FavoriteStoreModel(
      id: '3',
      category: '생활서비스',
      iconEmoji: '✂️',
      iconBgColor: 0xFFDBEAFE, // AppColors.primaryLight
      badgeText: '정부 인증',
      badgeColor: 0xFF2563EB, // AppColors.primary
      badgeBgColor: 0xFFDBEAFE, // AppColors.primaryLight
      distance: '1.1km',
      storeName: '착한미용실',
      menu: '커트',
      price: '8,000원',
      priceColor: 0xFF2563EB, // AppColors.primary
      buttonText: '길찾기',
      buttonColor: 0xFF2563EB, // AppColors.primary
      buttonTextColor: 0xFFFFFFFF, // AppColors.white
    ),
  ],
);

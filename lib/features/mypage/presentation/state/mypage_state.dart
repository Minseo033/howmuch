import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;

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
    this.profileImageUrl = '',
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
  final String profileImageUrl;

  static const guest = UserProfile(
    nickname: '게스트',
    email: '',
    level: 'LV.1 새싹',
    region: '',
    favoriteCategories: [],
    savedAmount: 0,
    visitCount: 0,
    reportCount: 0,
    favoriteStoreCount: 0,
    nicknamePublic: true,
    activityPublic: false,
  );

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
    String? profileImageUrl,
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
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
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

  static const defaults = NotificationSettings(
    all: true,
    review: true,
    report: true,
    price: true,
    todayPick: true,
    quietHours: false,
    quietStart: '22:00',
    quietEnd: '08:00',
  );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      all: json['all'] is bool ? json['all'] as bool : defaults.all,
      review: json['review'] is bool ? json['review'] as bool : defaults.review,
      report: json['report'] is bool ? json['report'] as bool : defaults.report,
      price: json['price'] is bool ? json['price'] as bool : defaults.price,
      todayPick: json['todayPick'] is bool
          ? json['todayPick'] as bool
          : defaults.todayPick,
      quietHours: json['quietHours'] is bool
          ? json['quietHours'] as bool
          : defaults.quietHours,
      quietStart: json['quietStart']?.toString() ?? defaults.quietStart,
      quietEnd: json['quietEnd']?.toString() ?? defaults.quietEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'all': all,
      'review': review,
      'report': report,
      'price': price,
      'todayPick': todayPick,
      'quietHours': quietHours,
      'quietStart': quietStart,
      'quietEnd': quietEnd,
    };
  }

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
    required this.storeId,
    required this.storeName,
    required this.menuName,
    required this.enabled,
  });

  final String storeId;
  final String storeName;
  final String menuName;
  final bool enabled;

  PriceAlertStore copyWith({bool? enabled}) {
    return PriceAlertStore(
      storeId: storeId,
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
    this.createdAt,
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
  final DateTime? createdAt;
  final bool isFavorite;

  factory FavoriteStoreModel.fromJson(Map<String, dynamic> json) {
    final storeName = json['storeName']?.toString().trim();
    final storeId = json['storeId']?.toString().trim() ?? '';
    final createdAtText = json['createdAt']?.toString();
    // 8/7: 백엔드가 공공데이터 인메모리 캐시에서 매칭한 매장 메타(업종/대표메뉴/가격/주소)를 동봉.
    //      제보 매장 등 캐시 미스 시 null → 기존 placeholder 유지.
    final industry = json['industry']?.toString().trim();
    final menu1 = json['menu1']?.toString().trim();
    final price1 = json['price1']?.toString().trim();
    final hasMeta = industry != null && industry.isNotEmpty;

    return FavoriteStoreModel(
      id: storeId.isNotEmpty ? storeId : json['id']?.toString() ?? '',
      category: hasMeta ? industry : '전체',
      iconEmoji: _emojiForStore(industry, storeName ?? ''),
      iconBgColor: 0xFFDBEAFE,
      badgeText: hasMeta ? '착한가격업소' : '찜한 매장',
      badgeColor: 0xFF2563EB,
      badgeBgColor: 0xFFDBEAFE,
      distance: '저장됨',
      storeName: storeName?.isNotEmpty == true ? storeName! : '매장명 없음',
      menu: (menu1 != null && menu1.isNotEmpty)
          ? menu1
          : '상세 정보는 매장 화면에서 확인해 주세요',
      price: _formatPrice(price1),
      priceColor: 0xFF2563EB,
      buttonText: '찜 해제',
      buttonColor: 0xFFFEE2E2,
      buttonTextColor: 0xFFDC2626,
      createdAt: createdAtText == null
          ? null
          : DateTime.tryParse(createdAtText),
    );
  }

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
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  static String _emojiForStore(String? industry, String name) {
    final key = '${industry ?? ''} $name';
    if (key.contains('카페') || key.contains('커피')) return '☕';
    if (key.contains('미용') || key.contains('헤어') || key.contains('이용')) {
      return '✂️';
    }
    if (key.contains('세탁')) return '🧺';
    if (key.contains('숙박')) return '🛏️';
    if (key.contains('목욕')) return '🛁';
    if (key.contains('중식')) return '🥟';
    if (key.contains('일식')) return '🍣';
    if (key.contains('양식')) return '🍝';
    if (key.contains('분식') || key.contains('국수')) return '🍜';
    return '🍽️';
  }

  /// "5000" → "5,000원" (숫자 아닌 문자 제거 후 천 단위 구분. 파싱 실패 시 원문 유지)
  static String _formatPrice(String? price1) {
    if (price1 == null || price1.isEmpty) return '';
    final digits = price1.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return price1;
    final value = int.tryParse(digits);
    if (value == null) return price1;
    final s = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return '$buffer원';
  }
}

// 💡 감사 이슈(#4): 하드코딩 목업('절약왕 민서', 24,500원 등) 제거.
//    기본값은 게스트 상태이며, 로그인 시 mypage_screen의 _loadProfileSummary가
//    /api/user/profile + /api/savings/stats + /api/report/my + /api/favorites로 실데이터를 채웁니다.
final userProfileProvider = StateProvider<UserProfile>(
  (ref) => UserProfile.guest,
);

// 서버의 내 제보 목록을 화면 간 공유하고, 제출 직후에는 응답받은 ID로 즉시 반영합니다.
final userReportsProvider =
    StateNotifierProvider<UserReportsNotifier, List<UserReportStatus>>(
      (ref) => UserReportsNotifier(const []),
    );

class NotificationSettingsApiException implements Exception {
  const NotificationSettingsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class NotificationSettingsApiService {
  const NotificationSettingsApiService(this._client);

  final http.Client _client;

  Future<NotificationSettings> fetchSettings() async {
    final response = await _client
        .get(
          ApiClient.uri('/api/notifications/settings'),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);
    return _parseResponse(response, action: '불러오기');
  }

  Future<NotificationSettings> saveSettings(
    NotificationSettings settings,
  ) async {
    final response = await _client
        .put(
          ApiClient.uri('/api/notifications/settings'),
          headers: ApiClient.jsonHeaders(auth: true),
          body: jsonEncode(settings.toJson()),
        )
        .timeout(ApiClient.defaultTimeout);
    return _parseResponse(response, action: '저장');
  }

  NotificationSettings _parseResponse(
    http.Response response, {
    required String action,
  }) {
    if (response.statusCode != 200) {
      throw NotificationSettingsApiException(
        response.statusCode == 401 || response.statusCode == 403
            ? '알림 설정을 사용하려면 로그인이 필요합니다.'
            : '알림 설정 $action에 실패했습니다.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('알림 설정 응답 형식이 올바르지 않습니다.');
    }
    return NotificationSettings.fromJson(Map<String, dynamic>.from(decoded));
  }
}

final notificationSettingsApiServiceProvider =
    Provider<NotificationSettingsApiService>((ref) {
      final client = ApiClient.createHttpClient();
      ref.onDispose(client.close);
      return NotificationSettingsApiService(client);
    });

class NotificationSettingsNotifier
    extends StateNotifier<AsyncValue<NotificationSettings>> {
  NotificationSettingsNotifier(this._api) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  final NotificationSettingsApiService _api;

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _api.fetchSettings());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void updateSettings(NotificationSettings settings) {
    state = AsyncValue.data(settings);
  }

  Future<bool> saveSettings(NotificationSettings settings) async {
    try {
      state = AsyncValue.data(await _api.saveSettings(settings));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final notificationSettingsProvider =
    StateNotifierProvider.autoDispose<
      NotificationSettingsNotifier,
      AsyncValue<NotificationSettings>
    >(
      (ref) => NotificationSettingsNotifier(
        ref.watch(notificationSettingsApiServiceProvider),
      ),
    );

class PriceAlertApiException implements Exception {
  const PriceAlertApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PriceAlertApiService {
  const PriceAlertApiService(this._client);

  final http.Client _client;

  Future<PriceAlertSettings> fetchSettings() async {
    final response = await _client
        .get(
          ApiClient.uri('/api/notifications/price-alerts'),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw PriceAlertApiException(
        response.statusCode == 401 || response.statusCode == 403
            ? '가격 알림을 사용하려면 로그인이 필요합니다.'
            : '가격 알림 매장 목록을 불러오지 못했습니다.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('가격 알림 응답 형식이 올바르지 않습니다.');
    }

    final items = decoded.whereType<Map>().toList(growable: false);
    final stores = items
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          final price = json['price']?.toString().trim() ?? '';
          final menu = json['menuName']?.toString().trim() ?? '';
          final menuName = menu.isEmpty
              ? '가격 변동 알림'
              : price.isEmpty || price.endsWith('원')
              ? menu
              : '$menu $price원';
          return PriceAlertStore(
            storeId: json['storeId']?.toString() ?? '',
            storeName: json['storeName']?.toString() ?? '매장명 없음',
            menuName: menuName,
            enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
          );
        })
        .where((store) => store.storeId.isNotEmpty)
        .toList(growable: false);
    final first = items.isEmpty ? null : items.first;
    return PriceAlertSettings(
      all: stores.isNotEmpty && stores.every((store) => store.enabled),
      stores: stores,
      notifyOnRise: first?['notifyOnRise'] is bool
          ? first!['notifyOnRise'] as bool
          : true,
      notifyOnDrop: first?['notifyOnDrop'] is bool
          ? first!['notifyOnDrop'] as bool
          : true,
      notifyOnNewMenu: first?['notifyOnNewMenu'] is bool
          ? first!['notifyOnNewMenu'] as bool
          : false,
    );
  }

  Future<PriceAlertStore> saveSubscription({
    required String storeId,
    required bool enabled,
    required bool notifyOnRise,
    required bool notifyOnDrop,
    required bool notifyOnNewMenu,
  }) async {
    final response = await _client
        .put(
          ApiClient.uri('/api/notifications/price-alerts'),
          headers: ApiClient.jsonHeaders(auth: true),
          body: jsonEncode({
            'storeId': storeId,
            'enabled': enabled,
            'notifyOnRise': notifyOnRise,
            'notifyOnDrop': notifyOnDrop,
            'notifyOnNewMenu': notifyOnNewMenu,
          }),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw PriceAlertApiException(
        response.statusCode == 401 || response.statusCode == 403
            ? '가격 알림을 사용하려면 로그인이 필요합니다.'
            : response.statusCode == 404
            ? '찜한 매장을 찾을 수 없습니다.'
            : '가격 알림 설정 저장에 실패했습니다.',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('가격 알림 저장 응답 형식이 올바르지 않습니다.');
    }
    final json = Map<String, dynamic>.from(decoded);
    return PriceAlertStore(
      storeId: json['storeId']?.toString() ?? storeId,
      storeName: json['storeName']?.toString() ?? '매장명 없음',
      menuName: json['menuName']?.toString() ?? '가격 변동 알림',
      enabled: json['enabled'] is bool ? json['enabled'] as bool : enabled,
    );
  }
}

final priceAlertApiServiceProvider = Provider<PriceAlertApiService>((ref) {
  final client = ApiClient.createHttpClient();
  ref.onDispose(client.close);
  return PriceAlertApiService(client);
});

class PriceAlertSettingsNotifier
    extends StateNotifier<AsyncValue<PriceAlertSettings>> {
  PriceAlertSettingsNotifier(this._api) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  final PriceAlertApiService _api;

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _api.fetchSettings());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void updateLocal(PriceAlertSettings settings) {
    state = AsyncValue.data(settings);
  }

  Future<bool> saveSettings(PriceAlertSettings settings) async {
    try {
      final savedStores = <PriceAlertStore>[];
      for (final store in settings.stores) {
        savedStores.add(
          await _api.saveSubscription(
            storeId: store.storeId,
            enabled: store.enabled,
            notifyOnRise: settings.notifyOnRise,
            notifyOnDrop: settings.notifyOnDrop,
            notifyOnNewMenu: settings.notifyOnNewMenu,
          ),
        );
      }
      state = AsyncValue.data(
        settings.copyWith(
          stores: savedStores,
          all:
              savedStores.isNotEmpty &&
              savedStores.every((store) => store.enabled),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final priceAlertSettingsProvider =
    StateNotifierProvider.autoDispose<
      PriceAlertSettingsNotifier,
      AsyncValue<PriceAlertSettings>
    >((ref) {
      return PriceAlertSettingsNotifier(
        ref.watch(priceAlertApiServiceProvider),
      );
    });

final favoriteApiServiceProvider = Provider((ref) => FavoriteApiService());

final favoriteStoresProvider =
    StateNotifierProvider.autoDispose<
      FavoriteStoresNotifier,
      AsyncValue<List<FavoriteStoreModel>>
    >(
      (ref) => FavoriteStoresNotifier(
        ref.read(favoriteApiServiceProvider),
        ref.read(userProfileProvider.notifier),
      ),
    );

class FavoriteApiService {
  Future<List<FavoriteStoreModel>> fetchFavorites() async {
    final res = await ApiClient.get(
      ApiClient.uri('/api/favorites'),
      headers: ApiClient.jsonHeaders(auth: true),
    ).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      throw Exception('찜 목록을 불러오지 못했습니다. (${res.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              FavoriteStoreModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<FavoriteStoreModel> addFavorite({
    required String storeId,
    required String storeName,
  }) async {
    final res = await ApiClient.post(
      ApiClient.uri('/api/favorites'),
      headers: ApiClient.jsonHeaders(auth: true),
      body: jsonEncode({'storeId': storeId, 'storeName': storeName}),
    ).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      throw Exception('찜 추가에 실패했습니다. (${res.statusCode})');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map) {
      throw Exception('찜 추가 응답을 확인할 수 없습니다.');
    }
    return FavoriteStoreModel.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> removeFavorite(String storeId) async {
    final res = await ApiClient.delete(
      ApiClient.uri('/api/favorites/${Uri.encodeComponent(storeId)}'),
      headers: ApiClient.jsonHeaders(auth: true),
    ).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      throw Exception('찜 해제에 실패했습니다. (${res.statusCode})');
    }
  }
}

class FavoriteStoresNotifier
    extends StateNotifier<AsyncValue<List<FavoriteStoreModel>>> {
  FavoriteStoresNotifier(this._api, this._profileNotifier)
    : super(const AsyncValue.loading());

  final FavoriteApiService _api;
  final StateController<UserProfile> _profileNotifier;
  bool _loaded = false;

  Future<void> loadFavorites({bool force = false}) async {
    if (_loaded && !force) return;
    _loaded = true;
    state = const AsyncValue.loading();
    try {
      final favorites = await _api.fetchFavorites();
      state = AsyncValue.data(favorites);
      _syncCount(favorites.length);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  bool isFavorite(String storeId) {
    return state.valueOrNull?.any((store) => store.id == storeId) ?? false;
  }

  Future<void> addFavorite({
    required String storeId,
    required String storeName,
  }) async {
    final previous = state.valueOrNull ?? const <FavoriteStoreModel>[];
    if (previous.any((store) => store.id == storeId)) return;

    final optimistic = FavoriteStoreModel.fromJson({
      'storeId': storeId,
      'storeName': storeName,
      'createdAt': DateTime.now().toIso8601String(),
    });
    state = AsyncValue.data([optimistic, ...previous]);
    _syncCount(previous.length + 1);

    try {
      final saved = await _api.addFavorite(
        storeId: storeId,
        storeName: storeName,
      );
      state = AsyncValue.data([
        saved,
        ...previous.where((store) => store.id != storeId),
      ]);
    } catch (error) {
      state = AsyncValue.data(previous);
      _syncCount(previous.length);
      rethrow;
    }
  }

  Future<void> removeFavorite(String storeId) async {
    final previous = state.valueOrNull ?? const <FavoriteStoreModel>[];
    final next = previous.where((store) => store.id != storeId).toList();
    state = AsyncValue.data(next);
    _syncCount(next.length);

    try {
      await _api.removeFavorite(storeId);
    } catch (error) {
      state = AsyncValue.data(previous);
      _syncCount(previous.length);
      rethrow;
    }
  }

  void _syncCount(int count) {
    _profileNotifier.update(
      (profile) => profile.copyWith(favoriteStoreCount: count),
    );
  }
}

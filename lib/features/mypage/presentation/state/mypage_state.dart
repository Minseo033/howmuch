import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  const UserProfile({
    required this.nickname,
    required this.region,
    required this.favoriteCategories,
    required this.savedAmount,
    required this.visitCount,
    required this.reportCount,
  });

  final String nickname;
  final String region;
  final List<String> favoriteCategories;
  final int savedAmount;
  final int visitCount;
  final int reportCount;

  UserProfile copyWith({
    String? nickname,
    String? region,
    List<String>? favoriteCategories,
    int? savedAmount,
    int? visitCount,
    int? reportCount,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      region: region ?? this.region,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      savedAmount: savedAmount ?? this.savedAmount,
      visitCount: visitCount ?? this.visitCount,
      reportCount: reportCount ?? this.reportCount,
    );
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.all,
    required this.review,
    required this.report,
    required this.price,
    required this.service,
  });

  final bool all;
  final bool review;
  final bool report;
  final bool price;
  final bool service;

  NotificationSettings copyWith({
    bool? all,
    bool? review,
    bool? report,
    bool? price,
    bool? service,
  }) {
    return NotificationSettings(
      all: all ?? this.all,
      review: review ?? this.review,
      report: report ?? this.report,
      price: price ?? this.price,
      service: service ?? this.service,
    );
  }
}

class PriceAlertSettings {
  const PriceAlertSettings({
    required this.categories,
    required this.regions,
    required this.onlyFavorites,
    required this.notifyOnDrop,
    required this.notifyOnRise,
  });

  final List<String> categories;
  final List<String> regions;
  final bool onlyFavorites;
  final bool notifyOnDrop;
  final bool notifyOnRise;

  PriceAlertSettings copyWith({
    List<String>? categories,
    List<String>? regions,
    bool? onlyFavorites,
    bool? notifyOnDrop,
    bool? notifyOnRise,
  }) {
    return PriceAlertSettings(
      categories: categories ?? this.categories,
      regions: regions ?? this.regions,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
      notifyOnDrop: notifyOnDrop ?? this.notifyOnDrop,
      notifyOnRise: notifyOnRise ?? this.notifyOnRise,
    );
  }
}

class SocialAccount {
  const SocialAccount({
    required this.name,
    required this.connected,
    required this.description,
  });

  final String name;
  final bool connected;
  final String description;

  SocialAccount copyWith({bool? connected}) {
    return SocialAccount(
      name: name,
      connected: connected ?? this.connected,
      description: description,
    );
  }
}

final userProfileProvider = StateProvider<UserProfile>(
  (ref) => const UserProfile(
    nickname: '민서',
    region: '서울시 마포구',
    favoriteCategories: ['한식', '분식', '카페'],
    savedAmount: 18400,
    visitCount: 12,
    reportCount: 5,
  ),
);

final notificationSettingsProvider = StateProvider<NotificationSettings>(
  (ref) => const NotificationSettings(
    all: true,
    review: true,
    report: true,
    price: true,
    service: false,
  ),
);

final priceAlertSettingsProvider = StateProvider<PriceAlertSettings>(
  (ref) => const PriceAlertSettings(
    categories: ['한식', '분식'],
    regions: ['마포구', '서대문구'],
    onlyFavorites: true,
    notifyOnDrop: true,
    notifyOnRise: false,
  ),
);

final socialAccountsProvider = StateProvider<List<SocialAccount>>(
  (ref) => const [
    SocialAccount(name: '카카오', connected: true, description: '간편 로그인에 사용 중'),
    SocialAccount(name: '네이버', connected: false, description: '지역 리뷰 연동 예정'),
    SocialAccount(name: '구글', connected: false, description: '웹 로그인 보조 계정'),
  ],
);

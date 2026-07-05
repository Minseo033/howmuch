import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/admin/presentation/screens/admin_inquiry_review_screen.dart';
import 'package:howmuch/features/admin/presentation/screens/admin_report_review_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/permission_setup_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/splash_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/account_management_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/connected_social_accounts_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/privacy_policy_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/public_data_source_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/terms_of_service_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/withdrawal_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_savings_report_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_store_report_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';
import 'package:howmuch/features/system/presentation/screens/network_error_screen.dart';
import 'package:howmuch/features/system/presentation/screens/report_delete_confirm_screen.dart';
import 'package:howmuch/features/system/presentation/screens/search_empty_screen.dart';
import 'package:howmuch/features/system/presentation/screens/session_expired_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';

import 'package:howmuch/features/savings/presentation/screens/savings_report_dashboard_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_detail_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/optimal_route_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/system/presentation/screens/notifications_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_goal_setting_screen.dart';

import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_history_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_screen.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_complete_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_reviews_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/visit_history_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart';

import 'package:howmuch/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      if (state.uri.host == 'oauth') {
        return '/oauth_loading';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/oauth_loading',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.reviewList,
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: ReviewListScreen(store: state.extra as Store?),
        ),
      ),
      GoRoute(
        path: AppRoutes.reviewWrite,
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: ReviewWriteScreen(store: state.extra as Store?),
        ),
      ),
      _route(AppRoutes.priceHistory, const PriceHistoryScreen()),
      GoRoute(
        path: AppRoutes.priceChangeReport,
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: PriceChangeReportScreen(
            storeName: state.extra is String ? state.extra as String : '매장 정보 없음',
          ),
        ),
      ),
      _route(AppRoutes.storeInfoReport, const StoreInfoReportScreen()),
      GoRoute(
        path: AppRoutes.visitVerification,
        pageBuilder: (_, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: VisitVerificationScreen(
            storeName: state.extra is String ? state.extra as String : '매장 정보 없음',
          ),
        ),
      ),
      _route(
        AppRoutes.visitVerificationComplete,
        const VisitVerificationCompleteScreen(),
      ),
      _route(
        AppRoutes.directionsExternalApp,
        const DirectionsExternalAppScreen(),
      ),
      _route(AppRoutes.myReviews, const MyReviewsScreen()),
      _route(AppRoutes.visitHistory, const VisitHistoryScreen()),
      _route(
        AppRoutes.favoriteCancelConfirm,
        const FavoriteCancelConfirmScreen(),
      ),
      GoRoute(path: AppRoutes.root, redirect: (_, _) => AppRoutes.splash),
      _route(AppRoutes.splash, const SplashScreen()),
      _route(AppRoutes.onboardingNearby, const OnboardingNearbyScreen()),
      _route(
        AppRoutes.onboardingSavingsReport,
        const OnboardingSavingsReportScreen(),
      ),
      _route(
        AppRoutes.onboardingStoreReport,
        const OnboardingStoreReportScreen(),
      ),
      _route(AppRoutes.login, const LoginScreen()),
      _route(AppRoutes.permissionSetup, const PermissionSetupScreen()),
      _route(AppRoutes.profileSetup, const ProfileSetupScreen()),
      _tabRoute(AppRoutes.home, const HomeMapScreen()),
      _route(AppRoutes.homeAiFab, const HomeMapScreen(showAiSpotlight: true)),
      _route(AppRoutes.homeAi, const HomeMapScreen(showAiSpotlight: true)),
      _route(AppRoutes.aiRecommend, const AiRecommendChatScreen()),
      _tabRoute(AppRoutes.communityFeed, const CommunityFeedScreen()),
      _route(AppRoutes.reportCreate, const ReportCreateScreen()),
      _route(AppRoutes.reportComplete, const ReportCompleteScreen()),
      _route(AppRoutes.myReports, const MyReportsScreen()),
      _route(AppRoutes.reportDetail, const ReportDetailScreen()),
      _route(AppRoutes.myReportsV2, const MyReportsV2Screen()),
      _route(AppRoutes.reportDetailV2, const ReportDetailV2Screen()),
      _route(AppRoutes.communityPostDetail, const CommunityPostDetailScreen()),
      _tabRoute(AppRoutes.mypage, const MypageScreen()),
      _route(
        AppRoutes.notificationSettings,
        const NotificationSettingsScreen(),
      ),
      _route(
        AppRoutes.priceAlertSubscription,
        const PriceAlertSubscriptionScreen(),
      ),
      _route(AppRoutes.accountManagement, const AccountManagementScreen()),
      _route(AppRoutes.publicDataSource, const PublicDataSourceScreen()),
      _route(AppRoutes.inquiry, const InquiryScreen()),
      _route(AppRoutes.profileEdit, const ProfileEditScreen()),
      _route(AppRoutes.withdrawal, const WithdrawalScreen()),
      _route(
        AppRoutes.connectedSocialAccounts,
        const ConnectedSocialAccountsScreen(),
      ),
      _route(AppRoutes.privacyPolicy, const PrivacyPolicyScreen()),
      _route(AppRoutes.termsOfService, const TermsOfServiceScreen()),
      _route(AppRoutes.adminReportReview, const AdminReportReviewScreen()),
      _route(AppRoutes.adminInquiryReview, const AdminInquiryReviewScreen()),
      _route(AppRoutes.networkError, const NetworkErrorScreen()),
      _route(AppRoutes.searchEmpty, const SearchEmptyScreen()),
      _route(AppRoutes.reportDeleteConfirm, const ReportDeleteConfirmScreen()),
      _route(AppRoutes.sessionExpired, const SessionExpiredScreen()),
      _tabRoute(
        AppRoutes.savingsReportDashboard,
        const SavingsReportDashboardScreen(),
      ),
      _route(AppRoutes.savingsDetail, const SavingsDetailScreen()),
      _route(AppRoutes.savingsGoalSetting, const SavingsGoalSettingScreen()),
      _route(AppRoutes.todaysPick, const TodaysPickScreen()),
      _route(AppRoutes.optimalRoute, const OptimalRouteScreen()),
      _route(AppRoutes.favoriteStores, const FavoriteStoresScreen()),
      _route(AppRoutes.notifications, const NotificationsScreen()),
      GoRoute(
        path: AppRoutes.searchResult,
        pageBuilder: (_, state) {
          final extra = state.extra;
          String query = '';
          bool openFilter = false;

          if (extra is String) {
            query = extra;
          } else if (extra is Map<String, dynamic>) {
            query = extra['query'] as String? ?? '';
            openFilter = extra['openFilter'] as bool? ?? false;
          }

          return CupertinoPage<void>(
            key: state.pageKey,
            child: SearchResultScreen(
              initialQuery: query,
              autoOpenFilter: openFilter,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.storeDetail,
        pageBuilder: (_, state) {
          final store = state.extra as Store;
          return CupertinoPage<void>(
            key: state.pageKey,
            child: StoreDetailScreen(store: store),
          );
        },
      ),
    ],
  );
});

GoRoute _route(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (_, state) =>
        CupertinoPage<void>(key: state.pageKey, child: child),
  );
}

GoRoute _tabRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (_, state) =>
        NoTransitionPage(key: state.pageKey, child: child),
  );
}

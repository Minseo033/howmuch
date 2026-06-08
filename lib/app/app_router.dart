import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/admin/presentation/screens/admin_inquiry_review_screen.dart';
import 'package:howmuch/features/admin/presentation/screens/admin_report_review_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/permission_setup_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports_v2_screen.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.onboardingNearby,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (_, _) => AppRoutes.onboardingNearby,
      ),
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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/permission_setup_screen.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/account_management_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/connected_social_accounts_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/public_data_source_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/withdrawal_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_savings_report_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_store_report_screen.dart';

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
    ],
  );
});

GoRoute _route(String path, Widget child) {
  return GoRoute(path: path, builder: (_, _) => child);
}

GoRoute _tabRoute(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (_, state) =>
        NoTransitionPage(key: state.pageKey, child: child),
  );
}

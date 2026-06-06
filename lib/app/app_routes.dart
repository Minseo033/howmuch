class AppRoutes {
  const AppRoutes._();

  static const root = '/';

  static const onboardingNearby = '/onboarding/nearby';
  static const onboardingSavingsReport = '/onboarding/savings-report';
  static const onboardingStoreReport = '/onboarding/store-report';
  static const login = '/login';
  static const permissionSetup = '/permissions';
  static const home = '/home';
  static const homeAiFab = '/home/ai-fab';
  static const homeAi = '/home-ai';
  static const aiRecommend = '/ai-recommend';

  static const communityFeed = '/community';
  static const reportCreate = '/community/report/new';
  static const reportComplete = '/community/report/complete';
  static const myReports = '/community/reports';
  static const reportDetail = '/community/report/detail';
  static const communityPostDetail = '/community/post/detail';

  static const mypage = '/mypage';
  static const notificationSettings = '/mypage/notifications';
  static const priceAlertSubscription = '/mypage/price-alerts';
  static const accountManagement = '/mypage/account';
  static const publicDataSource = '/mypage/public-data';
  static const inquiry = '/mypage/inquiry';
  static const profileEdit = '/mypage/profile-edit';
  static const withdrawal = '/mypage/withdrawal';
  static const connectedSocialAccounts = '/mypage/social-accounts';
  static const privacyPolicy = '/mypage/privacy-policy';
  static const termsOfService = '/mypage/terms';

  static const adminReportReview = '/admin/reports';
  static const adminInquiryReview = '/admin/inquiries';

  static const networkError = '/network-error';
  static const searchEmpty = '/search/empty';
  static const reportDeleteConfirm = '/reports/delete-confirm';
  static const sessionExpired = '/session-expired';
}

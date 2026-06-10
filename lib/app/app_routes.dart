class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const splash = '/splash';

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
  static const myReportsV2 = '/community/reports-v2';
  static const reportDetailV2 = '/community/report-detail-v2';
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
  static const searchResult = '/search/result';
  static const reportDeleteConfirm = '/reports/delete-confirm';
  static const sessionExpired = '/session-expired';
  static const storeDetail = '/store/detail';

  static const savingsReportDashboard = '/savings/dashboard';
  static const savingsDetail = '/savings/detail';
  static const savingsGoalSetting = '/savings/goal-setting';
  static const todaysPick = '/recommendation/todays-pick';
  static const optimalRoute = '/recommendation/optimal-route';

  // Dana's UI Screens
  static const reviewList = '/store/reviews';
  static const reviewWrite = '/store/reviews/write';
  static const priceHistory = '/store/price-history';
  static const priceChangeReport = '/store/price-change';
  static const storeInfoReport = '/store/info-report';
  static const visitVerification = '/store/visit';
  static const visitVerificationComplete = '/store/visit/complete';
  static const directionsExternalApp = '/store/directions';
  static const myReviews = '/mypage/reviews';
  static const visitHistory = '/mypage/visits';
  static const favoriteCancelConfirm = '/store/favorite-cancel';
  static const favoriteStores = '/mypage/favorite-stores';
  static const notifications = '/notifications';
}

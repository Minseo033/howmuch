import 'package:flutter/widgets.dart';
import 'package:howmuch/core/navigation/app_screen.dart';
import 'package:howmuch/features/admin/presentation/screens/admin_inquiry_review_screen.dart';
import 'package:howmuch/features/admin/presentation/screens/admin_report_review_screen.dart';
import 'package:howmuch/features/ai_recommendation/presentation/screens/ai_fab_entry_screen.dart';
import 'package:howmuch/features/ai_recommendation/presentation/screens/chatbot_analysis_screen.dart';
import 'package:howmuch/features/ai_recommendation/presentation/screens/chatbot_intro_screen.dart';
import 'package:howmuch/features/ai_recommendation/presentation/screens/chatbot_route_response_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/permission_setup_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_report_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_report_manage_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports_all_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports_approved_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports_pending_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_status_detail_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/empty_search_result_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/network_error_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/report_delete_confirm_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/session_expired_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/map_search/presentation/screens/filtered_results_screen.dart';
import 'package:howmuch/features/map_search/presentation/screens/search_filter_sheet_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/account_management_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/connected_social_accounts_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_reviews_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/privacy_policy_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/public_data_source_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/terms_of_service_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/visit_history_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/withdrawal_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_savings_report_screen.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_store_report_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/notifications_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/optimal_route_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/saving_goal_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_dashboard_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_detail_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/today_pick_weather_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_history_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_list_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_complete_screen.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_screen.dart';

const appScreens = <AppScreen>[
  AppScreen(
    figmaId: '1-1',
    title: '온보딩 · 주변 착한가격업소',
    owner: '김민서',
    feature: '온보딩',
    builder: _onboardingNearby,
  ),
  AppScreen(
    figmaId: '1-2',
    title: '온보딩 · 절약 리포트',
    owner: '김민서',
    feature: '온보딩',
    builder: _onboardingSavingsReport,
  ),
  AppScreen(
    figmaId: '1-3',
    title: '온보딩 · 매장 제보',
    owner: '김민서',
    feature: '온보딩',
    builder: _onboardingStoreReport,
  ),
  AppScreen(
    figmaId: '1-4',
    title: '로그인',
    owner: '김민서',
    feature: '인증',
    builder: _login,
  ),
  AppScreen(
    figmaId: '1-5',
    title: '권한 설정',
    owner: '김민서',
    feature: '인증',
    builder: _permissionSetup,
  ),
  AppScreen(
    figmaId: '2-1',
    title: '홈 / 메인 지도',
    owner: '김민서',
    feature: '홈',
    builder: _homeMap,
  ),
  AppScreen(
    figmaId: '2-2',
    title: '검색 · 필터 바텀시트',
    owner: '김다나',
    feature: '검색',
    builder: _searchFilterSheet,
  ),
  AppScreen(
    figmaId: '2-3',
    title: '필터 적용 결과',
    owner: '김다나',
    feature: '검색',
    builder: _filteredResults,
  ),
  AppScreen(
    figmaId: '2-4',
    title: '매장 상세',
    owner: '김다나',
    feature: '매장',
    builder: _storeDetail,
  ),
  AppScreen(
    figmaId: '2-5',
    title: '리뷰 · 댓글 전체보기',
    owner: '김다나',
    feature: '매장',
    builder: _reviewList,
  ),
  AppScreen(
    figmaId: '2-6',
    title: '리뷰 작성',
    owner: '김다나',
    feature: '매장',
    builder: _reviewWrite,
  ),
  AppScreen(
    figmaId: '2-7',
    title: '방문 인증',
    owner: '김다나',
    feature: '매장',
    builder: _visitVerification,
  ),
  AppScreen(
    figmaId: '2-8',
    title: '방문 인증 완료',
    owner: '김다나',
    feature: '매장',
    builder: _visitVerificationComplete,
  ),
  AppScreen(
    figmaId: '2-9',
    title: '길찾기 · 외부 앱 연결',
    owner: '김다나',
    feature: '매장',
    builder: _directionsExternalApp,
  ),
  AppScreen(
    figmaId: '2-10',
    title: '가격 변동 제보',
    owner: '김다나',
    feature: '매장',
    builder: _priceChangeReport,
  ),
  AppScreen(
    figmaId: '2-11',
    title: '가격 이력',
    owner: '김다나',
    feature: '매장',
    builder: _priceHistory,
  ),
  AppScreen(
    figmaId: '3-1',
    title: '동네 제보 커뮤니티 피드',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _communityFeed,
  ),
  AppScreen(
    figmaId: '3-2',
    title: '제보 등록',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _reportCreate,
  ),
  AppScreen(
    figmaId: '3-3',
    title: '제보 완료',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _reportComplete,
  ),
  AppScreen(
    figmaId: '3-4',
    title: '내 제보 관리',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _myReportManage,
  ),
  AppScreen(
    figmaId: '3-5',
    title: '제보 상세 / 검토 상태',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _reportStatusDetail,
  ),
  AppScreen(
    figmaId: '3-6',
    title: '커뮤니티 게시글 상세',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _communityPostDetail,
  ),
  AppScreen(
    figmaId: '3-A',
    title: '내 제보 · 전체',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _myReportsAll,
  ),
  AppScreen(
    figmaId: '3-B',
    title: '내 제보 · 검토 중',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _myReportsPending,
  ),
  AppScreen(
    figmaId: '3-C',
    title: '내 제보 · 승인 완료',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _myReportsApproved,
  ),
  AppScreen(
    figmaId: '3-D',
    title: '내 제보 상세',
    owner: '오태관',
    feature: '커뮤니티',
    builder: _myReportDetail,
  ),
  AppScreen(
    figmaId: '4-1',
    title: '절약 리포트 대시보드',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _savingsDashboard,
  ),
  AppScreen(
    figmaId: '4-2',
    title: '절약 상세 내역',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _savingsDetail,
  ),
  AppScreen(
    figmaId: '4-3',
    title: '오늘의 픽 · 날씨 추천',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _todayPickWeather,
  ),
  AppScreen(
    figmaId: '4-4',
    title: '최적 루트 추천',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _optimalRoute,
  ),
  AppScreen(
    figmaId: '4-5',
    title: '찜한 매장',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _favoriteStores,
  ),
  AppScreen(
    figmaId: '4-6',
    title: '알림',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _notifications,
  ),
  AppScreen(
    figmaId: '4-7',
    title: '절약 목표 설정',
    owner: '오태관',
    feature: '절약 리포트',
    builder: _savingGoal,
  ),
  AppScreen(
    figmaId: '5-1',
    title: '마이페이지',
    owner: '김민서',
    feature: '마이페이지',
    builder: _mypage,
  ),
  AppScreen(
    figmaId: '5-A',
    title: '알림 설정',
    owner: '김민서',
    feature: '마이페이지',
    builder: _notificationSettings,
  ),
  AppScreen(
    figmaId: '5-B',
    title: '가격 알림 구독',
    owner: '김민서',
    feature: '마이페이지',
    builder: _priceAlertSubscription,
  ),
  AppScreen(
    figmaId: '5-C',
    title: '계정 관리',
    owner: '김민서',
    feature: '마이페이지',
    builder: _accountManagement,
  ),
  AppScreen(
    figmaId: '5-D',
    title: '공공데이터 출처',
    owner: '김민서',
    feature: '마이페이지',
    builder: _publicDataSource,
  ),
  AppScreen(
    figmaId: '5-E',
    title: '문의하기',
    owner: '김민서',
    feature: '마이페이지',
    builder: _inquiry,
  ),
  AppScreen(
    figmaId: '5-F',
    title: '프로필 수정',
    owner: '김민서',
    feature: '마이페이지',
    builder: _profileEdit,
  ),
  AppScreen(
    figmaId: '5-G',
    title: '내 리뷰 내역',
    owner: '김다나',
    feature: '마이페이지',
    builder: _myReviews,
  ),
  AppScreen(
    figmaId: '5-H',
    title: '방문 기록',
    owner: '김다나',
    feature: '마이페이지',
    builder: _visitHistory,
  ),
  AppScreen(
    figmaId: '5-I',
    title: '회원 탈퇴',
    owner: '김민서',
    feature: '마이페이지',
    builder: _withdrawal,
  ),
  AppScreen(
    figmaId: '5-J',
    title: '개인정보 처리방침',
    owner: '김민서',
    feature: '마이페이지',
    builder: _privacyPolicy,
  ),
  AppScreen(
    figmaId: '5-K',
    title: '서비스 이용약관',
    owner: '김민서',
    feature: '마이페이지',
    builder: _termsOfService,
  ),
  AppScreen(
    figmaId: '5-L',
    title: '연결된 소셜 계정',
    owner: '김민서',
    feature: '마이페이지',
    builder: _connectedSocialAccounts,
  ),
  AppScreen(
    figmaId: '6-1',
    title: '관리자 제보 검토',
    owner: '김민서',
    feature: '관리자',
    builder: _adminReportReview,
  ),
  AppScreen(
    figmaId: '6-2',
    title: '관리자 문의 검토',
    owner: '김민서',
    feature: '관리자',
    builder: _adminInquiryReview,
  ),
  AppScreen(
    figmaId: '7-1',
    title: '네트워크 오류',
    owner: '김민서',
    feature: '공통 상태',
    builder: _networkError,
  ),
  AppScreen(
    figmaId: '7-2',
    title: '검색 결과 0건',
    owner: '김민서',
    feature: '공통 상태',
    builder: _emptySearchResult,
  ),
  AppScreen(
    figmaId: '7-3',
    title: '매장 정보 신고',
    owner: '김다나',
    feature: '공통 상태',
    builder: _storeInfoReport,
  ),
  AppScreen(
    figmaId: '7-4',
    title: '찜 취소 확인',
    owner: '김다나',
    feature: '공통 상태',
    builder: _favoriteCancelConfirm,
  ),
  AppScreen(
    figmaId: '7-5',
    title: '제보 삭제 확인',
    owner: '김민서',
    feature: '공통 상태',
    builder: _reportDeleteConfirm,
  ),
  AppScreen(
    figmaId: '7-6',
    title: '세션 만료 · 재로그인',
    owner: '김민서',
    feature: '공통 상태',
    builder: _sessionExpired,
  ),
  AppScreen(
    figmaId: '8-1',
    title: '홈 · AI 추천 FAB 진입',
    owner: '오태관',
    feature: 'AI 추천',
    builder: _aiFabEntry,
  ),
  AppScreen(
    figmaId: '8-2',
    title: '챗봇 첫 화면 · 추천 질문',
    owner: '오태관',
    feature: 'AI 추천',
    builder: _chatbotIntro,
  ),
  AppScreen(
    figmaId: '8-3',
    title: '대화 · 조건 분석',
    owner: '오태관',
    feature: 'AI 추천',
    builder: _chatbotAnalysis,
  ),
  AppScreen(
    figmaId: '8-4',
    title: '루트 추천 응답',
    owner: '오태관',
    feature: 'AI 추천',
    builder: _chatbotRouteResponse,
  ),
];

Widget _onboardingNearby(BuildContext context) =>
    const OnboardingNearbyScreen();
Widget _onboardingSavingsReport(BuildContext context) =>
    const OnboardingSavingsReportScreen();
Widget _onboardingStoreReport(BuildContext context) =>
    const OnboardingStoreReportScreen();
Widget _login(BuildContext context) => const LoginScreen();
Widget _permissionSetup(BuildContext context) => const PermissionSetupScreen();
Widget _homeMap(BuildContext context) => const HomeMapScreen();
Widget _searchFilterSheet(BuildContext context) =>
    const SearchFilterSheetScreen();
Widget _filteredResults(BuildContext context) => const FilteredResultsScreen();
Widget _storeDetail(BuildContext context) => const StoreDetailScreen();
Widget _reviewList(BuildContext context) => const ReviewListScreen();
Widget _reviewWrite(BuildContext context) => const ReviewWriteScreen();
Widget _visitVerification(BuildContext context) =>
    const VisitVerificationScreen();
Widget _visitVerificationComplete(BuildContext context) =>
    const VisitVerificationCompleteScreen();
Widget _directionsExternalApp(BuildContext context) =>
    const DirectionsExternalAppScreen();
Widget _priceChangeReport(BuildContext context) =>
    const PriceChangeReportScreen();
Widget _priceHistory(BuildContext context) => const PriceHistoryScreen();
Widget _communityFeed(BuildContext context) => const CommunityFeedScreen();
Widget _reportCreate(BuildContext context) => const ReportCreateScreen();
Widget _reportComplete(BuildContext context) => const ReportCompleteScreen();
Widget _myReportManage(BuildContext context) => const MyReportManageScreen();
Widget _reportStatusDetail(BuildContext context) =>
    const ReportStatusDetailScreen();
Widget _communityPostDetail(BuildContext context) =>
    const CommunityPostDetailScreen();
Widget _myReportsAll(BuildContext context) => const MyReportsAllScreen();
Widget _myReportsPending(BuildContext context) =>
    const MyReportsPendingScreen();
Widget _myReportsApproved(BuildContext context) =>
    const MyReportsApprovedScreen();
Widget _myReportDetail(BuildContext context) => const MyReportDetailScreen();
Widget _savingsDashboard(BuildContext context) =>
    const SavingsDashboardScreen();
Widget _savingsDetail(BuildContext context) => const SavingsDetailScreen();
Widget _todayPickWeather(BuildContext context) =>
    const TodayPickWeatherScreen();
Widget _optimalRoute(BuildContext context) => const OptimalRouteScreen();
Widget _favoriteStores(BuildContext context) => const FavoriteStoresScreen();
Widget _notifications(BuildContext context) => const NotificationsScreen();
Widget _savingGoal(BuildContext context) => const SavingGoalScreen();
Widget _mypage(BuildContext context) => const MypageScreen();
Widget _notificationSettings(BuildContext context) =>
    const NotificationSettingsScreen();
Widget _priceAlertSubscription(BuildContext context) =>
    const PriceAlertSubscriptionScreen();
Widget _accountManagement(BuildContext context) =>
    const AccountManagementScreen();
Widget _publicDataSource(BuildContext context) =>
    const PublicDataSourceScreen();
Widget _inquiry(BuildContext context) => const InquiryScreen();
Widget _profileEdit(BuildContext context) => const ProfileEditScreen();
Widget _myReviews(BuildContext context) => const MyReviewsScreen();
Widget _visitHistory(BuildContext context) => const VisitHistoryScreen();
Widget _withdrawal(BuildContext context) => const WithdrawalScreen();
Widget _privacyPolicy(BuildContext context) => const PrivacyPolicyScreen();
Widget _termsOfService(BuildContext context) => const TermsOfServiceScreen();
Widget _connectedSocialAccounts(BuildContext context) =>
    const ConnectedSocialAccountsScreen();
Widget _adminReportReview(BuildContext context) =>
    const AdminReportReviewScreen();
Widget _adminInquiryReview(BuildContext context) =>
    const AdminInquiryReviewScreen();
Widget _networkError(BuildContext context) => const NetworkErrorScreen();
Widget _emptySearchResult(BuildContext context) =>
    const EmptySearchResultScreen();
Widget _storeInfoReport(BuildContext context) => const StoreInfoReportScreen();
Widget _favoriteCancelConfirm(BuildContext context) =>
    const FavoriteCancelConfirmScreen();
Widget _reportDeleteConfirm(BuildContext context) =>
    const ReportDeleteConfirmScreen();
Widget _sessionExpired(BuildContext context) => const SessionExpiredScreen();
Widget _aiFabEntry(BuildContext context) => const AiFabEntryScreen();
Widget _chatbotIntro(BuildContext context) => const ChatbotIntroScreen();
Widget _chatbotAnalysis(BuildContext context) => const ChatbotAnalysisScreen();
Widget _chatbotRouteResponse(BuildContext context) =>
    const ChatbotRouteResponseScreen();

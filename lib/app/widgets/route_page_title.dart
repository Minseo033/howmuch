import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/store/store_model.dart';

const _appName = '얼마고?';

/// Browser tab names, matching each screen's heading.
const Map<String, String> _screenTitles = {
  AppRoutes.onboardingNearby: '시작하기',
  AppRoutes.onboardingSavingsReport: '시작하기',
  AppRoutes.onboardingStoreReport: '시작하기',
  AppRoutes.authTerms: '약관 동의',
  AppRoutes.login: '로그인',
  AppRoutes.loginFlow: '로그인',
  '/oauth_loading': '로그인',
  AppRoutes.permissionSetup: '권한 설정',
  AppRoutes.profileSetup: '프로필 설정',
  AppRoutes.home: '홈',
  AppRoutes.homeAiFab: '홈',
  AppRoutes.aiRecommend: 'AI 추천',
  AppRoutes.communityFeed: '동네 제보',
  AppRoutes.reportCreate: '가성비 매장 제보',
  AppRoutes.reportComplete: '제보 완료',
  AppRoutes.myReportsV2: '내 제보 내역',
  AppRoutes.reportDetailV2: '제보 상세',
  AppRoutes.communityPostDetail: '게시글 상세',
  AppRoutes.mypage: '마이',
  AppRoutes.notificationSettings: '알림 설정',
  AppRoutes.priceAlertSubscription: '가격 알림 구독',
  AppRoutes.accountManagement: '계정 관리',
  AppRoutes.publicDataSource: '공공데이터 출처',
  AppRoutes.inquiry: '문의하기',
  AppRoutes.inquiryHistory: '내 문의 내역',
  AppRoutes.profileEdit: '프로필 수정',
  AppRoutes.withdrawal: '회원 탈퇴',
  AppRoutes.connectedSocialAccounts: '로그인 계정',
  AppRoutes.privacyPolicy: '개인정보 처리방침',
  AppRoutes.termsOfService: '서비스 이용약관',
  AppRoutes.networkError: '연결 오류',
  AppRoutes.searchResult: '검색',
  AppRoutes.reportDeleteConfirm: '제보 삭제',
  AppRoutes.sessionExpired: '로그인 만료',
  AppRoutes.storeDetail: '매장 상세',
  AppRoutes.savingsReportDashboard: '절약 리포트',
  AppRoutes.savingsDetail: '절약 상세 내역',
  AppRoutes.savingsGoalSetting: '절약 목표',
  AppRoutes.todaysPick: '오늘의 픽',
  AppRoutes.optimalRoute: '추천 루트',
  AppRoutes.reviewList: '매장 리뷰',
  AppRoutes.reviewWrite: '리뷰 작성',
  AppRoutes.priceHistory: '가격 이력',
  AppRoutes.priceChangeReport: '가격 변동 제보',
  AppRoutes.storeInfoReport: '정보 신고',
  AppRoutes.visitVerification: '방문 인증',
  AppRoutes.visitVerificationComplete: '방문 인증 완료',
  AppRoutes.directionsExternalApp: '길찾기',
  AppRoutes.myReviews: '내 리뷰',
  AppRoutes.visitHistory: '방문 기록',
  AppRoutes.favoriteCancelConfirm: '찜 해제',
  AppRoutes.favoriteStores: '찜한 매장',
  AppRoutes.notifications: '알림',
};

/// The browser tab title for the screen on top, such as "알림 · 얼마고?".
///
/// Screens opened with push keep the tab's address, so the top route is
/// read from the route stack rather than the address.
String routePageTitle(RouteMatchList configuration) {
  if (configuration.matches.isEmpty) return _appName;
  final last = configuration.last;
  final visible = last is ImperativeRouteMatch ? last.matches : configuration;
  final path = visible.uri.path;
  if (path == AppRoutes.storeDetail) {
    final extra = visible.extra;
    final storeName = extra is Store ? extra.storeName.trim() : '';
    if (storeName.isNotEmpty) return '$storeName · $_appName';
  }
  final title = _screenTitles[path];
  return title == null ? _appName : '$title · $_appName';
}

/// Names the browser tab after the visible screen and renames it on every
/// push, pop and tab change (QA 10/7 #43).
class RoutePageTitle extends StatefulWidget {
  const RoutePageTitle({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<RoutePageTitle> createState() => _RoutePageTitleState();
}

class _RoutePageTitleState extends State<RoutePageTitle> {
  late String _title = _routeTitle();
  bool _refreshScheduled = false;

  String _routeTitle() =>
      routePageTitle(widget.router.routerDelegate.currentConfiguration);

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didUpdateWidget(RoutePageTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
    widget.router.routerDelegate.addListener(_onRouteChanged);
    _title = _routeTitle();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  // The router can report a route while the screens below are building (the
  // first route does). This ancestor then rebuilds after that frame.
  void _onRouteChanged() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _refresh();
      return;
    }
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    scheduler.addPostFrameCallback((_) {
      _refreshScheduled = false;
      _refresh();
    });
  }

  void _refresh() {
    if (!mounted) return;
    final title = _routeTitle();
    if (title != _title) setState(() => _title = title);
  }

  @override
  Widget build(BuildContext context) {
    return Title(
      title: _title,
      // The color MaterialApp reports, so the page theme-color is unchanged.
      color: Theme.of(context).primaryColor,
      child: widget.child,
    );
  }
}

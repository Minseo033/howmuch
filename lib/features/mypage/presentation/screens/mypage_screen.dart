import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class MypageScreen extends ConsumerWidget {
  const MypageScreen({super.key});

  static const blue = AppColors.primary;
  static const orange = AppColors.warning;
  static const green = AppColors.success;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const hint = AppColors.textLight;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final auth = ref.watch(authStateProvider);
    final reports = ref.watch(userReportsProvider);
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final bottomNavHeight = HowmuchBottomNav.heightFor(bottomOffset);
    final settingsCardHeight = (auth.isAdmin ? 448.0 : 358.0) + 89.0;
    final scrollContentHeight =
        659.98583984375 + topOffset + settingsCardHeight + bottomNavHeight + 20;

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(
                width: double.infinity,
                height: scrollContentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 50.96590805053711 + topOffset,
                      child: _Header(topOffset: topOffset),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 66.96044921875 + topOffset,
                      height: 163.23863220214844,
                      child: _ProfileCard(
                        profile: profile,
                        onEdit: () => context.go(AppRoutes.profileEdit),
                      ),
                    ),
                    // QuickMenu row 1
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 246.193359375 + topOffset,
                      height: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuickMenu(
                                label: '내 제보',
                                icon: Icons.description_outlined,
                                color: orange,
                                onTap: () =>
                                    context.push(AppRoutes.myReportsV2),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _QuickMenu(
                                label: '찜한 매장',
                                icon: Icons.favorite_border_rounded,
                                color: orange,
                                onTap: () =>
                                    context.push(AppRoutes.favoriteStores),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _QuickMenu(
                                label: '내 리뷰',
                                icon: Icons.rate_review_outlined,
                                color: blue,
                                onTap: () => context.push(AppRoutes.myReviews),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // QuickMenu row 2
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 348.47998046875 + topOffset,
                      height: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuickMenu(
                                label: '방문 기록',
                                icon: Icons.location_on_outlined,
                                color: green,
                                onTap: () =>
                                    context.push(AppRoutes.visitHistory),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _QuickMenu(
                                label: '절약 리포트',
                                icon: Icons.bar_chart_rounded,
                                color: green,
                                onTap: () => context.go(
                                  AppRoutes.savingsReportDashboard,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _QuickMenu(
                                label: '알림 설정',
                                icon: Icons.notifications_none_rounded,
                                color: blue,
                                onTap: () =>
                                    context.go(AppRoutes.notificationSettings),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 458.76416015625 + topOffset,
                      height: 189.23294067382812,
                      child: _ReportStatusCard(
                        reports: reports,
                        onViewAll: () => context.push(AppRoutes.myReportsV2),
                        onReportTap: (report) => context.push(
                          '${AppRoutes.reportDetailV2}?id=${report.id}',
                          extra: report,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 659.98583984375 + topOffset,
                      height: settingsCardHeight,
                      child: _SettingsCard(
                        onNotificationTap: () =>
                            context.go(AppRoutes.notificationSettings),
                        onAccountTap: () =>
                            context.go(AppRoutes.accountManagement),
                        onPublicDataTap: () =>
                            context.go(AppRoutes.publicDataSource),
                        onInquiryTap: () => context.go(AppRoutes.inquiry),
                        isAdmin: auth.isAdmin,
                        onAdminModeToggle: () {
                          final next = !auth.isAdmin;
                          // TODO(박지환 BE): 관리자 권한 API가 붙으면 이 개발용 토글은 제거하고 서버 권한값만 사용하세요.
                          ref.read(authStateProvider.notifier).state = auth
                              .copyWith(isAdmin: next);
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  next
                                      ? '개발용 관리자 모드를 켰어요.'
                                      : '개발용 관리자 모드를 껐어요.',
                                ),
                              ),
                            );
                        },
                        onAdminReportTap: () =>
                            context.push(AppRoutes.adminReportReview),
                        onAdminInquiryTap: () =>
                            context.push(AppRoutes.adminInquiryReview),
                        onNetworkErrorTap: () =>
                            context.push(AppRoutes.networkError),
                        onSessionExpiredTap: () =>
                            context.push(AppRoutes.sessionExpired),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomNavHeight,
            child: HowmuchBottomNav(
              safeBottom: bottomOffset,
              activeTab: HowmuchBottomTab.mypage,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.topOffset});

  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.white),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 11.98876953125 + topOffset,
            child: const Text(
              '마이',
              style: TextStyle(
                color: MypageScreen.black,
                fontFamily: MypageScreen.fontFamily,
                fontFamilyFallback: MypageScreen.fontFallback,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
          Positioned(
            right: 48.991455078125,
            top: 16.4775390625 + topOffset,
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.notifications),
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: MypageScreen.ink,
                size: 18,
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 16.4775390625 + topOffset,
            child: const Icon(
              Icons.settings_outlined,
              color: MypageScreen.ink,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MypageScreen.blue, AppColors.primary],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 215.45452880859375,
              top: -20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 130, height: 130),
              ),
            ),
            Positioned(
              left: 20,
              top: 26.619140625,
              width: 55.99431610107422,
              height: 55.99431610107422,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '👑',
                    style: TextStyle(fontSize: 24, height: 1.5),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 87.98294067382812,
              top: 25.2841796875,
              width: 68.0539779663086,
              height: 18.977272033691406,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    profile.level,
                    style: _white10.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 87.98294067382812,
              top: 47.25830078125,
              child: Text(
                profile.nickname,
                style: _white17.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Positioned(
              left: 87.98294067382812,
              top: 72.75537109375,
              child: Text(
                profile.email,
                style: _white11.copyWith(
                  color: AppColors.white.withValues(alpha: .85),
                ),
              ),
            ),
            Positioned(
              left: 220.5965576171875,
              top: 40.38330078125,
              width: 94.85794830322266,
              height: 28.480112075805664,
              child: Material(
                color: AppColors.white.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onEdit,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('프로필 수정', style: _profileEditText),
                      SizedBox(width: 5.5),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.white,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 105.2412109375,
              width: 93.15340423583984,
              child: _ProfileMetric(
                value: '${profile.savedAmountText}원',
                label: '이번 달 절약',
              ),
            ),
            Positioned(
              left: 121.15057373046875,
              top: 105.2412109375,
              width: 93.15340423583984,
              child: _ProfileMetric(
                value: '${profile.reportCount}곳',
                label: '제보 매장',
                bordered: true,
              ),
            ),
            Positioned(
              left: 222.3011474609375,
              top: 105.2412109375,
              width: 93.15340423583984,
              child: _ProfileMetric(
                value: '${profile.favoriteStoreCount}곳',
                label: '찜한 매장',
                bordered: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.value,
    required this.label,
    this.bordered = false,
  });

  final String value;
  final String label;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 37.99715805053711,
      decoration: BoxDecoration(
        border: bordered
            ? Border(
                left: BorderSide(
                  color: AppColors.white.withValues(alpha: .2),
                  width: .909,
                ),
              )
            : null,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: _white14Bold,
              ),
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: _white10.copyWith(
                  color: AppColors.white.withValues(alpha: .85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 94.2897720336914,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MypageScreen.border, width: .909),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 37.99715805053711,
                  height: 37.99715805053711,
                  child: Icon(icon, color: color, size: 18),
                ),
              ),
              const SizedBox(height: 5.994),
              Text(label, style: _quickMenuText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportStatusCard extends StatelessWidget {
  const _ReportStatusCard({
    required this.reports,
    required this.onViewAll,
    required this.onReportTap,
  });

  final List<UserReportStatus> reports;
  final VoidCallback onViewAll;
  final Function(UserReportStatus) onReportTap;

  @override
  Widget build(BuildContext context) {
    final visibleReports = reports.take(2).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16.903411865234375,
        16.9033203125,
        16.903411865234375,
        .909,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MypageScreen.border, width: .909),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 19.488636016845703,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('내 제보 상태', style: _sectionTitleText),
                GestureDetector(
                  onTap: onViewAll,
                  behavior: HitTestBehavior.opaque,
                  child: const Text('전체보기', style: _linkText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11.989),
          if (visibleReports.isEmpty)
            const _EmptyReportItem()
          else
            for (var index = 0; index < visibleReports.length; index++) ...[
              _ReportItem(
                report: visibleReports[index],
                onTap: () => onReportTap(visibleReports[index]),
              ),
              if (index != visibleReports.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ReportItem extends StatelessWidget {
  const _ReportItem({required this.report, required this.onTap});

  final UserReportStatus report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MypageScreen.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 301.647705078125,
          height: 56.974430084228516,
          child: Stack(
            children: [
              Positioned(
                left: 11.9886474609375,
                top: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.store, style: _reportStoreText),
                    const SizedBox(height: .994),
                    Text(report.menu, style: _muted11),
                  ],
                ),
              ),
              Positioned(
                right: 11.9886474609375,
                top: 17.98291015625,
                child: Container(
                  height: 20.99431800842285,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.99151611328125,
                  ),
                  decoration: BoxDecoration(
                    color: Color(report.statusBg),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(report.statusColor),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 5, height: 5),
                      ),
                      const SizedBox(width: 3.991),
                      Text(
                        report.status,
                        style: TextStyle(
                          color: Color(report.textColor),
                          fontFamily: MypageScreen.fontFamily,
                          fontFamilyFallback: MypageScreen.fontFallback,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReportItem extends StatelessWidget {
  const _EmptyReportItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 301.647705078125,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MypageScreen.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text('진행 중인 제보가 없어요', style: _muted11),
    );
  }
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({
    required this.onNotificationTap,
    required this.onAccountTap,
    required this.onPublicDataTap,
    required this.onInquiryTap,
    required this.isAdmin,
    required this.onAdminModeToggle,
    required this.onAdminReportTap,
    required this.onAdminInquiryTap,
    required this.onNetworkErrorTap,
    required this.onSessionExpiredTap,
  });

  final VoidCallback onNotificationTap;
  final VoidCallback onAccountTap;
  final VoidCallback onPublicDataTap;
  final VoidCallback onInquiryTap;
  final bool isAdmin;
  final VoidCallback onAdminModeToggle;
  final VoidCallback onAdminReportTap;
  final VoidCallback onAdminInquiryTap;
  final VoidCallback onNetworkErrorTap;
  final VoidCallback onSessionExpiredTap;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  bool _pushEnabled = false;
  bool _marketingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('push_notifications') ?? false;
      _marketingEnabled = prefs.getBool('marketing_consent') ?? false;
    });
  }

  Future<void> _togglePush(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', value);
    setState(() {
      _pushEnabled = value;
    });
  }

  Future<void> _toggleMarketing(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('marketing_consent', value);
    setState(() {
      _marketingEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MypageScreen.border, width: .909),
      ),
      child: Column(
        children: [
          const _PermissionRow(),
          _DividerLine(),

          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            title: '푸시 알림',
            value: _pushEnabled,
            onToggle: () => _togglePush(!_pushEnabled),
          ),
          _DividerLine(),
          _ToggleRow(
            icon: Icons.campaign_outlined,
            title: '마케팅 정보 수신 동의',
            value: _marketingEnabled,
            onToggle: () => _toggleMarketing(!_marketingEnabled),
          ),
          _DividerLine(),

          _SettingRow(
            icon: Icons.notifications_none_rounded,
            title: '알림 설정',
            onTap: widget.onNotificationTap,
          ),
          _DividerLine(),
          _SettingRow(
            icon: Icons.manage_accounts_outlined,
            title: '계정 관리',
            onTap: widget.onAccountTap,
          ),
          _DividerLine(),
          _SettingRow(
            icon: Icons.dataset_outlined,
            title: '공공데이터 출처 안내',
            onTap: widget.onPublicDataTap,
          ),
          _DividerLine(),
          _SettingRow(
            icon: Icons.support_agent_outlined,
            title: '문의하기',
            onTap: widget.onInquiryTap,
          ),
          _DividerLine(),
          _AdminModeRow(value: widget.isAdmin, onTap: widget.onAdminModeToggle),
          if (widget.isAdmin) ...[
            _DividerLine(),
            _SettingRow(
              icon: Icons.admin_panel_settings_outlined,
              title: '관리자 제보 검토',
              onTap: widget.onAdminReportTap,
            ),
            _DividerLine(),
            _SettingRow(
              icon: Icons.mark_chat_read_outlined,
              title: '관리자 문의 검토',
              onTap: widget.onAdminInquiryTap,
            ),
          ],
          _DividerLine(),
          _SettingRow(
            icon: Icons.wifi_off_rounded,
            title: '네트워크 오류 화면',
            onTap: widget.onNetworkErrorTap,
          ),
          _DividerLine(),
          _SettingRow(
            icon: Icons.lock_outline_rounded,
            title: '세션 만료 · 재로그인',
            onTap: widget.onSessionExpiredTap,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onToggle,
  });

  final IconData icon;
  final String title;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: SizedBox(
          height: 43.46590805053711,
          child: Row(
            children: [
              const SizedBox(width: 15.994),
              Icon(icon, color: MypageScreen.muted, size: 17),
              const SizedBox(width: 11.989),
              Text(title, style: _settingText),
              const Spacer(),
              _AdminModeSwitch(value: value),
              const SizedBox(width: 16.903),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminModeRow extends StatelessWidget {
  const _AdminModeRow({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 43.46590805053711,
          child: Row(
            children: [
              const SizedBox(width: 15.994),
              const Icon(
                Icons.science_outlined,
                color: MypageScreen.muted,
                size: 17,
              ),
              const SizedBox(width: 11.989),
              const Text('개발용 관리자 모드', style: _settingText),
              const SizedBox(width: 6),
              Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: const Text('QA', style: _qaBadgeText),
              ),
              const Spacer(),
              _AdminModeSwitch(value: value),
              const SizedBox(width: 16.903),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminModeSwitch extends StatelessWidget {
  const _AdminModeSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 40,
      height: 23.99147605895996,
      decoration: BoxDecoration(
        color: value ? MypageScreen.blue : AppColors.disabled,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            left: value ? 17.9970703125 : 1.9886474609375,
            top: 1.98876953125,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.375,
      child: Row(
        children: const [
          SizedBox(width: 15.994),
          Icon(Icons.location_on_outlined, color: MypageScreen.muted, size: 17),
          SizedBox(width: 11.989),
          Text('위치 권한 설정', style: _settingText),
          Spacer(),
          Text('허용', style: _allowedText),
          SizedBox(width: 4.991),
          Icon(
            Icons.chevron_right_rounded,
            color: MypageScreen.muted,
            size: 15,
          ),
          SizedBox(width: 16.903),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 43.46590805053711,
          child: Row(
            children: [
              const SizedBox(width: 15.994),
              Icon(icon, color: MypageScreen.muted, size: 17),
              const SizedBox(width: 11.989),
              Text(title, style: _settingText),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: MypageScreen.muted,
                size: 15,
              ),
              const SizedBox(width: 16.903),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 301.647705078125,
      height: .9943181276321411,
      child: ColoredBox(color: MypageScreen.border),
    );
  }
}

const _white10 = TextStyle(
  color: AppColors.white,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _white11 = TextStyle(
  color: AppColors.white,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _white14Bold = TextStyle(
  color: AppColors.white,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _white17 = TextStyle(
  color: AppColors.white,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _profileEditText = TextStyle(
  color: AppColors.white,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _quickMenuText = TextStyle(
  color: MypageScreen.ink,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _sectionTitleText = TextStyle(
  color: MypageScreen.black,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _linkText = TextStyle(
  color: MypageScreen.blue,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _reportStoreText = TextStyle(
  color: MypageScreen.black,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _muted11 = TextStyle(
  color: MypageScreen.muted,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _settingText = TextStyle(
  color: MypageScreen.ink,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _qaBadgeText = TextStyle(
  color: MypageScreen.blue,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 9,
  fontWeight: FontWeight.w800,
  height: 1.2,
);

const _allowedText = TextStyle(
  color: MypageScreen.green,
  fontFamily: MypageScreen.fontFamily,
  fontFamilyFallback: MypageScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

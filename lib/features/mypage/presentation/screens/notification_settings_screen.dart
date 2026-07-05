import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const blue = AppColors.primary;
  static const orange = AppColors.warning;
  static const green = AppColors.success;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const disabled = AppColors.disabled;
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
    final settings = ref.watch(notificationSettingsProvider);
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final saveFooterHeight = _StickySaveButton.heightFor(bottomOffset);
    final scrollContentHeight =
        705.7955322265625 + topOffset + saveFooterHeight + 20;

    void update(NotificationSettings value) {
      ref.read(notificationSettingsProvider.notifier).state = value;
    }

    void updateTypes({
      bool? price,
      bool? report,
      bool? todayPick,
      bool? review,
    }) {
      final next = settings.copyWith(
        price: price,
        report: report,
        todayPick: todayPick,
        review: review,
      );

      update(
        next.copyWith(
          all: next.price && next.report && next.todayPick && next.review,
        ),
      );
    }

    void goBack() {
      context.go(AppRoutes.mypage);
    }

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
                      left: 20,
                      right: 20,
                      top: 64.8720703125 + topOffset,
                      height: 73.29544830322266,
                      child: _AllNotificationCard(
                        value: settings.all,
                        onTap: () {
                          final next = !settings.all;
                          update(
                            settings.copyWith(
                              all: next,
                              price: next,
                              report: next,
                              todayPick: next,
                              review: next,
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 23.991485595703125,
                      top: 154.16162109375 + topOffset,
                      child: const _SectionLabel('알림 유형'),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 178.650390625 + topOffset,
                      height: 272.64202880859375,
                      child: _NotificationTypeCard(
                        settings: settings,
                        onPriceTap: () => updateTypes(price: !settings.price),
                        onReportTap: () =>
                            updateTypes(report: !settings.report),
                        onTodayPickTap: () =>
                            updateTypes(todayPick: !settings.todayPick),
                        onReviewTap: () =>
                            updateTypes(review: !settings.review),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 463.28125 + topOffset,
                      height: 67.76988220214844,
                      child: _PriceAlertEntryCard(
                        onTap: () =>
                            context.go(AppRoutes.priceAlertSubscription),
                      ),
                    ),
                    Positioned(
                      left: 23.991485595703125,
                      top: 547.04541015625 + topOffset,
                      child: const _SectionLabel('방해 금지 시간'),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 571.5341796875 + topOffset,
                      height: 134.2613525390625,
                      child: _QuietHoursCard(
                        settings: settings,
                        onToggle: () => update(
                          settings.copyWith(quietHours: !settings.quietHours),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Header(topOffset: topOffset, title: '알림 설정', onBack: goBack),
          Positioned(
            left: 0,
            bottom: 0,
            right: 0,
            height: saveFooterHeight,
            child: _StickySaveButton(
              safeBottom: bottomOffset,
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                // TODO(박지환 BE): 알림 설정 저장 API가 붙으면 현재 provider 상태를 서버에 저장하세요.
                messenger.clearSnackBars();
                context.go(AppRoutes.mypage);
                messenger.showSnackBar(
                  const SnackBar(content: Text('알림 설정을 저장했어요.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.topOffset,
    required this.title,
    required this.onBack,
  });

  final double topOffset;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(
              color: NotificationSettingsScreen.border,
              width: .909,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 72,
              height: 48.877838134765625,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: NotificationSettingsScreen.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 11.98876953125 + topOffset,
              child: IgnorePointer(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NotificationSettingsScreen.black,
                    fontFamily: NotificationSettingsScreen.fontFamily,
                    fontFamilyFallback: NotificationSettingsScreen.fontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllNotificationCard extends StatelessWidget {
  const _AllNotificationCard({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _RoundedPanel(
        child: Stack(
          children: [
            const Positioned(
              left: 16.903411865234375,
              top: 15.994140625,
              child: _TitleSubtitle(
                title: '전체 알림',
                subtitle: '모든 알림을 켜고 끌 수 있어요',
              ),
            ),
            Positioned(
              right: 16.903411865234375,
              top: 17.73583984375,
              child: _HowmuchToggle(
                value: value,
                activeColor: NotificationSettingsScreen.blue,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTypeCard extends StatelessWidget {
  const _NotificationTypeCard({
    required this.settings,
    required this.onPriceTap,
    required this.onReportTap,
    required this.onTodayPickTap,
    required this.onReviewTap,
  });

  final NotificationSettings settings;
  final VoidCallback onPriceTap;
  final VoidCallback onReportTap;
  final VoidCallback onTodayPickTap;
  final VoidCallback onReviewTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Column(
        children: [
          _NotificationRow(
            title: '가격 변동 알림',
            subtitle: '찜한 매장의 가격 변동 제보를 알려드려요.',
            value: settings.price,
            activeColor: NotificationSettingsScreen.orange,
            onTap: onPriceTap,
          ),
          const _CardDivider(),
          _NotificationRow(
            title: '제보 상태 알림',
            subtitle: '내 제보가 승인되거나 보완 요청되면 알려드려요.',
            value: settings.report,
            activeColor: NotificationSettingsScreen.blue,
            onTap: onReportTap,
          ),
          const _CardDivider(),
          _NotificationRow(
            title: '오늘의 픽 추천',
            subtitle: '날씨와 위치에 맞는 추천 매장을 알려드려요.',
            value: settings.todayPick,
            activeColor: NotificationSettingsScreen.green,
            onTap: onTodayPickTap,
          ),
          const _CardDivider(),
          _NotificationRow(
            title: '리뷰 반응 알림',
            subtitle: '내 리뷰에 반응이 있을 때 알려드려요.',
            value: settings.review,
            activeColor: NotificationSettingsScreen.blue,
            onTap: onReviewTap,
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 66.9602279663086,
        child: Stack(
          children: [
            Positioned(
              left: 16.903411865234375,
              top: 13.9912109375,
              child: _TitleSubtitle(
                title: title,
                subtitle: subtitle,
                compact: true,
              ),
            ),
            Positioned(
              right: 16.903411865234375,
              top: 7.9912109375,
              child: _HowmuchToggle(
                value: value,
                activeColor: activeColor,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceAlertEntryCard extends StatelessWidget {
  const _PriceAlertEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: const [
              Positioned(
                left: 16,
                top: 15.88037109375,
                child: _CircleIcon(
                  icon: Icons.notifications_none_rounded,
                  bg: AppColors.primaryLight,
                  color: NotificationSettingsScreen.blue,
                ),
              ),
              Positioned(
                left: 64.8863525390625,
                top: 14.900390625,
                child: _TitleSubtitle(
                  title: '구독 중인 가격 알림',
                  subtitle: '매장 3곳 · 메뉴 5개 관리',
                  compact: true,
                ),
              ),
              Positioned(
                right: 16.903411865234375,
                top: 25.88037109375,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: NotificationSettingsScreen.muted,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietHoursCard extends StatelessWidget {
  const _QuietHoursCard({required this.settings, required this.onToggle});

  final NotificationSettings settings;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 49,
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          const Positioned(
            left: 16.903411865234375,
            top: 16.9033203125,
            child: Text('설정 사용', style: _semi13),
          ),
          Positioned(
            right: 16.903411865234375,
            top: 10.9033203125,
            child: _HowmuchToggle(
              value: settings.quietHours,
              activeColor: NotificationSettingsScreen.blue,
              onTap: onToggle,
            ),
          ),
          Positioned(
            left: 16.903411865234375,
            top: 52.88330078125,
            child: _TimeBox(label: '시작 시간', value: settings.quietStart),
          ),
          Positioned(
            right: 16.903411865234375,
            top: 52.88330078125,
            child: _TimeBox(label: '종료 시간', value: settings.quietEnd),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146.81817626953125,
      height: 66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _muted11),
          const SizedBox(height: 5.994),
          Container(
            height: 41.9886360168457,
            padding: const EdgeInsets.symmetric(horizontal: 11.988),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(
                color: NotificationSettingsScreen.border,
                width: .909,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(value, style: _semi13),
                const Spacer(),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: NotificationSettingsScreen.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickySaveButton extends StatelessWidget {
  const _StickySaveButton({required this.safeBottom, required this.onPressed});

  static const buttonHeight = 51.9886360168457;
  static const topGap = 12.89794921875;
  static const bottomGap = 26.0;
  static const minimumSafeBottom = 34.0;

  final double safeBottom;
  final VoidCallback onPressed;

  static double effectiveSafeBottom(double safeBottom) {
    return safeBottom > minimumSafeBottom ? safeBottom : minimumSafeBottom;
  }

  static double heightFor(double safeBottom) {
    return topGap + buttonHeight + bottomGap + effectiveSafeBottom(safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottom = effectiveSafeBottom(safeBottom);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: NotificationSettingsScreen.border,
            width: .909,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: effectiveBottom + bottomGap,
            height: buttonHeight,
            child: SizedBox(
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NotificationSettingsScreen.blue,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: NotificationSettingsScreen.fontFamily,
                    fontFamilyFallback: NotificationSettingsScreen.fontFallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                onPressed: onPressed,
                child: const Text('설정 저장'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowmuchToggle extends StatelessWidget {
  const _HowmuchToggle({
    required this.value,
    required this.activeColor,
    required this.onTap,
  });

  final bool value;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: 52,
        height: 36,
        child: Align(
          alignment: Alignment.topRight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 23.99147605895996,
            decoration: BoxDecoration(
              color: value ? activeColor : NotificationSettingsScreen.disabled,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  left: value ? 18.991455078125 : 2.99713134765625,
                  top: 2.9970703125,
                  child: Container(
                    width: 17.99715805053711,
                    height: 17.99715805053711,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundedPanel extends StatelessWidget {
  const _RoundedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: NotificationSettingsScreen.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  const _TitleSubtitle({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 249.65908813476562 : 151.34942626953125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: compact ? _bold13 : _bold14),
          SizedBox(height: compact ? 2.997 : 1.989),
          Text(subtitle, style: _muted11, maxLines: 1),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.bg,
    required this.color,
  });

  final IconData icon;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35.99431610107422,
      height: 35.99431610107422,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 301.647705078125,
      height: .9943181276321411,
      child: ColoredBox(color: NotificationSettingsScreen.border),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _sectionText);
  }
}

const _bold14 = TextStyle(
  color: NotificationSettingsScreen.ink,
  fontFamily: NotificationSettingsScreen.fontFamily,
  fontFamilyFallback: NotificationSettingsScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _bold13 = TextStyle(
  color: NotificationSettingsScreen.ink,
  fontFamily: NotificationSettingsScreen.fontFamily,
  fontFamilyFallback: NotificationSettingsScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _semi13 = TextStyle(
  color: NotificationSettingsScreen.ink,
  fontFamily: NotificationSettingsScreen.fontFamily,
  fontFamilyFallback: NotificationSettingsScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _muted11 = TextStyle(
  color: NotificationSettingsScreen.muted,
  fontFamily: NotificationSettingsScreen.fontFamily,
  fontFamilyFallback: NotificationSettingsScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _sectionText = TextStyle(
  color: NotificationSettingsScreen.muted,
  fontFamily: NotificationSettingsScreen.fontFamily,
  fontFamilyFallback: NotificationSettingsScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

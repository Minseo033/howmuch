import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
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
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isSaving = false;
  NotificationSettings? _savedSettings;

  bool _dirty(NotificationSettings? current) =>
      current != null &&
      _savedSettings != null &&
      !current.sameAs(_savedSettings!);

  Future<void> _leave(NotificationSettings? current) async {
    if (_isSaving) return;
    if (_dirty(current)) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('저장하지 않고 나갈까요?'),
          content: const Text('변경한 알림 설정은 아직 저장되지 않았어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 편집'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    context.go(AppRoutes.mypage);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final saveFooterHeight = _StickySaveButton.heightFor(bottomOffset);
    final scrollContentHeight =
        715.5341796875 + topOffset + saveFooterHeight + 36;

    void update(NotificationSettings value) {
      if (_isSaving) return;
      ref.read(notificationSettingsProvider.notifier).updateSettings(value);
    }

    void updateTypes({
      bool? price,
      bool? report,
      bool? todayPick,
      bool? review,
      required NotificationSettings current,
    }) {
      final next = current.copyWith(
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

    void goBack() => _leave(settingsAsync.valueOrNull);

    Future<void> pickQuietTime({
      required NotificationSettings current,
      required bool isStart,
    }) async {
      final initialValue = isStart ? current.quietStart : current.quietEnd;
      final initialTime = _parseTime(initialValue);
      final title = isStart ? '방해 금지 시작 시간' : '방해 금지 종료 시간';
      final mediaQuery = MediaQuery.of(context);
      final sheetMaxWidth = math.min(
        FigmaMobileCanvas.maxWebWidth,
        mediaQuery.size.width,
      );
      final sheetMaxHeight = math.max(
        0.0,
        math.min(320.0, mediaQuery.size.height - mediaQuery.padding.top - 8),
      );

      final picked = await showModalBottomSheet<TimeOfDay>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: BoxConstraints(
          maxWidth: sheetMaxWidth,
          maxHeight: sheetMaxHeight,
        ),
        builder: (modalContext) {
          TimeOfDay tempTime = initialTime;
          final now = DateTime.now();
          final initialDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            initialTime.hour,
            initialTime.minute,
          );

          return Container(
            key: const ValueKey('quiet-time-bottom-sheet'),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(modalContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NotificationSettingsScreen.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(modalContext),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            color: NotificationSettingsScreen.muted,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: NotificationSettingsScreen.ink,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(modalContext, tempTime),
                        child: const Text(
                          '완료',
                          style: TextStyle(
                            color: NotificationSettingsScreen.blue,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  color: NotificationSettingsScreen.border,
                ),
                Flexible(
                  child: SizedBox(
                    height: 180,
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        brightness: Brightness.light,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            fontSize: 20,
                            color: NotificationSettingsScreen.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: false,
                        initialDateTime: initialDateTime,
                        onDateTimeChanged: (DateTime newDateTime) {
                          tempTime = TimeOfDay(
                            hour: newDateTime.hour,
                            minute: newDateTime.minute,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (picked == null || _isSaving) return;
      final serialized = _serializeTime(picked);
      update(
        isStart
            ? current.copyWith(quietStart: serialized)
            : current.copyWith(quietEnd: serialized),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: FigmaMobileCanvas(
        backgroundColor: NotificationSettingsScreen.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: settingsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: NotificationSettingsScreen.blue,
                  ),
                ),
                error: (err, stack) {
                  final unauthorized =
                      err is NotificationSettingsApiException &&
                      err.isUnauthorized;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.warning,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            unauthorized ? '로그인이 필요해요' : '설정을 불러오지 못했어요',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            unauthorized
                                ? '로그인한 뒤 알림 설정을 변경할 수 있어요.'
                                : '잠시 후 다시 시도해 주세요.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 140,
                            height: 40,
                            child: FilledButton(
                              onPressed: () => ref
                                  .read(notificationSettingsProvider.notifier)
                                  .loadSettings(),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    NotificationSettingsScreen.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '다시 시도',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (settings) {
                  _savedSettings ??= settings;
                  return SingleChildScrollView(
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
                            left: 20,
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
                              onPriceTap: () => updateTypes(
                                price: !settings.price,
                                current: settings,
                              ),
                              onReportTap: () => updateTypes(
                                report: !settings.report,
                                current: settings,
                              ),
                              onTodayPickTap: () => updateTypes(
                                todayPick: !settings.todayPick,
                                current: settings,
                              ),
                              onReviewTap: () => updateTypes(
                                review: !settings.review,
                                current: settings,
                              ),
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
                            left: 20,
                            top: 547.04541015625 + topOffset,
                            child: const _SectionLabel('방해 금지 시간'),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            top: 571.5341796875 + topOffset,
                            height: 144,
                            child: _QuietHoursCard(
                              settings: settings,
                              onToggle: () => update(
                                settings.copyWith(
                                  quietHours: !settings.quietHours,
                                ),
                              ),
                              onStartTap: () => pickQuietTime(
                                current: settings,
                                isStart: true,
                              ),
                              onEndTap: () => pickQuietTime(
                                current: settings,
                                isStart: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _Header(topOffset: topOffset, title: '알림 설정', onBack: goBack),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              height: saveFooterHeight,
              child: settingsAsync.maybeWhen(
                data: (settings) => _StickySaveButton(
                  safeBottom: bottomOffset,
                  isSaving: _isSaving,
                  onPressed: () async {
                    if (_isSaving) return;
                    if (settings.quietHours &&
                        settings.quietStart == settings.quietEnd) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('방해 금지 시작·종료 시간을 다르게 선택해 주세요.'),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _isSaving = true;
                    });
                    final messenger = ScaffoldMessenger.of(context);
                    final router = GoRouter.of(context);
                    final success = await ref
                        .read(notificationSettingsProvider.notifier)
                        .saveSettings(settings);
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                      messenger.clearSnackBars();
                      if (success) {
                        _savedSettings = settings;
                        router.go(AppRoutes.mypage);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('알림 설정을 저장했어요.')),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('설정 저장 중 오류가 발생했습니다. 다시 시도해 주세요.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 22, minute: 0);
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _serializeTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: _TitleSubtitle(
                  title: '전체 알림',
                  subtitle: '모든 알림을 켜고 끌 수 있어요',
                ),
              ),
              const SizedBox(width: 12),
              _HowmuchToggle(
                value: value,
                activeColor: NotificationSettingsScreen.blue,
                onTap: onTap,
              ),
            ],
          ),
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
      key: const ValueKey('notification-type-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotificationRow(
            title: '가격 변동 알림',
            subtitle: '찜한 매장의 가격 변동 제보를 알려드려요.',
            value: settings.price,
            activeColor: NotificationSettingsScreen.orange,
            onTap: onPriceTap,
          ),
          const _CardDivider(lineKey: ValueKey('notification-type-divider')),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _TitleSubtitle(
                  title: title,
                  subtitle: subtitle,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              _HowmuchToggle(
                value: value,
                activeColor: activeColor,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceAlertEntryCard extends ConsumerWidget {
  const _PriceAlertEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(priceAlertSettingsProvider);
    final subtitle = settings.when(
      data: (value) {
        final enabled = value.stores.where((store) => store.enabled).toList();
        final menuCount = enabled
            .where((store) => store.menuName.trim().isNotEmpty)
            .length;
        return '매장 ${enabled.length}곳 · 메뉴 $menuCount개 관리';
      },
      loading: () => '가격 알림 정보를 불러오는 중',
      error: (_, _) => '가격 알림에서 구독 현황 확인',
    );
    return _RoundedPanel(
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _CircleIcon(
                  icon: Icons.notifications_none_rounded,
                  bg: AppColors.primaryLight,
                  color: NotificationSettingsScreen.blue,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _TitleSubtitle(
                    title: '구독 중인 가격 알림',
                    subtitle: subtitle,
                    compact: true,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NotificationSettingsScreen.muted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietHoursCard extends StatelessWidget {
  const _QuietHoursCard({
    required this.settings,
    required this.onToggle,
    required this.onStartTap,
    required this.onEndTap,
  });

  final NotificationSettings settings;
  final VoidCallback onToggle;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('설정 사용', style: _semi13),
                    _HowmuchToggle(
                      value: settings.quietHours,
                      activeColor: NotificationSettingsScreen.blue,
                      onTap: onToggle,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeBox(
                    label: '시작 시간',
                    value: settings.quietStart,
                    onTap: onStartTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeBox(
                    label: '종료 시간',
                    value: settings.quietEnd,
                    onTap: onEndTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _muted11),
          const SizedBox(height: 5.994),
          Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(
                color: NotificationSettingsScreen.border,
                width: .909,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 41.9886360168457,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11.988),
                  child: Row(
                    children: [
                      Text(_displayTime(value), style: _semi13),
                      const Spacer(),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: NotificationSettingsScreen.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayTime(String rawValue) {
    final parts = rawValue.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return rawValue;
    }
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }
}

class _StickySaveButton extends StatelessWidget {
  const _StickySaveButton({
    required this.safeBottom,
    required this.onPressed,
    this.isSaving = false,
  });

  static const buttonHeight = 51.9886360168457;
  static const topGap = 12.89794921875;
  static const bottomGap = 26.0;
  static const minimumSafeBottom = 34.0;

  final double safeBottom;
  final VoidCallback onPressed;
  final bool isSaving;

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
                onPressed: isSaving ? null : onPressed,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('설정 저장'),
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
          alignment: Alignment.centerRight,
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
                          color: AppColors.black.withValues(alpha: 0.2),
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
  const _RoundedPanel({super.key, required this.child});

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
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: compact ? _bold13 : _bold14),
          SizedBox(height: compact ? 3.0 : 2.0),
          Text(
            subtitle,
            style: _muted11,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
  const _CardDivider({this.lineKey});

  final Key? lineKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ColoredBox(
          key: lineKey,
          color: NotificationSettingsScreen.border,
        ),
      ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class PriceAlertSubscriptionScreen extends ConsumerWidget {
  const PriceAlertSubscriptionScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
  static const border = Color(0xFFE5E7EB);
  static const disabled = Color(0xFFCBD5E1);
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
    final settings = ref.watch(priceAlertSettingsProvider);
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyButton.heightFor(bottomOffset);
    final scrollContentHeight = 592 + topOffset + footerHeight + 24;

    void update(PriceAlertSettings value) {
      ref.read(priceAlertSettingsProvider.notifier).state = value;
    }

    void updateStore(int index) {
      final stores = [
        for (var i = 0; i < settings.stores.length; i++)
          i == index
              ? settings.stores[i].copyWith(
                  enabled: !settings.stores[i].enabled,
                )
              : settings.stores[i],
      ];

      update(
        settings.copyWith(
          stores: stores,
          all: stores.every((store) => store.enabled),
        ),
      );
    }

    return FigmaMobileCanvas(
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(
                width: FigmaMobileCanvas.width,
                height: scrollContentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 64.8720703125 + topOffset,
                      width: 335.45452880859375,
                      height: 20.142044067382812,
                      child: const Text(
                        '찜한 매장의 가격 변동 제보를 받아볼 수 있어요',
                        style: _descriptionText,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 99.00537109375 + topOffset,
                      width: 335.45452880859375,
                      height: 69.2897720336914,
                      child: _AllAlertCard(
                        value: settings.all,
                        onTap: () {
                          final next = !settings.all;
                          update(
                            settings.copyWith(
                              all: next,
                              stores: [
                                for (final store in settings.stores)
                                  store.copyWith(enabled: next),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 184.28955078125 + topOffset,
                      child: const _SectionLabel('매장별 알림'),
                    ),
                    Positioned(
                      left: 20,
                      top: 208.7783203125 + topOffset,
                      width: 335.45452880859375,
                      height: 223.86363220214844,
                      child: Column(
                        children: [
                          for (var i = 0; i < settings.stores.length; i++) ...[
                            _StoreAlertCard(
                              store: settings.stores[i],
                              onTap: () => updateStore(i),
                            ),
                            if (i != settings.stores.length - 1)
                              const SizedBox(height: 7.997),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 452.64208984375 + topOffset,
                      child: const _SectionLabel('알림 조건'),
                    ),
                    Positioned(
                      left: 20,
                      top: 477.13037109375 + topOffset,
                      width: 335.45452880859375,
                      height: 163.59375,
                      child: _ConditionCard(
                        settings: settings,
                        onRiseTap: () => update(
                          settings.copyWith(
                            notifyOnRise: !settings.notifyOnRise,
                          ),
                        ),
                        onDropTap: () => update(
                          settings.copyWith(
                            notifyOnDrop: !settings.notifyOnDrop,
                          ),
                        ),
                        onNewMenuTap: () => update(
                          settings.copyWith(
                            notifyOnNewMenu: !settings.notifyOnNewMenu,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Header(
            topOffset: topOffset,
            title: '가격 알림 구독',
            onBack: () => context.go(AppRoutes.notificationSettings),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
            height: footerHeight,
            child: _StickyButton(
              safeBottom: bottomOffset,
              label: '설정 저장',
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                // TODO(박지환 BE): 가격 알림 구독/해제 API가 붙으면 매장별 알림 상태를 서버에 저장하세요.
                messenger.clearSnackBars();
                context.go(AppRoutes.notificationSettings);
                messenger.showSnackBar(
                  const SnackBar(content: Text('가격 알림을 저장했어요.')),
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
      width: FigmaMobileCanvas.width,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: PriceAlertSubscriptionScreen.border,
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
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: PriceAlertSubscriptionScreen.ink,
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
                    color: PriceAlertSubscriptionScreen.black,
                    fontFamily: PriceAlertSubscriptionScreen.fontFamily,
                    fontFamilyFallback:
                        PriceAlertSubscriptionScreen.fontFallback,
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

class _AllAlertCard extends StatelessWidget {
  const _AllAlertCard({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            const Positioned(
              left: 14.90057373046875,
              top: 14.90087890625,
              child: _TitleSubtitle(
                title: '전체 알림',
                subtitle: '모든 매장의 변동 알림을 받습니다',
                titleWeight: FontWeight.w800,
              ),
            ),
            Positioned(
              right: 14.90057373046875,
              top: 16.8896484375,
              child: _ToggleSm(value: value, onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreAlertCard extends StatelessWidget {
  const _StoreAlertCard({required this.store, required this.onTap});

  final PriceAlertStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 335.45452880859375,
      height: 69.2897720336914,
      child: _RoundedCard(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            children: [
              const Positioned(
                left: 14.90057373046875,
                top: 25.63916015625,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: PriceAlertSubscriptionScreen.orange,
                ),
              ),
              Positioned(
                left: 44.88641357421875,
                top: 14.900390625,
                child: _TitleSubtitle(
                  title: store.storeName,
                  subtitle: store.menuName,
                ),
              ),
              Positioned(
                right: 14.90057373046875,
                top: 16.8896484375,
                child: _ToggleSm(value: store.enabled, onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.settings,
    required this.onRiseTap,
    required this.onDropTap,
    required this.onNewMenuTap,
  });

  final PriceAlertSettings settings;
  final VoidCallback onRiseTap;
  final VoidCallback onDropTap;
  final VoidCallback onNewMenuTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Column(
        children: [
          _ConditionRow(
            label: '가격 인상',
            dotColor: PriceAlertSubscriptionScreen.orange,
            value: settings.notifyOnRise,
            onTap: onRiseTap,
          ),
          const _Divider(),
          _ConditionRow(
            label: '가격 인하',
            dotColor: PriceAlertSubscriptionScreen.green,
            value: settings.notifyOnDrop,
            onTap: onDropTap,
          ),
          const _Divider(),
          _ConditionRow(
            label: '새 메뉴 등록',
            dotColor: PriceAlertSubscriptionScreen.blue,
            value: settings.notifyOnNewMenu,
            onTap: onNewMenuTap,
          ),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.label,
    required this.dotColor,
    required this.value,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 53.925,
        child: Stack(
          children: [
            Positioned(
              left: 14.90057373046875,
              top: 23,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 7.997159004211426,
                  height: 7.997159004211426,
                ),
              ),
            ),
            Positioned(
              left: 30.8948974609375,
              top: 17.2,
              child: Text(label, style: _conditionText),
            ),
            Positioned(
              right: 14.90057373046875,
              top: 15.1,
              child: _ToggleSm(value: value, onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSm extends StatelessWidget {
  const _ToggleSm({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
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
              color: value
                  ? PriceAlertSubscriptionScreen.blue
                  : PriceAlertSubscriptionScreen.disabled,
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
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

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.safeBottom,
    required this.label,
    required this.onPressed,
  });

  static const buttonHeight = 50.48295211791992;
  static const topGap = 12.8974609375;
  static const bottomGap = 26.0;
  static const minimumSafeBottom = 34.0;

  final double safeBottom;
  final String label;
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: PriceAlertSubscriptionScreen.border,
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: PriceAlertSubscriptionScreen.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: PriceAlertSubscriptionScreen.fontFamily,
                  fontFamilyFallback: PriceAlertSubscriptionScreen.fontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  const _RoundedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: PriceAlertSubscriptionScreen.border,
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
    this.titleWeight = FontWeight.w700,
  });

  final String title;
  final String subtitle;
  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.25,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _cardTitle.copyWith(fontWeight: titleWeight)),
          const SizedBox(height: 1.989),
          Text(subtitle, style: _captionText, maxLines: 1),
        ],
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 305.6534118652344,
      height: .909,
      child: ColoredBox(color: PriceAlertSubscriptionScreen.border),
    );
  }
}

const _descriptionText = TextStyle(
  color: PriceAlertSubscriptionScreen.muted,
  fontFamily: PriceAlertSubscriptionScreen.fontFamily,
  fontFamilyFallback: PriceAlertSubscriptionScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _sectionText = TextStyle(
  color: PriceAlertSubscriptionScreen.muted,
  fontFamily: PriceAlertSubscriptionScreen.fontFamily,
  fontFamilyFallback: PriceAlertSubscriptionScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .5,
);

const _cardTitle = TextStyle(
  color: PriceAlertSubscriptionScreen.ink,
  fontFamily: PriceAlertSubscriptionScreen.fontFamily,
  fontFamilyFallback: PriceAlertSubscriptionScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _captionText = TextStyle(
  color: PriceAlertSubscriptionScreen.muted,
  fontFamily: PriceAlertSubscriptionScreen.fontFamily,
  fontFamilyFallback: PriceAlertSubscriptionScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _conditionText = TextStyle(
  color: PriceAlertSubscriptionScreen.ink,
  fontFamily: PriceAlertSubscriptionScreen.fontFamily,
  fontFamilyFallback: PriceAlertSubscriptionScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

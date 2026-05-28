import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  static const red = Color(0xFFEF4444);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
  static const border = Color(0xFFE5E7EB);
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
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _reasons = const [
    '원하는 매장 정보가 부족해요',
    '가격 정보가 정확하지 않아요',
    '자주 사용하지 않아요',
    '유사한 다른 서비스를 이용해요',
    '기타',
  ];
  int _selectedReason = 1;
  bool _confirmed = true;

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyActions.heightFor(bottomOffset);
    final contentHeight = 876 + topOffset + footerHeight + 24;

    return FigmaMobileCanvas(
      backgroundColor: WithdrawalScreen.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(
                width: FigmaMobileCanvas.width,
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 64.8720703125 + topOffset,
                      width: 335.45452880859375,
                      height: 92.94033813476562,
                      child: const _WarningCard(),
                    ),
                    Positioned(
                      left: 23.991455078125,
                      top: 173.806640625 + topOffset,
                      child: const _SectionLabel('탈퇴 시 삭제되는 데이터'),
                    ),
                    Positioned(
                      left: 20,
                      top: 198.29541015625 + topOffset,
                      width: 335.45452880859375,
                      height: 223.1818084716797,
                      child: const _DeletedDataCard(),
                    ),
                    Positioned(
                      left: 20,
                      top: 433.4658203125 + topOffset,
                      width: 335.45452880859375,
                      height: 58.039772033691406,
                      child: const _InfoBox(),
                    ),
                    Positioned(
                      left: 23.991455078125,
                      top: 511.50537109375 + topOffset,
                      child: const _SectionLabel('탈퇴 사유 (선택)'),
                    ),
                    Positioned(
                      left: 20,
                      top: 535.994140625 + topOffset,
                      width: 335.45452880859375,
                      height: 225.3408966064453,
                      child: _ReasonsCard(
                        reasons: _reasons,
                        selectedIndex: _selectedReason,
                        onChanged: (index) =>
                            setState(() => _selectedReason = index),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 777.32958984375 + topOffset,
                      width: 335.45452880859375,
                      height: 70.99431610107422,
                      child: _ConsentCard(
                        confirmed: _confirmed,
                        onTap: () => setState(() => _confirmed = !_confirmed),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Header(
            topOffset: topOffset,
            title: '회원 탈퇴',
            onBack: () => context.go(AppRoutes.accountManagement),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
            height: footerHeight,
            child: _StickyActions(
              safeBottom: bottomOffset,
              onCancel: () => context.go(AppRoutes.accountManagement),
              onWithdraw: _withdraw,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_confirmed) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('탈퇴 동의 내용을 확인해주세요.')));
      return;
    }

    final shouldWithdraw = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: Text(
            '선택한 사유: ${_reasons[_selectedReason]}\n탈퇴하면 앱 데이터가 삭제돼요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('탈퇴하기'),
            ),
          ],
        );
      },
    );

    if (shouldWithdraw != true || !mounted) {
      return;
    }

    // TODO(박지환 BE): 실제 회원 탈퇴 API 호출 후 성공 응답을 받으면 로컬 세션을 종료합니다.
    ref.read(authStateProvider.notifier).state = const AuthState(
      isLoggedIn: false,
      isAdmin: false,
      provider: '이메일',
      email: '',
    );

    messenger.clearSnackBars();
    context.go(AppRoutes.login);
    messenger.showSnackBar(const SnackBar(content: Text('회원 탈퇴가 완료되었어요.')));
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
            bottom: BorderSide(color: WithdrawalScreen.border, width: .909),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 68,
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
                        color: WithdrawalScreen.ink,
                        size: 24,
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
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _titleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        border: Border.all(color: const Color(0x33EF4444), width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 16.9033203125,
            top: 16.9033203125,
            child: _CircleIcon(
              size: 37.99715805053711,
              background: Colors.white,
              icon: Icons.warning_amber_rounded,
              iconColor: WithdrawalScreen.red,
              iconSize: 18,
            ),
          ),
          Positioned(
            left: 66.88916015625,
            top: 15.8125,
            width: 251.66192626953125,
            child: const Text('탈퇴 전 꼭 확인해주세요', style: _warningTitleText),
          ),
          Positioned(
            left: 66.88916015625,
            top: 39.29248046875,
            width: 251.66192626953125,
            child: RichText(
              text: const TextSpan(
                style: _warningBodyText,
                children: [
                  TextSpan(text: '탈퇴 후에는 동일 계정으로 재가입해도\n'),
                  TextSpan(
                    text: '이전 데이터는 복구되지 않습니다.',
                    style: TextStyle(fontWeight: FontWeight.w700),
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

class _DeletedDataCard extends StatelessWidget {
  const _DeletedDataCard();

  static const items = [
    ('내 제보 내역', '2건', Icons.feed_outlined),
    ('찜한 매장', '12곳', Icons.favorite_border_rounded),
    ('방문 인증 · 절약 리포트', '24,500원 누적', Icons.trending_down_rounded),
    ('작성한 리뷰 · 댓글', '7개', Icons.chat_bubble_outline_rounded),
    ('가격 알림 구독', '5개 메뉴', Icons.notifications_none_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.903, 12.897, 16.904, .909),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _DeletedDataRow(
                title: items[index].$1,
                value: items[index].$2,
                icon: items[index].$3,
              ),
              if (index != items.length - 1) const _CardDivider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeletedDataRow extends StatelessWidget {
  const _DeletedDataRow({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38.75,
      child: Row(
        children: [
          Icon(icon, size: 14, color: WithdrawalScreen.muted),
          const SizedBox(width: 9.999),
          Expanded(
            child: Text(
              title,
              style: _deletedTitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(value, style: _deletedValueText),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 11.988,
            top: 13.977,
            child: Icon(
              Icons.info_outline_rounded,
              size: 12.997,
              color: WithdrawalScreen.muted,
            ),
          ),
          Positioned(
            left: 32.98291015625,
            top: 11.98876953125,
            width: 290.4829406738281,
            child: RichText(
              text: const TextSpan(
                style: _infoText,
                children: [
                  TextSpan(text: '승인된 제보 데이터는 '),
                  TextSpan(
                    text: '익명화되어 다른 사용자에게 계속 제공',
                    style: TextStyle(
                      color: WithdrawalScreen.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: '됩니다. (개인정보처리방침 제 7조)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({
    required this.reasons,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> reasons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.9033203125),
        child: Column(
          children: [
            for (var index = 0; index < reasons.length; index++) ...[
              _ReasonRow(
                label: reasons[index],
                selected: selectedIndex == index,
                onTap: () => onChanged(index),
              ),
              if (index != reasons.length - 1) const _CardDivider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Text(label, style: selected ? _reasonSelectedText : _reasonText),
              const Spacer(),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.confirmed, required this.onTap});

  final bool confirmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0x33EF4444), width: .909),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 16.9033203125,
                top: 17.983,
                child: _CheckBoxMark(selected: confirmed),
              ),
              Positioned(
                left: 46.88916015625,
                top: 15.994,
                width: 240.24147033691406,
                child: RichText(
                  text: const TextSpan(
                    style: _consentText,
                    children: [
                      TextSpan(text: '위 내용을 모두 확인했으며,\n'),
                      TextSpan(
                        text: '탈퇴 시 데이터가 영구 삭제됨에 동의합니다.',
                        style: TextStyle(
                          color: WithdrawalScreen.red,
                          fontWeight: FontWeight.w700,
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

class _StickyActions extends StatelessWidget {
  const _StickyActions({
    required this.safeBottom,
    required this.onCancel,
    required this.onWithdraw,
  });

  static const buttonHeight = 50.0;
  static const topGap = 12.89794921875;
  static const bottomGap = 26.0;
  static const minimumSafeBottom = 34.0;

  final double safeBottom;
  final VoidCallback onCancel;
  final VoidCallback onWithdraw;

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
          top: BorderSide(color: WithdrawalScreen.border, width: .909),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: effectiveBottom + bottomGap,
            height: buttonHeight,
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: '취소',
                    background: Colors.white,
                    foreground: WithdrawalScreen.ink,
                    borderColor: WithdrawalScreen.border,
                    onTap: onCancel,
                  ),
                ),
                const SizedBox(width: 7.997),
                Expanded(
                  child: _ActionButton(
                    label: '탈퇴하기',
                    background: WithdrawalScreen.red,
                    foreground: Colors.white,
                    shadowColor: WithdrawalScreen.red.withValues(alpha: .3),
                    onTap: onWithdraw,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
    this.shadowColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: .909),
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadowColor == null
                ? null
                : [
                    BoxShadow(
                      color: shadowColor!,
                      blurRadius: 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontFamily: WithdrawalScreen.fontFamily,
                fontFamilyFallback: WithdrawalScreen.fontFallback,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? WithdrawalScreen.red : Colors.white,
        border: Border.all(
          color: selected ? WithdrawalScreen.red : const Color(0xFFCBD5E1),
          width: .909,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
          : null,
    );
  }
}

class _CheckBoxMark extends StatelessWidget {
  const _CheckBoxMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17.99715805053711,
      height: 17.99715805053711,
      decoration: BoxDecoration(
        color: selected ? WithdrawalScreen.red : Colors.white,
        border: selected
            ? null
            : Border.all(color: const Color(0xFFCBD5E1), width: .909),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
          : null,
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.size,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.iconSize,
  });

  final double size;
  final Color background;
  final IconData icon;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: iconSize),
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
        color: Colors.white,
        border: Border.all(color: WithdrawalScreen.border, width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 301.647705078125,
      height: .909,
      child: ColoredBox(color: WithdrawalScreen.border),
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

const _titleText = TextStyle(
  color: WithdrawalScreen.black,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _warningTitleText = TextStyle(
  color: WithdrawalScreen.red,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _warningBodyText = TextStyle(
  color: WithdrawalScreen.ink,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _sectionText = TextStyle(
  color: WithdrawalScreen.muted,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _deletedTitleText = TextStyle(
  color: WithdrawalScreen.ink,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _deletedValueText = TextStyle(
  color: WithdrawalScreen.red,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _infoText = TextStyle(
  color: WithdrawalScreen.muted,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _reasonText = TextStyle(
  color: WithdrawalScreen.ink,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _reasonSelectedText = TextStyle(
  color: WithdrawalScreen.ink,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _consentText = TextStyle(
  color: WithdrawalScreen.ink,
  fontFamily: WithdrawalScreen.fontFamily,
  fontFamilyFallback: WithdrawalScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

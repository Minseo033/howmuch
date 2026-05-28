import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ConnectedSocialAccountsScreen extends ConsumerWidget {
  const ConnectedSocialAccountsScreen({super.key});

  static const blue = Color(0xFF2563EB);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(socialAccountsProvider);
    final connectedAccounts = accounts.where((account) => account.connected);
    final availableAccounts = accounts.where((account) => !account.connected);
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;
    final bottomOffset = FigmaMobileCanvas.designSafePaddingOf(context).bottom;
    final connectedRowsHeight = _rowsHeight(connectedAccounts.length, 85.014);
    final availableLabelTop = 143.76416015625 + connectedRowsHeight + 15.994;
    final availableRowsTop = availableLabelTop + 24.488;
    final availableRowsHeight = _rowsHeight(availableAccounts.length, 75.795);
    final primaryCardTop = availableRowsTop + availableRowsHeight + 15.994;
    final noticeTop = primaryCardTop + 82.77;
    final contentHeight = noticeTop + 58.04 + bottomOffset + 32;

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
                width: FigmaMobileCanvas.width,
                height: contentHeight + topOffset,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 64.8720703125 + topOffset,
                      width: 335.45452880859375,
                      height: 87.28692626953125,
                      child: const _IntroCard(),
                    ),
                    Positioned(
                      left: 23.9912109375,
                      top: 168.1533203125 + topOffset,
                      child: _SectionLabel(
                        '연결된 계정 · ${connectedAccounts.length}개',
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 192.64208984375 + topOffset,
                      width: 335.45452880859375,
                      height: connectedRowsHeight,
                      child: _SocialRows(
                        rowHeight: 85.01419830322266,
                        accounts: connectedAccounts.toList(),
                        onConnect: (account) =>
                            _connectAccount(context, ref, account),
                        onDisconnect: (account) =>
                            _disconnectAccount(context, ref, account),
                      ),
                    ),
                    Positioned(
                      left: 23.9912109375,
                      top: availableLabelTop + topOffset,
                      child: const _SectionLabel('연결 가능'),
                    ),
                    Positioned(
                      left: 20,
                      top: availableRowsTop + topOffset,
                      width: 335.45452880859375,
                      height: availableRowsHeight,
                      child: _SocialRows(
                        rowHeight: 75.79544830322266,
                        accounts: availableAccounts.toList(),
                        onConnect: (account) =>
                            _connectAccount(context, ref, account),
                        onDisconnect: (account) =>
                            _disconnectAccount(context, ref, account),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: primaryCardTop + topOffset,
                      width: 335.45452880859375,
                      height: 70.78125,
                      child: _PrimaryChangeCard(
                        onTap: () => _showPrimaryAccountSheet(context, ref),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: noticeTop + topOffset,
                      width: 335.45452880859375,
                      height: 58.039772033691406,
                      child: const _NoticeBox(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Header(
            topOffset: topOffset,
            title: '연결된 소셜 계정',
            onBack: () => context.go(AppRoutes.accountManagement),
          ),
        ],
      ),
    );
  }

  static double _rowsHeight(int count, double rowHeight) {
    if (count == 0) {
      return 0;
    }

    return count * rowHeight + (count - 1) * 7.997 + 1;
  }

  void _connectAccount(
    BuildContext context,
    WidgetRef ref,
    SocialAccount selected,
  ) {
    final profile = ref.read(userProfileProvider);
    final today = _todayText();

    // TODO(Backend/OAuth): 실제 소셜 OAuth 연결 API 응답으로 이메일과 연결일을 교체합니다.
    _updateAccounts(ref, (account) {
      if (account.id != selected.id) {
        return account;
      }

      return account.copyWith(
        connected: true,
        email: profile.email,
        connectedAt: today,
      );
    });

    _showSnackBar(context, '${selected.name} 계정을 연결했어요.');
  }

  void _disconnectAccount(
    BuildContext context,
    WidgetRef ref,
    SocialAccount selected,
  ) {
    if (selected.isPrimary) {
      _showSnackBar(context, '주 계정은 해제할 수 없어요.');
      return;
    }

    _updateAccounts(ref, (account) {
      if (account.id != selected.id) {
        return account;
      }

      return account.copyWith(connected: false, email: '', connectedAt: '');
    });
    _showSnackBar(context, '${selected.name} 계정을 해제했어요.');
  }

  Future<void> _showPrimaryAccountSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final connectedAccounts = ref
        .read(socialAccountsProvider)
        .where((account) => account.connected)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('주 계정 변경', style: _sheetTitleText),
                const SizedBox(height: 4),
                const Text(
                  '알림 수신과 계정 복구에 사용할 계정을 선택해주세요.',
                  style: _sheetBodyText,
                ),
                const SizedBox(height: 14),
                for (final account in connectedAccounts)
                  _PrimaryOption(
                    account: account,
                    onTap: () {
                      _updateAccounts(ref, (candidate) {
                        return candidate.copyWith(
                          isPrimary: candidate.id == account.id,
                        );
                      });
                      Navigator.of(sheetContext).pop();
                      _showSnackBar(
                        context,
                        '${account.name} 계정을 주 계정으로 변경했어요.',
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateAccounts(
    WidgetRef ref,
    SocialAccount Function(SocialAccount account) update,
  ) {
    ref.read(socialAccountsProvider.notifier).state = [
      for (final account in ref.read(socialAccountsProvider)) update(account),
    ];
  }

  static String _todayText() {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${now.year}.${twoDigits(now.month)}.${twoDigits(now.day)}';
  }

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              color: ConnectedSocialAccountsScreen.border,
              width: .909,
            ),
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
                        color: ConnectedSocialAccountsScreen.ink,
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

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        border: Border.all(color: const Color(0x212563EB), width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16.9033203125,
            top: 16.9033203125,
            child: _CircleIcon(
              size: 37.99715805053711,
              background: Colors.white,
              icon: Icons.verified_user_outlined,
              iconColor: ConnectedSocialAccountsScreen.blue,
              iconSize: 16.99,
            ),
          ),
          Positioned(
            left: 66.88916015625,
            top: 15.8125,
            width: 251.66192626953125,
            child: RichText(
              text: const TextSpan(
                style: _introText,
                children: [
                  TextSpan(text: '여러 개의 소셜 계정을 연결하면\n'),
                  TextSpan(
                    text: '어느 계정으로 로그인해도 같은 데이터',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '로 접근할 수 있어요.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialRows extends StatelessWidget {
  const _SocialRows({
    required this.accounts,
    required this.rowHeight,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<SocialAccount> accounts;
  final double rowHeight;
  final ValueChanged<SocialAccount> onConnect;
  final ValueChanged<SocialAccount> onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < accounts.length; index++) ...[
          _SocialRow(
            account: accounts[index],
            height: rowHeight,
            onConnect: () => onConnect(accounts[index]),
            onDisconnect: () => onDisconnect(accounts[index]),
          ),
          if (index != accounts.length - 1) const SizedBox(height: 7.997),
        ],
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.account,
    required this.height,
    required this.onConnect,
    required this.onDisconnect,
  });

  final SocialAccount account;
  final double height;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final isConnected = account.connected;
    final buttonLabel = account.isPrimary
        ? '주 계정'
        : isConnected
        ? '해제'
        : '연결';
    final buttonColor = account.isPrimary
        ? Colors.white
        : isConnected
        ? const Color(0xFFF1F5F9)
        : ConnectedSocialAccountsScreen.blue;
    final buttonTextColor = account.isPrimary
        ? ConnectedSocialAccountsScreen.muted
        : isConnected
        ? ConnectedSocialAccountsScreen.ink
        : Colors.white;
    final subtitle = isConnected
        ? '${account.email} · 연결\n${account.connectedAt}'
        : '아직 연결되지 않았어요';

    return Container(
      width: 335.45452880859375,
      height: height,
      decoration: BoxDecoration(
        color: account.isPrimary ? const Color(0xFFEFF4FF) : Colors.white,
        border: Border.all(
          color: account.isPrimary
              ? const Color(0x332563EB)
              : ConnectedSocialAccountsScreen.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: isConnected ? 18.59 : 13.99,
            child: _SocialBadge(account: account),
          ),
          Positioned(
            left: 71.97,
            top: isConnected ? 13.99 : 17.63,
            width: isConnected ? 193.68 : 193.68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(account.name, style: _accountNameText),
                    if (account.isPrimary) ...[
                      const SizedBox(width: 5.994),
                      const _PrimaryBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 1.989),
                Text(subtitle, style: _accountSubtitleText),
              ],
            ),
          ),
          Positioned(
            right: account.isPrimary ? 15.81 : 14.9,
            top: account.isPrimary
                ? 26.45
                : isConnected
                ? 27.36
                : 22.74,
            width: account.isPrimary ? 58.693180084228516 : 42.002838134765625,
            height: account.isPrimary ? 30.298294067382812 : 28.480112075805664,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: account.isPrimary
                    ? onDisconnect
                    : isConnected
                    ? onDisconnect
                    : onConnect,
                child: Ink(
                  decoration: BoxDecoration(
                    color: buttonColor,
                    border: account.isPrimary
                        ? Border.all(
                            color: ConnectedSocialAccountsScreen.border,
                            width: .909,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      buttonLabel,
                      style: TextStyle(
                        color: buttonTextColor,
                        fontFamily: ConnectedSocialAccountsScreen.fontFamily,
                        fontFamilyFallback:
                            ConnectedSocialAccountsScreen.fontFallback,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialBadge extends StatelessWidget {
  const _SocialBadge({required this.account});

  final SocialAccount account;

  @override
  Widget build(BuildContext context) {
    final background = switch (account.id) {
      'kakao' => const Color(0xFFFEE500),
      'apple' => ConnectedSocialAccountsScreen.ink,
      'naver' => const Color(0xFF03C75A),
      'google' => Colors.white,
      _ => Colors.white,
    };
    final textColor = switch (account.id) {
      'kakao' => const Color(0xFF191600),
      'apple' => Colors.white,
      'naver' => Colors.white,
      'google' => ConnectedSocialAccountsScreen.ink,
      _ => ConnectedSocialAccountsScreen.ink,
    };
    final letter = switch (account.id) {
      'kakao' => 'K',
      'apple' => '',
      'naver' => 'N',
      'google' => 'G',
      _ => account.name.characters.first,
    };

    return Container(
      width: 45.99431610107422,
      height: 45.99431610107422,
      decoration: BoxDecoration(
        color: background,
        border: account.id == 'google'
            ? Border.all(
                color: ConnectedSocialAccountsScreen.border,
                width: .909,
              )
            : null,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: account.id == 'apple'
          ? const Icon(Icons.apple_rounded, color: Colors.white, size: 24)
          : Text(
              letter,
              style: TextStyle(
                color: textColor,
                fontFamily: ConnectedSocialAccountsScreen.fontFamily,
                fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.159088134765625,
      height: 15.497159004211426,
      decoration: BoxDecoration(
        color: ConnectedSocialAccountsScreen.blue,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text('주 계정', style: _primaryBadgeText),
    );
  }
}

class _PrimaryChangeCard extends StatelessWidget {
  const _PrimaryChangeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.903, 16.903, 16.904, 16.903),
            child: Row(
              children: [
                const _CircleIcon(
                  size: 35.99431610107422,
                  background: Color(0xFFF1F5F9),
                  icon: Icons.person_outline_rounded,
                  iconColor: ConnectedSocialAccountsScreen.ink,
                  iconSize: 15,
                ),
                const SizedBox(width: 11.989),
                Expanded(
                  child: SizedBox(
                    height: 36.974430084228516,
                    child: Stack(
                      children: const [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Text('주 계정 변경', style: _cardTitleText),
                        ),
                        Positioned(
                          left: 0,
                          top: 20.48291015625,
                          child: Text(
                            '알림 수신 · 비밀번호 재설정에 사용',
                            style: _cardSubtitleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: ConnectedSocialAccountsScreen.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox();

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
              color: ConnectedSocialAccountsScreen.muted,
            ),
          ),
          Positioned(
            left: 32.98291015625,
            top: 11.98828125,
            width: 290.4829406738281,
            child: RichText(
              text: const TextSpan(
                style: _noticeText,
                children: [
                  TextSpan(
                    text: '주 계정은 해제할 수 없습니다.',
                    style: TextStyle(
                      color: ConnectedSocialAccountsScreen.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: ' 다른 계정을 주 계정으로 변경한 뒤 해제해주세요.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryOption extends StatelessWidget {
  const _PrimaryOption({required this.account, required this.onTap});

  final SocialAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SocialBadge(account: account),
      title: Text(account.name, style: _cardTitleText),
      subtitle: Text(account.email, style: _cardSubtitleText),
      trailing: account.isPrimary
          ? const Icon(
              Icons.check_circle_rounded,
              color: ConnectedSocialAccountsScreen.blue,
            )
          : null,
      onTap: onTap,
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

class _RoundedCard extends StatelessWidget {
  const _RoundedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: ConnectedSocialAccountsScreen.border,
          width: .909,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
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
  color: ConnectedSocialAccountsScreen.black,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _introText = TextStyle(
  color: ConnectedSocialAccountsScreen.ink,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _sectionText = TextStyle(
  color: ConnectedSocialAccountsScreen.muted,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: 0,
);

const _accountNameText = TextStyle(
  color: ConnectedSocialAccountsScreen.ink,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _accountSubtitleText = TextStyle(
  color: ConnectedSocialAccountsScreen.muted,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _primaryBadgeText = TextStyle(
  color: Colors.white,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 9,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _cardTitleText = TextStyle(
  color: ConnectedSocialAccountsScreen.ink,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _cardSubtitleText = TextStyle(
  color: ConnectedSocialAccountsScreen.muted,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _noticeText = TextStyle(
  color: ConnectedSocialAccountsScreen.muted,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _sheetTitleText = TextStyle(
  color: ConnectedSocialAccountsScreen.ink,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _sheetBodyText = TextStyle(
  color: ConnectedSocialAccountsScreen.muted,
  fontFamily: ConnectedSocialAccountsScreen.fontFamily,
  fontFamilyFallback: ConnectedSocialAccountsScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

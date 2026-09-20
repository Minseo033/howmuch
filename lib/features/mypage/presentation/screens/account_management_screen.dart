import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/device_permission_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});

  static const blue = AppColors.primary;
  static const green = AppColors.success;
  static const red = AppColors.error;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const fontFamily = 'Noto Sans KR';
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
    final location = ref.watch(locationAccessProvider);
    final email =
        usableAccountEmail(profile.email) ??
        usableAccountEmail(auth.email) ??
        '이메일 정보 없음';
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;
    final provider = auth.provider.trim().isEmpty ? '로그인 정보 없음' : auth.provider;
    final scrollContentHeight = 672 + topOffset;
    final canPop = Navigator.of(context).canPop();

    void goBack() {
      if (canPop) {
        context.pop();
      } else {
        context.go(AppRoutes.mypage);
      }
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.mypage);
      },
      child: FigmaMobileCanvas(
        backgroundColor: surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            width: double.infinity,
            height: scrollContentHeight,
            child: Stack(
              children: [
                _Header(topOffset: topOffset, title: '계정 관리', onBack: goBack),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 64.8720703125 + topOffset,
                  height: 89.80113220214844,
                  child: _ProfileAccountCard(
                    profile: profile,
                    email: email,
                    onEdit: () => context.push(AppRoutes.profileEdit),
                  ),
                ),
                Positioned(
                  left: 23.9915771484375,
                  top: 170.66748046875 + topOffset,
                  child: const _SectionLabel('계정'),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 195.15625 + topOffset,
                  height: 146.22158813476562,
                  child: _AccountInfoCard(
                    profile: profile,
                    provider: provider,
                    locationAccess: location.valueOrNull,
                    onSocialAccounts: () =>
                        context.push(AppRoutes.connectedSocialAccounts),
                    onLocationTap: () async {
                      final service = ref.read(devicePermissionServiceProvider);
                      final access =
                          location.valueOrNull ?? DeviceAccess.unknown;
                      if (access == DeviceAccess.denied) {
                        await service.requestLocation();
                      } else if (access != DeviceAccess.allowed) {
                        await service.openSettings(
                          locationService: access == DeviceAccess.serviceOff,
                        );
                      }
                      if (!context.mounted) return;
                      ref.invalidate(locationAccessProvider);
                    },
                  ),
                ),
                Positioned(
                  left: 23.9915771484375,
                  top: 357.3720703125 + topOffset,
                  child: const _SectionLabel('약관 및 정책'),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 381.86083984375 + topOffset,
                  height: 97.75567626953125,
                  child: const _PolicyCard(),
                ),
                Positioned(
                  left: 23.9915771484375,
                  top: 495.61083984375 + topOffset,
                  child: const _SectionLabel('계정 관리'),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 520.09912109375 + topOffset,
                  height: 115.3125,
                  child: _AccountActionCard(
                    onLogout: () async {
                      await ref.read(kakaoLoginServiceProvider).logout();
                      if (!context.mounted) return;
                      context.go(AppRoutes.login);
                    },
                    onWithdrawal: () => context.push(AppRoutes.withdrawal),
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
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(
              color: AccountManagementScreen.border,
              width: .909,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 3.97705078125 + topOffset,
              width: 44,
              height: 44,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onBack,
                  child: const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 22,
                      color: AccountManagementScreen.ink,
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
                    color: AccountManagementScreen.black,
                    fontFamily: AccountManagementScreen.fontFamily,
                    fontFamilyFallback: AccountManagementScreen.fontFallback,
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

class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({
    required this.profile,
    required this.email,
    required this.onEdit,
  });

  final UserProfile profile;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Stack(
        children: [
          Positioned(
            left: 16.9034423828125,
            top: 16.9033203125,
            child: _Avatar(imageUrl: profile.profileImageUrl),
          ),
          Positioned(
            left: 84.8863525390625,
            top: 22.912109375,
            child: SizedBox(
              width: 179.6732940673828,
              height: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.nickname, style: _bold15),
                  const SizedBox(height: 3.991),
                  Row(
                    children: [
                      const _KakaoMiniBadge(),
                      const SizedBox(width: 3.992),
                      Expanded(
                        child: Text(
                          '· $email',
                          style: _muted11,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16.9034423828125,
            top: 30.6533203125,
            child: _SmallPillButton(label: '편집', onTap: onEdit),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.profile,
    required this.provider,
    required this.locationAccess,
    required this.onSocialAccounts,
    required this.onLocationTap,
  });

  final UserProfile profile;
  final String provider;
  final DeviceAccess? locationAccess;
  final VoidCallback onSocialAccounts;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Column(
        children: [
          _AccountRow(
            icon: Icons.person_outline_rounded,
            title: '닉네임 변경',
            value: profile.nickname,
            showChevron: false,
          ),
          const _CardDivider(),
          _AccountRow(
            icon: Icons.account_circle_outlined,
            title: '로그인 계정',
            value: provider,
            onTap: onSocialAccounts,
          ),
          const _CardDivider(),
          _AccountRow(
            icon: Icons.location_on_outlined,
            title: '위치 정보 사용 관리',
            value: switch (locationAccess) {
              DeviceAccess.allowed => '허용',
              DeviceAccess.blocked => '설정 필요',
              DeviceAccess.serviceOff => '꺼짐',
              null => '확인 중',
              _ => '허용 안 됨',
            },
            valueColor: locationAccess == DeviceAccess.allowed
                ? AccountManagementScreen.green
                : AccountManagementScreen.muted,
            boldValue: true,
            onTap: onLocationTap,
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard();

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Column(
        children: [
          _SimpleRow(
            icon: Icons.privacy_tip_outlined,
            title: '개인정보 처리방침',
            onTap: () => context.push(AppRoutes.privacyPolicy),
          ),
          const _CardDivider(),
          _SimpleRow(
            icon: Icons.article_outlined,
            title: '서비스 이용약관',
            onTap: () => context.push(AppRoutes.termsOfService),
          ),
        ],
      ),
    );
  }
}

class _AccountActionCard extends StatelessWidget {
  const _AccountActionCard({
    required this.onLogout,
    required this.onWithdrawal,
  });

  final VoidCallback onLogout;
  final VoidCallback onWithdrawal;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Column(
        children: [
          SizedBox(
            height: 49,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                hoverColor: AppColors.primaryLight,
                onTap: onLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _RowIcon(icon: Icons.logout_rounded),
                      SizedBox(width: 10),
                      Text('로그아웃', style: _medium13),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const _CardDivider(),
          Expanded(
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                hoverColor: AppColors.errorLight,
                onTap: onWithdrawal,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _DangerIcon(),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('회원 탈퇴', style: _dangerTitle),
                            SizedBox(height: 1),
                            Text('제보·리포트가 모두 삭제돼요', style: _muted105),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AccountManagementScreen.red,
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
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor = AccountManagementScreen.ink,
    this.boldValue = false,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  final bool boldValue;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 47.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.9034423828125),
        child: Row(
          children: [
            _RowIcon(icon: icon),
            const SizedBox(width: 10),
            Text(title, style: _medium13),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontFamily: AccountManagementScreen.fontFamily,
                fontFamilyFallback: AccountManagementScreen.fontFallback,
                fontSize: 12,
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w500,
                height: 1.5,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 7.997),
              const Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: AccountManagementScreen.muted,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        hoverColor: AppColors.primaryLight,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 47.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.9034423828125),
        child: Row(
          children: [
            _RowIcon(icon: icon),
            const SizedBox(width: 10),
            Text(title, style: _medium13),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: AccountManagementScreen.muted,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        hoverColor: AppColors.primaryLight,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: AccountManagementScreen.muted),
    );
  }
}

class _SmallPillButton extends StatelessWidget {
  const _SmallPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42.002838134765625,
        height: 28.480112075805664,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: _semi11),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55.99431610107422,
      height: 55.99431610107422,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl.isEmpty
          ? const Icon(
              Icons.person_rounded,
              color: AccountManagementScreen.blue,
              size: 28,
            )
          : Image.network(
              imageUrl,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: AccountManagementScreen.blue,
                size: 28,
              ),
            ),
    );
  }
}

class _KakaoMiniBadge extends StatelessWidget {
  const _KakaoMiniBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('kakao-provider-badge'),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.kakaoYellow,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: const Text('카카오', style: _kakaoText),
    );
  }
}

class _DangerIcon extends StatelessWidget {
  const _DangerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35.99431610107422,
      height: 35.99431610107422,
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AccountManagementScreen.red,
        size: 15,
      ),
    );
  }
}

class _RoundedPanel extends StatelessWidget {
  const _RoundedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AccountManagementScreen.border, width: .909),
        borderRadius: BorderRadius.circular(22),
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
      width: double.infinity,
      height: 1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ColoredBox(color: AccountManagementScreen.border),
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

const _bold15 = TextStyle(
  color: AccountManagementScreen.black,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _medium13 = TextStyle(
  color: AccountManagementScreen.ink,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _semi11 = TextStyle(
  color: AccountManagementScreen.black,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _muted11 = TextStyle(
  color: AccountManagementScreen.muted,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _muted105 = TextStyle(
  color: AccountManagementScreen.muted,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _sectionText = TextStyle(
  color: AccountManagementScreen.muted,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _dangerTitle = TextStyle(
  color: AccountManagementScreen.red,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _kakaoText = TextStyle(
  color: AppColors.kakaoBrown,
  fontFamily: AccountManagementScreen.fontFamily,
  fontFamilyFallback: AccountManagementScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  height: 1.2,
);

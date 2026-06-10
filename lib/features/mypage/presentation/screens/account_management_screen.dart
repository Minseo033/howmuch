import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
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
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;
    final provider = auth.provider == '이메일' ? '카카오' : auth.provider;
    final scrollContentHeight = 672 + topOffset;

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.mypage);
      }
    }

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: SizedBox(
          width: FigmaMobileCanvas.width,
          height: scrollContentHeight,
          child: Stack(
            children: [
              _Header(topOffset: topOffset, title: '계정 관리', onBack: goBack),
              Positioned(
                left: 20,
                top: 64.8720703125 + topOffset,
                width: 335.45452880859375,
                height: 89.80113220214844,
                child: _ProfileAccountCard(
                  profile: profile,
                  provider: provider,
                  onEdit: () => context.go(AppRoutes.profileEdit),
                ),
              ),
              Positioned(
                left: 23.9915771484375,
                top: 170.66748046875 + topOffset,
                child: const _SectionLabel('계정'),
              ),
              Positioned(
                left: 20,
                top: 195.15625 + topOffset,
                width: 335.45452880859375,
                height: 146.22158813476562,
                child: _AccountInfoCard(
                  profile: profile,
                  provider: provider,
                  onSocialAccounts: () =>
                      context.go(AppRoutes.connectedSocialAccounts),
                ),
              ),
              Positioned(
                left: 23.9915771484375,
                top: 357.3720703125 + topOffset,
                child: const _SectionLabel('약관 및 정책'),
              ),
              Positioned(
                left: 20,
                top: 381.86083984375 + topOffset,
                width: 335.45452880859375,
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
                top: 520.09912109375 + topOffset,
                width: 335.45452880859375,
                height: 49.289772033691406,
                child: _LogoutCard(
                  onTap: () {
                    // TODO(박지환 BE): 실제 로그아웃 API가 붙으면 서버 세션/refresh token을 먼저 폐기하세요.
                    ref.read(authStateProvider.notifier).state = auth.copyWith(
                      isLoggedIn: false,
                    );
                    context.go(AppRoutes.login);
                  },
                ),
              ),
              Positioned(
                left: 20,
                top: 585.38330078125 + topOffset,
                width: 335.45452880859375,
                height: 66.0227279663086,
                child: _WithdrawalCard(
                  onTap: () => context.go(AppRoutes.withdrawal),
                ),
              ),
            ],
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
      width: FigmaMobileCanvas.width,
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
    required this.provider,
    required this.onEdit,
  });

  final UserProfile profile;
  final String provider;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Stack(
        children: [
          const Positioned(
            left: 16.9034423828125,
            top: 16.9033203125,
            child: _Avatar(),
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
                          '$provider · ${profile.email}',
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
    required this.onSocialAccounts,
  });

  final UserProfile profile;
  final String provider;
  final VoidCallback onSocialAccounts;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Column(
        children: [
          _AccountRow(title: '닉네임 변경', value: profile.nickname),
          const _CardDivider(),
          _AccountRow(
            title: '연결된 소셜 계정',
            value: provider,
            onTap: onSocialAccounts,
          ),
          const _CardDivider(),
          const _AccountRow(
            title: '위치 정보 사용 관리',
            value: '허용',
            valueColor: AccountManagementScreen.green,
            boldValue: true,
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
            title: '개인정보 처리방침',
            onTap: () => context.go(AppRoutes.privacyPolicy),
          ),
          const _CardDivider(),
          _SimpleRow(
            title: '서비스 이용약관',
            onTap: () => context.go(AppRoutes.termsOfService),
          ),
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.9034423828125),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 15,
                  color: AccountManagementScreen.ink,
                ),
                SizedBox(width: 7.997),
                Text('로그아웃', style: _medium13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.errorAlpha, width: .909),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: const [
              Positioned(
                left: 16.9034423828125,
                top: 14.900390625,
                child: _DangerIcon(),
              ),
              Positioned(
                left: 64.8863525390625,
                top: 14.900390625,
                child: SizedBox(
                  width: 180,
                  height: 39,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('회원 탈퇴', style: _dangerTitle, maxLines: 1),
                      SizedBox(height: .994),
                      Text(
                        '제보·리포트가 모두 삭제돼요',
                        style: _muted105,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16.9034423828125,
                top: 25.01416015625,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AccountManagementScreen.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.title,
    required this.value,
    this.valueColor = AccountManagementScreen.ink,
    this.boldValue = false,
    this.onTap,
  });

  final String title;
  final String value;
  final Color valueColor;
  final bool boldValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.9034423828125),
        child: Row(
          children: [
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
            const SizedBox(width: 7.997),
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
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 47.471588134765625,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.9034423828125),
        child: Row(
          children: [
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
      child: InkWell(onTap: onTap, child: row),
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
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55.99431610107422,
      height: 55.99431610107422,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text('👑', style: TextStyle(fontSize: 24, height: 1.5)),
    );
  }
}

class _KakaoMiniBadge extends StatelessWidget {
  const _KakaoMiniBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17.798294067382812,
      height: 17.485794067382812,
      decoration: const BoxDecoration(
        color: AppColors.kakaoYellow,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text('K', style: _kakaoText),
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
      decoration: const BoxDecoration(
        color: AppColors.errorLight,
        shape: BoxShape.circle,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AccountManagementScreen.border, width: .909),
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
      height: .9943181276321411,
      child: ColoredBox(color: AccountManagementScreen.border),
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
  fontSize: 9,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

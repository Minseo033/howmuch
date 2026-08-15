import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  static const blue = AppColors.primary;
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
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late bool _nicknamePublic;
  late bool _activityPublic;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }

    final profile = ref.read(userProfileProvider);
    _nicknamePublic = profile.nicknamePublic;
    _activityPublic = profile.activityPublic;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyButton.heightFor(bottomOffset);
    final scrollContentHeight =
        633.6647644042969 + topOffset + footerHeight + 24;

    return FigmaMobileCanvas(
      backgroundColor: ProfileEditScreen.surface,
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
                      left: 145.724365234375,
                      top: 68.8779296875 + topOffset,
                      width: 83.9914779663086,
                      height: 83.9914779663086,
                      child: const _Avatar(),
                    ),
                    Positioned(
                      left: 201.71875,
                      top: 124.8720703125 + topOffset,
                      width: 27.99715805053711,
                      height: 27.99715805053711,
                      child: const _CameraBadge(),
                    ),
                    Positioned(
                      left: 20,
                      top: 176.86083984375 + topOffset,
                      child: const _SectionLabel('기본 정보'),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 201.34912109375 + topOffset,
                      height: 144.65908813476562,
                      child: _BasicInfoCard(
                        nickname: profile.nickname,
                        email: profile.email,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 362.0029296875 + topOffset,
                      child: const _SectionLabel('지역 설정'),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 386.4912109375 + topOffset,
                      height: 74.27556610107422,
                      child: _RegionCard(region: profile.region),
                    ),
                    Positioned(
                      left: 20,
                      top: 476.76123046875 + topOffset,
                      child: const _SectionLabel('공개 설정'),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 501.25 + topOffset,
                      height: 132.41476440429688,
                      child: _PrivacyCard(
                        nicknamePublic: _nicknamePublic,
                        activityPublic: _activityPublic,
                        onNicknameTap: () {
                          setState(() {
                            _nicknamePublic = !_nicknamePublic;
                          });
                        },
                        onActivityTap: () {
                          setState(() {
                            _activityPublic = !_activityPublic;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Header(
            topOffset: topOffset,
            title: '프로필 수정',
            onBack: () => context.go(AppRoutes.mypage),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            right: 0,
            height: footerHeight,
            child: _StickyButton(
              safeBottom: bottomOffset,
              label: '저장하기',
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                // TODO(박지환 BE): 프로필 수정 API가 붙으면 공개 설정과 지역/닉네임 변경값을 서버에 저장하세요.
                ref.read(userProfileProvider.notifier).state = profile.copyWith(
                  nicknamePublic: _nicknamePublic,
                  activityPublic: _activityPublic,
                );
                messenger.clearSnackBars();
                context.go(AppRoutes.mypage);
                messenger.showSnackBar(
                  const SnackBar(content: Text('프로필을 저장했어요.')),
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
            bottom: BorderSide(color: ProfileEditScreen.border, width: .909),
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
                        color: ProfileEditScreen.ink,
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
                    color: ProfileEditScreen.black,
                    fontFamily: ProfileEditScreen.fontFamily,
                    fontFamilyFallback: ProfileEditScreen.fontFallback,
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

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text('👑', style: TextStyle(fontSize: 36, height: 1.5)),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ProfileEditScreen.blue,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.818),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.photo_camera_rounded,
        color: AppColors.white,
        size: 13,
      ),
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({required this.nickname, required this.email});

  final String nickname;
  final String email;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Column(
        children: [
          SizedBox(
            height: 70.3835220336914,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16.9033203125,
                13.99169921875,
                16.9033203125,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('닉네임', style: _captionText),
                  const SizedBox(height: 3.991),
                  Row(
                    children: [
                      Text(nickname, style: _valueText),
                      const Spacer(),
                      const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: ProfileEditScreen.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const _Divider(),
          SizedBox(
            height: 72.45738220214844,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16.9033203125,
                13.9912109375,
                16.9033203125,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이메일', style: _captionText),
                  const SizedBox(height: 4.719),
                  Text(email, style: _normalValueText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final String region;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16.9033203125,
          14.90087890625,
          16.9033203125,
          0,
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('현재 동네', style: _captionText),
                const SizedBox(height: 4.719),
                Text(region, style: _valueText),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: ProfileEditScreen.ink,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.nicknamePublic,
    required this.activityPublic,
    required this.onNicknameTap,
    required this.onActivityTap,
  });

  final bool nicknamePublic;
  final bool activityPublic;
  final VoidCallback onNicknameTap;
  final VoidCallback onActivityTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Column(
        children: [
          _PrivacyRow(
            title: '닉네임 공개',
            subtitle: '제보와 리뷰에 닉네임이 표시돼요',
            value: nicknamePublic,
            onTap: onNicknameTap,
          ),
          const _Divider(),
          _PrivacyRow(
            title: '활동 내역 공개',
            subtitle: '방문·제보 횟수를 다른 사용자에게 공개해요',
            value: activityPublic,
            onTap: onActivityTap,
          ),
        ],
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 64.84375,
        child: Stack(
          children: [
            Positioned(
              left: 16.9033203125,
              top: 13.9912109375,
              child: SizedBox(
                width: 220,
                height: 38,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _privacyTitleText),
                    const SizedBox(height: 1.989),
                    Text(subtitle, style: _privacyCaptionText, maxLines: 1),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16.9033203125,
              top: 13.9912109375,
              child: _Toggle(value: value, onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onTap});

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
                  ? ProfileEditScreen.blue
                  : ProfileEditScreen.disabled,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  left: value ? 18.991455078125 : 2.9970703125,
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

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.safeBottom,
    required this.label,
    required this.onPressed,
  });

  static const buttonHeight = 51.9886360168457;
  static const topGap = 12.89794921875;
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
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: ProfileEditScreen.border, width: .909),
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
                backgroundColor: ProfileEditScreen.blue,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: ProfileEditScreen.fontFamily,
                  fontFamilyFallback: ProfileEditScreen.fontFallback,
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
        color: AppColors.white,
        border: Border.all(color: ProfileEditScreen.border, width: .909),
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 301.647705078125,
      height: .909,
      child: ColoredBox(color: ProfileEditScreen.border),
    );
  }
}

const _sectionText = TextStyle(
  color: ProfileEditScreen.muted,
  fontFamily: ProfileEditScreen.fontFamily,
  fontFamilyFallback: ProfileEditScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _captionText = TextStyle(
  color: ProfileEditScreen.muted,
  fontFamily: ProfileEditScreen.fontFamily,
  fontFamilyFallback: ProfileEditScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _valueText = TextStyle(
  color: ProfileEditScreen.ink,
  fontFamily: ProfileEditScreen.fontFamily,
  fontFamilyFallback: ProfileEditScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _normalValueText = TextStyle(
  color: ProfileEditScreen.ink,
  fontFamily: ProfileEditScreen.fontFamily,
  fontFamilyFallback: ProfileEditScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _privacyTitleText = TextStyle(
  color: ProfileEditScreen.ink,
  fontFamily: ProfileEditScreen.fontFamily,
  fontFamilyFallback: ProfileEditScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _privacyCaptionText = TextStyle(
  color: ProfileEditScreen.muted,
  fontFamily: ProfileEditScreen.fontFamily,
  fontFamilyFallback: ProfileEditScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.4,
);

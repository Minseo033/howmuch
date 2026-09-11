import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';

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
  late String _nickname;
  late String _savedNickname;
  bool _loaded = false;
  bool _identityRefreshStarted = false;
  bool _isSaving = false;
  Future<({String email, String profileImageUrl})>? _identityRefresh;

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await (_identityRefresh ??= ref
        .read(kakaoLoginServiceProvider)
        .refreshKakaoIdentity());
    if (!mounted) return;
    final profile = ref.read(userProfileProvider);
    final auth = ref.read(authStateProvider);
    final saved = await UserProfileApiService().saveProfile(
      nickname: _nickname,
      email:
          usableAccountEmail(profile.email) ??
          usableAccountEmail(auth.email) ??
          '',
      region: profile.region,
      favoriteCategories: profile.favoriteCategories,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 저장에 실패했어요. 다시 시도해주세요.')),
      );
      return;
    }
    ref.read(userProfileProvider.notifier).state = profile.copyWith(
      nickname: _nickname,
    );
    _savedNickname = _nickname;
    setState(() => _isSaving = false);
    if (!context.mounted) return;
    context.go(AppRoutes.mypage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('프로필을 저장했어요.')));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }

    final profile = ref.read(userProfileProvider);
    _nickname = profile.nickname;
    _savedNickname = profile.nickname;
    _loaded = true;
    if (!_identityRefreshStarted) {
      _identityRefreshStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _identityRefresh = ref
            .read(kakaoLoginServiceProvider)
            .refreshKakaoIdentity();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final auth = ref.watch(authStateProvider);
    final displayEmail =
        usableAccountEmail(profile.email) ??
        usableAccountEmail(auth.email) ??
        '카카오 이메일을 확인할 수 없어요';
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final footerHeight = _StickyButton.heightFor(bottomOffset);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: FigmaMobileCanvas(
        backgroundColor: ProfileEditScreen.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  topOffset + 76,
                  20,
                  footerHeight + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: _Avatar(imageUrl: profile.profileImageUrl),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel('기본 정보'),
                    const SizedBox(height: 10),
                    _BasicInfoCard(
                      nickname: _nickname,
                      email: displayEmail,
                      onNicknameTap: _editNickname,
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel('지역 정보'),
                    const SizedBox(height: 10),
                    _RegionCard(region: profile.region),
                    const SizedBox(height: 24),
                    const _SectionLabel('공개 설정'),
                    const SizedBox(height: 10),
                    _PrivacyCard(
                      nicknamePublic: false,
                      activityPublic: false,
                      onNicknameTap: _showUnavailablePrivacySetting,
                      onActivityTap: _showUnavailablePrivacySetting,
                    ),
                  ],
                ),
              ),
            ),
            _Header(topOffset: topOffset, title: '프로필 수정', onBack: _leave),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              height: footerHeight,
              child: _StickyButton(
                safeBottom: bottomOffset,
                label: _isSaving ? '저장 중...' : '저장하기',
                onPressed: _isSaving
                    ? null
                    : () {
                        _saveProfile();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave() async {
    if (_isSaving) return;
    if (_nickname != _savedNickname) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('저장하지 않고 나갈까요?'),
          content: const Text('변경한 닉네임은 아직 저장되지 않았어요.'),
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
    context.canPop() ? context.pop() : context.go(AppRoutes.mypage);
  }

  void _showUnavailablePrivacySetting() {
    if (_isSaving) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('프로필 공개 설정은 현재 제공하지 않아요.')));
  }

  Future<void> _editNickname() async {
    if (_isSaving) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameDialog(initialValue: _nickname),
    );
    if (!mounted || result == null || result == _nickname) return;
    setState(() => _nickname = result);
  }
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '닉네임을 입력해주세요.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return HowmuchDialog(
      title: '닉네임 변경',
      description: '얼마고?에서 사용할 이름을 정해주세요.\n프로필 화면에서 저장하면 반영돼요.',
      confirmLabel: '변경',
      onConfirm: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('profile-nickname-field'),
            controller: _controller,
            autofocus: true,
            cursorColor: AppColors.primary,
            maxLength: 50,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              labelText: '닉네임',
              floatingLabelStyle: const TextStyle(color: AppColors.primary),
              hintText: '어떤 이름으로 불러드릴까요?',
              counterText: '',
              errorText: _errorText,
              filled: true,
              fillColor: AppColors.bgLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (_) => setState(() => _errorText = null),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                '최대 50자까지 입력할 수 있어요.',
                key: ValueKey('profile-nickname-helper'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${_controller.text.characters.length}/50',
                key: const ValueKey('profile-nickname-counter'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
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
  const _Avatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Center(
              child: Icon(
                Icons.person_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            )
          : Image.network(
              imageUrl,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({
    required this.nickname,
    required this.email,
    required this.onNicknameTap,
  });

  final String nickname;
  final String email;
  final VoidCallback onNicknameTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16.9033203125,
                13.99169921875,
                16.9033203125,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('닉네임', style: _captionText),
                  const SizedBox(height: 3.991),
                  InkWell(
                    key: const ValueKey('profile-nickname-edit'),
                    onTap: onNicknameTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nickname,
                              style: _valueText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: ProfileEditScreen.blue,
                            semanticLabel: '닉네임 편집',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _Divider(),
          SizedBox(
            height: 76,
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
                  Text(
                    email,
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _normalValueText,
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

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final String region;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('현재 동네', style: _captionText),
                  const SizedBox(height: 4.719),
                  Text(
                    region.trim().isEmpty ? '등록된 지역이 없어요' : region,
                    style: _valueText,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icon(
              Icons.location_on_outlined,
              color: ProfileEditScreen.muted,
              size: 22,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PrivacyRow(
            title: '닉네임 공개',
            subtitle: '제보와 리뷰에 닉네임이 표시돼요',
            value: nicknamePublic,
            switchKey: const ValueKey('nickname-public-switch'),
            rowKey: const ValueKey('nickname-public-row'),
            onTap: onNicknameTap,
          ),
          const _Divider(),
          _PrivacyRow(
            title: '활동 내역 공개',
            subtitle: '방문·제보 횟수를 다른 사용자에게 공개해요',
            value: activityPublic,
            switchKey: const ValueKey('activity-public-switch'),
            rowKey: const ValueKey('activity-public-row'),
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
    required this.switchKey,
    required this.rowKey,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Key switchKey;
  final Key rowKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        key: rowKey,
        height: 64.84375,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.9033203125),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _privacyTitleText),
                    const SizedBox(height: 1.989),
                    Text(
                      subtitle,
                      style: _privacyCaptionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _Toggle(value: value, switchKey: switchKey, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.switchKey,
    required this.onTap,
  });

  final bool value;
  final Key switchKey;
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
          alignment: Alignment.centerRight,
          child: AnimatedContainer(
            key: switchKey,
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

class _StickyButton extends StatelessWidget {
  const _StickyButton({
    required this.safeBottom,
    required this.label,
    required this.onPressed,
  });

  static const buttonHeight = 51.9886360168457;
  static const topGap = 12.89794921875;
  static const bottomGap = 8.0;
  static const minimumSafeBottom = 12.0;

  final double safeBottom;
  final String label;
  final VoidCallback? onPressed;

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
  fontSize: 13,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/custom_app_bar.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ConnectedSocialAccountsScreen extends ConsumerStatefulWidget {
  const ConnectedSocialAccountsScreen({super.key});

  @override
  ConsumerState<ConnectedSocialAccountsScreen> createState() =>
      _ConnectedSocialAccountsScreenState();
}

class _ConnectedSocialAccountsScreenState
    extends ConsumerState<ConnectedSocialAccountsScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(authStateProvider).isLoggedIn) return;
      ref.read(kakaoLoginServiceProvider).refreshKakaoIdentity();
    });
  }

  Future<void> _requestAccountInfo() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final identity = await ref
        .read(kakaoLoginServiceProvider)
        .refreshKakaoIdentity(requestConsent: true);
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    final missingEmail = usableAccountEmail(identity.email) == null;
    final missingImage = identity.profileImageUrl.isEmpty;
    final message = missingEmail || missingImage
        ? '카카오에서 제공하지 않은 정보는 표시할 수 없어요. 카카오 앱의 동의 항목 설정을 확인해주세요.'
        : '카카오 계정 정보를 불러왔어요.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(userProfileProvider);
    final isLoggedIn = auth.isLoggedIn;
    final provider = auth.provider.trim().isEmpty ? '로그인 정보 없음' : auth.provider;
    final email =
        usableAccountEmail(profile.email) ?? usableAccountEmail(auth.email);
    final accountInfoMissing = email == null || profile.profileImageUrl.isEmpty;

    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const CustomAppBar(title: '로그인 계정'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.kakaoYellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: profile.profileImageUrl.isEmpty
                          ? const Text(
                              'K',
                              style: TextStyle(
                                color: AppColors.kakaoBrown,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : Image.network(
                              profile.profileImageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Text(
                                  'K',
                                  style: TextStyle(
                                    color: AppColors.kakaoBrown,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoggedIn && profile.nickname != '게스트'
                                ? profile.nickname
                                : (isLoggedIn ? '$provider 로그인' : '로그인 정보 없음'),
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLoggedIn
                                ? '$provider · ${email ?? '이메일 정보 없음'}'
                                : '로그인 후 계정 정보를 확인할 수 있어요.',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoggedIn && accountInfoMissing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _requestAccountInfo,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(_isRefreshing ? '불러오는 중...' : '카카오 계정 정보 불러오기'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '현재는 카카오 로그인만 지원합니다.',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

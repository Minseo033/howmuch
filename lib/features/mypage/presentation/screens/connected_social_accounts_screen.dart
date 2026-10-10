import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
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
    // Called straight from the tap: on web the consent window must open before
    // the first await to count as a user-initiated popup.
    final result = await ref
        .read(kakaoLoginServiceProvider)
        .requestKakaoIdentityConsent();
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(HowmuchSnackBar(content: Text(_consentMessage(result))));
  }

  static String _consentMessage(KakaoIdentityConsentResult result) {
    switch (result.outcome) {
      case KakaoConsentOutcome.timedOut:
        return '카카오 동의 창에서 응답이 없어 요청을 마쳤어요. 다시 시도해주세요.';
      case KakaoConsentOutcome.blocked:
        return '브라우저가 카카오 동의 창을 막았어요. 팝업을 허용한 뒤 다시 시도해주세요.';
      case KakaoConsentOutcome.cancelled:
        return '카카오 동의를 취소했어요. 필요할 때 다시 불러올 수 있어요.';
      case KakaoConsentOutcome.failed:
        return '카카오 계정 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
      case KakaoConsentOutcome.notNeeded:
      case KakaoConsentOutcome.granted:
        final missingEmail = usableAccountEmail(result.email) == null;
        final missingImage = result.profileImageUrl.isEmpty;
        return missingEmail || missingImage
            ? '카카오에서 제공하지 않은 정보는 표시할 수 없어요. 카카오 앱의 동의 항목 설정을 확인해주세요.'
            : '카카오 계정 정보를 불러왔어요.';
    }
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
        appBar: CustomAppBar(
          title: '로그인 계정',
          leading: IconButton(
            key: const ValueKey('connected-accounts-back-button'),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.accountManagement);
              }
            },
            // The bare arrow had no name (QA 10/7 #50).
            icon: const Icon(Icons.arrow_back_rounded, semanticLabel: '뒤로가기'),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border, width: .909),
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
                        borderRadius: BorderRadius.circular(14),
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
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.prefer,
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
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _requestAccountInfo,
                    // A white secondary button on the cream page. It keeps
                    // its colors while loading, next to its own spinner.
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.white,
                      disabledForegroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Noto Sans KR',
                        fontFamilyFallback: ['Noto Sans KR'],
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
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
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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

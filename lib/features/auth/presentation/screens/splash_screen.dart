import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/network/backend_warmup_service.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:howmuch/features/system/presentation/screens/service_preparation_screen.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;
  _StartupView _startupView = _StartupView.brand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();

    _timer = Timer(const Duration(milliseconds: 2500), _routeAfterSplash);
  }

  Future<void> _routeAfterSplash() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
    if (!mounted) return;

    if (!onboardingDone) {
      context.go(AppRoutes.onboardingNearby);
      return;
    }

    if (!ApiClient.isAuthenticated) {
      unawaited(ref.read(backendWarmupServiceProvider).ensureReady());
      _markLoggedOut();
      context.go(AppRoutes.login);
      return;
    }

    var readinessResolved = false;
    final preparingTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || readinessResolved) return;
      setState(() => _startupView = _StartupView.preparing);
    });
    final backendReady = await ref
        .read(backendWarmupServiceProvider)
        .ensureReady();
    readinessResolved = true;
    preparingTimer.cancel();
    if (!mounted) return;
    if (!backendReady) {
      setState(() => _startupView = _StartupView.delayed);
      return;
    }

    final kakaoIdentity = await _loadKakaoIdentity(prefs);
    final profileImageUrl = kakaoIdentity.profileImageUrl;
    final kakaoEmail = kakaoIdentity.email;
    if (!mounted) return;

    try {
      final profile = await UserProfileApiService().fetchProfile(strict: true);
      if (!mounted) return;

      if (profile == null) {
        ref
            .read(authStateProvider.notifier)
            .update(
              (state) => state.copyWith(
                isLoggedIn: true,
                provider: '카카오',
                email: kakaoEmail,
                sessionToken: ApiClient.sessionToken ?? '',
                profileImageUrl: profileImageUrl,
              ),
            );
        ref
            .read(userProfileProvider.notifier)
            .update(
              (state) => state.copyWith(
                email: kakaoEmail,
                profileImageUrl: profileImageUrl,
              ),
            );
        context.go(AppRoutes.profileSetup);
        return;
      }

      _applyAuthenticatedProfile(
        profile,
        profileImageUrl: profileImageUrl,
        kakaoEmail: kakaoEmail,
      );
      context.go(AppRoutes.home);
    } on UserProfileAuthException {
      await ApiClient.setSessionToken(null);
      if (!mounted) return;
      _markLoggedOut();
      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('자동 로그인 프로필 확인 실패: $e');
      if (!mounted) return;
      setState(() => _startupView = _StartupView.delayed);
    }
  }

  void _retryConnection() {
    setState(() => _startupView = _StartupView.preparing);
    _routeAfterSplash();
  }

  Future<({String profileImageUrl, String email})> _loadKakaoIdentity(
    SharedPreferences prefs,
  ) async {
    final cachedImageUrl =
        prefs.getString(kakaoProfileImagePreferenceKey)?.trim() ?? '';
    final cachedEmail =
        usableAccountEmail(prefs.getString(kakaoEmailPreferenceKey)) ?? '';
    try {
      final user = await UserApi.instance.me();
      final kakaoProfile = user.kakaoAccount?.profile;
      final currentImageUrl =
          (kakaoProfile?.profileImageUrl ?? kakaoProfile?.thumbnailImageUrl)
              ?.toString()
              .trim() ??
          '';
      final currentEmail =
          usableAccountEmail(user.kakaoAccount?.email) ?? cachedEmail;
      if (currentImageUrl.isNotEmpty) {
        await prefs.setString(kakaoProfileImagePreferenceKey, currentImageUrl);
      }
      if (currentEmail.isNotEmpty) {
        await prefs.setString(kakaoEmailPreferenceKey, currentEmail);
      }
      return (
        profileImageUrl: currentImageUrl.isNotEmpty
            ? currentImageUrl
            : cachedImageUrl,
        email: currentEmail,
      );
    } catch (e) {
      debugPrint('카카오 프로필 정보 갱신 실패: $e');
    }
    return (profileImageUrl: cachedImageUrl, email: cachedEmail);
  }

  void _applyAuthenticatedProfile(
    Map<String, dynamic> profile, {
    required String profileImageUrl,
    required String kakaoEmail,
  }) {
    final rawCategories = profile['favoriteCategories'];
    final categories = rawCategories is List
        ? rawCategories.map((category) => category.toString()).toList()
        : <String>[];
    final email = usableAccountEmail(profile['email']) ?? kakaoEmail;
    final firebaseUid = profile['firebaseUid']?.toString() ?? '';

    ref
        .read(authStateProvider.notifier)
        .update(
          (state) => state.copyWith(
            isLoggedIn: true,
            provider: '카카오',
            email: email,
            firebaseUid: firebaseUid,
            sessionToken: ApiClient.sessionToken ?? '',
            profileImageUrl: profileImageUrl,
          ),
        );
    ref
        .read(userProfileProvider.notifier)
        .update(
          (state) => state.copyWith(
            nickname: profile['nickname']?.toString(),
            email: email.isNotEmpty ? email : state.email,
            region: profile['region']?.toString(),
            favoriteCategories: categories,
            profileImageUrl: profileImageUrl,
          ),
        );
  }

  void _markLoggedOut() {
    ref.read(authStateProvider.notifier).state = const AuthState(
      isLoggedIn: false,
      provider: '',
      email: '',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupView == _StartupView.preparing) {
      return const ServicePreparationScreen.preparing();
    }
    if (_startupView == _StartupView.delayed) {
      return ServicePreparationScreen.delayed(onRetry: _retryConnection);
    }
    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.white, // 바뀐 로고 이미지 배경에 맞춤
        body: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Opacity(
                opacity: _fade.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 30,
                              offset: Offset(0, 15),
                            ),
                          ],
                          image: const DecorationImage(
                            image: AssetImage('assets/images/app_logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '얼마고?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: [
                            'Apple SD Gothic Neo',
                            'Noto Sans KR',
                          ],
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary, // 브랜드 블루
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '동네 가성비 매장 지도',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: [
                            'Apple SD Gothic Neo',
                            'Noto Sans KR',
                          ],
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted, // 슬레이트 색상
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _StartupView { brand, preparing, delayed }

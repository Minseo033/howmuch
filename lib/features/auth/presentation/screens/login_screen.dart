import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
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
    return FigmaMobileCanvas(
      child: SingleChildScrollView(
        child: SizedBox(
          height: FigmaMobileCanvas.height,
          child: Stack(
            children: [
              const Positioned(
                left: 153.7215576171875,
                top: 97.31533813476562,
                width: 67.99715423583984,
                height: 67.99715423583984,
                child: _LoginLogo(),
              ),
              const Positioned(
                left: 105.15625,
                top: 183.13067626953125,
                width: 165.1420440673828,
                height: 45,
                child: Text(
                  '얼마고?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              const Positioned(
                left: 105.15625,
                top: 238.30966186523438,
                width: 165.1420440673828,
                height: 38.977272033691406,
                child: Text(
                  '가까운 착한가격업소를 찾고\n절약을 기록해보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              Positioned(
                left: 27.9971923828125,
                top: 374.616455078125,
                width: 319.460205078125,
                child: Column(
                  children: [
                    _SocialLoginButton(
                      label: '카카오로 계속하기',
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xFF191600),
                      icon: Icons.chat_bubble_rounded,
                      onPressed: () =>
                          _loginWith(ref, context, provider: '카카오'),
                    ),
                    const SizedBox(height: 10),
                    _SocialLoginButton(
                      label: '네이버로 계속하기',
                      backgroundColor: const Color(0xFF03C75A),
                      foregroundColor: Colors.white,
                      textIcon: 'N',
                      onPressed: () =>
                          _loginWith(ref, context, provider: '네이버'),
                    ),
                    const SizedBox(height: 10),
                    _SocialLoginButton(
                      label: 'Apple로 계속하기',
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      icon: Icons.apple_rounded,
                      onPressed: () =>
                          _loginWith(ref, context, provider: 'Apple'),
                    ),
                  ],
                ),
              ),
              const Positioned(
                left: 27.9971923828125,
                top: 566.57666015625,
                width: 319.460205078125,
                height: 16.49147605895996,
                child: _DividerLabel(),
              ),
              Positioned(
                left: 27.9971923828125,
                top: 599.0624389648438,
                width: 319.460205078125,
                height: 50,
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.permissionSetup),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  child: const Text('로그인 없이 둘러보기'),
                ),
              ),
              const Positioned(
                left: 27.9971923828125,
                top: 665.0567626953125,
                width: 319.460205078125,
                height: 56.96022415161133,
                child: _LoginNotice(),
              ),
              const Positioned(
                left: 27.9971923828125,
                top: 737.0112915039062,
                width: 319.460205078125,
                height: 30,
                child: _TermsText(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loginWith(
    WidgetRef ref,
    BuildContext context, {
    required String provider,
  }) {
    // TODO(박지환 BE): 실제 OAuth 로그인 API 응답으로 토큰, 이메일, 관리자 권한을 저장하세요.
    ref.read(authStateProvider.notifier).state = AuthState(
      isLoggedIn: true,
      isAdmin: false,
      provider: provider,
      email: '',
    );
    context.go(AppRoutes.permissionSetup);
  }
}

class _LoginLogo extends StatelessWidget {
  const _LoginLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoginScreen.blue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x592563EB),
            blurRadius: 13.6,
            offset: Offset(0, 10.2),
          ),
        ],
      ),
      child: const Text(
        '얼',
        style: TextStyle(
          color: Colors.white,
          fontFamily: LoginScreen.fontFamily,
          fontFamilyFallback: LoginScreen.fontFallback,
          fontSize: 30.6,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.icon,
    this.textIcon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? textIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 319.460205078125,
      height: 51.9886360168457,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 15.9942626953125,
                width: 21.988636016845703,
                height: 23.99147605895996,
                child: Center(
                  child: textIcon == null
                      ? Icon(icon, color: foregroundColor, size: 18)
                      : Text(
                          textIcon!,
                          style: TextStyle(
                            color: foregroundColor,
                            fontFamily: LoginScreen.fontFamily,
                            fontFamilyFallback: LoginScreen.fontFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontFamily: LoginScreen.fontFamily,
                  fontFamilyFallback: LoginScreen.fontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFE5E7EB), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 11.988636016845703),
          child: Text(
            '또는',
            style: TextStyle(
              color: LoginScreen.muted,
              fontFamily: LoginScreen.fontFamily,
              fontFamilyFallback: LoginScreen.fontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE5E7EB), height: 1)),
      ],
    );
  }
}

class _LoginNotice extends StatelessWidget {
  const _LoginNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: const [
          Positioned(
            left: 11.9886474609375,
            top: 13.977294921875,
            child: Icon(
              Icons.info_outline_rounded,
              color: LoginScreen.blue,
              size: 14,
            ),
          ),
          Positioned(
            left: 33.977294921875,
            top: 11.9886474609375,
            width: 163.28125,
            child: Text(
              '로그인하면 찜한 매장, 제보 내역,\n절약 리포트를 저장할 수 있어요.',
              style: TextStyle(
                color: LoginScreen.blue,
                fontFamily: LoginScreen.fontFamily,
                fontFamilyFallback: LoginScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: const [
          TextSpan(text: '계속하면 '),
          TextSpan(
            text: '서비스 이용약관',
            style: TextStyle(
              color: LoginScreen.ink,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: ' 및\n'),
          TextSpan(
            text: '개인정보 처리방침',
            style: TextStyle(
              color: LoginScreen.ink,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: '에 동의한 것으로 간주됩니다.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: LoginScreen.muted,
        fontFamily: LoginScreen.fontFamily,
        fontFamilyFallback: LoginScreen.fontFallback,
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }
}

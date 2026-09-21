import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
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
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _termsCheckComplete = false;

  @override
  void initState() {
    super.initState();
    _verifyTermsAcceptance();
  }

  Future<void> _verifyTermsAcceptance() async {
    final preferences = await SharedPreferences.getInstance();
    final accepted = preferences.getBool('auth_terms_accepted_v1') == true;
    if (!mounted) return;
    if (!accepted) {
      context.go(AppRoutes.authTerms);
      return;
    }
    setState(() => _termsCheckComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = FigmaMobileCanvas.designSafePaddingOf(context).bottom;

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: !_termsCheckComplete
          ? const Center(
              child: CircularProgressIndicator(color: LoginScreen.blue),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 700;

                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: safeBottom > 0 ? safeBottom / 2 : 20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: isCompact ? 24 : 96),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14203D32),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset('assets/images/app_logo.png'),
                        ),
                        SizedBox(height: isCompact ? 14 : 22),
                        const Text(
                          '얼마고?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LoginScreen.ink,
                            fontFamily: LoginScreen.fontFamily,
                            fontFamilyFallback: LoginScreen.fontFallback,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '가까운 착한가격업소를 찾고 절약을 기록해보세요.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LoginScreen.muted,
                            fontFamily: LoginScreen.fontFamily,
                            fontFamilyFallback: LoginScreen.fontFallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: isCompact ? 20 : 36),
                        Column(
                          children: [
                            _SocialLoginButton(
                              label: '카카오로 계속하기',
                              backgroundColor: const Color(0xFFFEE500),
                              foregroundColor: const Color(0xFF191600),
                              mark: const _KakaoMark(),
                              onPressed: () => _loginWithKakao(context),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 22 : 32),
                        const SizedBox(height: 16.5, child: _DividerLabel()),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton(
                            onPressed: () =>
                                context.go(AppRoutes.permissionSetup),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF4F6FA),
                              foregroundColor: LoginScreen.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: LoginScreen.fontFamily,
                                fontFamilyFallback: LoginScreen.fontFallback,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            child: const Text('로그인 없이 둘러보기'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 56.96, child: _LoginNotice()),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _loginWithKakao(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorMsg = await ref.read(kakaoLoginServiceProvider).login();
    if (errorMsg == null) {
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('카카오로 로그인했어요.')));
      }
    } else {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('로그인 실패: $errorMsg')));
      }
    }
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    required this.mark,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final Widget mark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(left: 18, child: mark),
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
      ),
    );
  }
}

class _KakaoMark extends StatelessWidget {
  const _KakaoMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _KakaoMarkPainter()),
    );
  }
}

class _KakaoMarkPainter extends CustomPainter {
  const _KakaoMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0F172A);
    final bubble = Rect.fromLTWH(1, 2, size.width - 2, size.height * 0.70);
    canvas.drawOval(bubble, paint);
    final tail = Path()
      ..moveTo(size.width * 0.29, size.height * 0.63)
      ..lineTo(size.width * 0.22, size.height * 0.91)
      ..lineTo(size.width * 0.48, size.height * 0.72)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(_KakaoMarkPainter oldDelegate) => false;
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
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '로그인하면 찜한 매장, 제보 내역, 절약 리포트를 저장할 수 있어요.',
              maxLines: 1,
              style: TextStyle(
                color: LoginScreen.blue,
                fontFamily: LoginScreen.fontFamily,
                fontFamilyFallback: LoginScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

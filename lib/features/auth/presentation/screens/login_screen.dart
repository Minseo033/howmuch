import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class LoginScreen extends ConsumerStatefulWidget {
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
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _acceptedTerms = false;

  @override
  Widget build(BuildContext context) {
    final safeBottom = FigmaMobileCanvas.designSafePaddingOf(context).bottom;

    return FigmaMobileCanvas(
      child: LayoutBuilder(
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
                  const SizedBox(width: 68, height: 68, child: _LoginLogo()),
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
                    '가까운 착한가격업소를 찾고\n절약을 기록해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LoginScreen.muted,
                      fontFamily: LoginScreen.fontFamily,
                      fontFamilyFallback: LoginScreen.fontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
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
                      const SizedBox(height: 10),
                      _SocialLoginButton(
                        label: '네이버로 계속하기',
                        backgroundColor: const Color(0xFF03C75A),
                        foregroundColor: Colors.white,
                        mark: const _NaverMark(),
                        statusLabel: '준비 중',
                        onPressed: () => _showComingSoon(context, '네이버'),
                      ),
                      const SizedBox(height: 10),
                      _SocialLoginButton(
                        label: 'Google로 계속하기',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F2937),
                        borderColor: const Color(0xFFD1D5DB),
                        mark: const _GoogleMark(),
                        statusLabel: '준비 중',
                        onPressed: () => _showComingSoon(context, 'Google'),
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
                      onPressed: () => context.go(AppRoutes.permissionSetup),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: LoginScreen.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                  _TermsText(
                    accepted: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loginWithKakao(BuildContext context) async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서비스 이용약관과 개인정보 처리방침에 동의해주세요.')),
      );
      return;
    }
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

  void _showComingSoon(BuildContext context, String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$provider 로그인은 준비 중이에요.')));
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
    required this.mark,
    this.borderColor,
    this.statusLabel,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final Widget mark;
  final Color? borderColor;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = statusLabel == null ? label : '$label, $statusLabel';
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!),
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
                if (statusLabel != null)
                  Positioned(
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: foregroundColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel!,
                        style: TextStyle(
                          color: foregroundColor.withValues(alpha: 0.72),
                          fontFamily: LoginScreen.fontFamily,
                          fontFamilyFallback: LoginScreen.fontFallback,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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
    final paint = Paint()..color = const Color(0xFF191919);
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

class _NaverMark extends StatelessWidget {
  const _NaverMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _NaverMarkPainter()),
    );
  }
}

class _NaverMarkPainter extends CustomPainter {
  const _NaverMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(size.width * 0.39, 2)
      ..lineTo(size.width - 2, size.height - 2)
      ..lineTo(size.width * 0.61, size.height - 2)
      ..lineTo(2, 2)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.width * 0.29, size.height - 4),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.69, 2, size.width * 0.21, size.height - 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_NaverMarkPainter oldDelegate) => false;
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 21,
      height: 21,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final strokeWidth = size.width * 0.22;
    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = strokeWidth,
      );
    }

    arc(const Color(0xFF4285F4), -0.13, 1.72);
    arc(const Color(0xFF34A853), 1.59, 1.12);
    arc(const Color(0xFFFBBC05), 2.71, 0.86);
    arc(const Color(0xFFEA4335), 3.57, 1.52);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.46,
        size.width * 0.43,
        strokeWidth,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
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
  const _TermsText({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: LoginScreen.muted,
      fontFamily: LoginScreen.fontFamily,
      fontFamilyFallback: LoginScreen.fontFallback,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    final linkStyle = TextButton.styleFrom(
      foregroundColor: LoginScreen.ink,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: textStyle.copyWith(decoration: TextDecoration.underline),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: accepted,
          onChanged: (value) => onChanged(value ?? false),
          semanticLabel: '서비스 이용약관과 개인정보 처리방침 동의',
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('계속하면 ', style: textStyle),
              TextButton(
                style: linkStyle,
                onPressed: () => context.push(AppRoutes.termsOfService),
                child: const Text('서비스 이용약관'),
              ),
              const Text(' 및 ', style: textStyle),
              TextButton(
                style: linkStyle,
                onPressed: () => context.push(AppRoutes.privacyPolicy),
                child: const Text('개인정보 처리방침'),
              ),
              const Text('에 동의합니다.', style: textStyle),
            ],
          ),
        ),
      ],
    );
  }
}

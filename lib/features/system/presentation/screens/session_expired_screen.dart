import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
  static const kakao = Color(0xFFFEE500);
  static const kakaoInk = Color(0xFF191600);
  static const green = Color(0xFF10B981);
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
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final actionTop = FigmaMobileCanvas.height - bottomOffset - 16 - 111.988;

    void close() {
      ref.read(authStateProvider.notifier).state = const AuthState(
        isLoggedIn: false,
        isAdmin: false,
        provider: '',
        email: 'minseo@example.com',
      );
      context.go(AppRoutes.home);
    }

    void loginAgain() async {
      final messenger = ScaffoldMessenger.of(context);
      final success = await ref.read(kakaoLoginServiceProvider).login();
      
      if (success) {
        if (context.mounted) {
          context.go(AppRoutes.home);
          messenger.showSnackBar(const SnackBar(content: Text('카카오로 로그인했어요.')));
        }
      } else {
        if (context.mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('로그인에 실패했습니다.')));
        }
      }
    }

    return FigmaMobileCanvas(
      child: SingleChildScrollView(
        child: SizedBox(
          height: FigmaMobileCanvas.height,
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: topOffset + 12,
                width: 31.988636016845703,
                height: 31.988636016845703,
                child: Material(
                  color: surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: close,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF5F708A),
                      size: 16,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 147.72726440429688,
                top: topOffset + 125.67,
                width: 80,
                height: 80,
                child: const _StateIcon(
                  icon: Icons.lock_outline_rounded,
                  size: 36,
                ),
              ),
              Positioned(
                left: 80.69601440429688,
                top: topOffset + 229.66,
                width: 214.0625,
                height: 30,
                child: const Text(
                  '다시 로그인이 필요해요',
                  textAlign: TextAlign.center,
                  style: _titleText,
                ),
              ),
              Positioned(
                left: 88.44461059570312,
                top: topOffset + 267.66,
                width: 198.56533813476562,
                height: 66.26420593261719,
                child: const Text(
                  '보안을 위해 세션이 만료되었어요.\n찜 · 제보 · 절약 리포트는\n로그인 후 이용할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: _bodyText,
                ),
              ),
              Positioned(
                left: 31.9886474609375,
                top: topOffset + 357.91,
                width: 311.4772644042969,
                height: 128.452,
                child: const _AvailableWithoutLoginPanel(),
              ),
              Positioned(
                left: 27.9971923828125,
                top: actionTop,
                width: 319.460205078125,
                child: Column(
                  children: [
                    _KakaoButton(onPressed: loginAgain),
                    const SizedBox(height: 10),
                    _LaterButton(onPressed: close),
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

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: SessionExpiredScreen.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Color(0xFF5F708A), size: size),
    );
  }
}

class _AvailableWithoutLoginPanel extends StatelessWidget {
  const _AvailableWithoutLoginPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SessionExpiredScreen.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Stack(
        children: [
          Positioned(
            left: 15.9942626953125,
            top: 15.9942626953125,
            child: Text('로그인 없이 이용 가능', style: _panelTitleText),
          ),
          Positioned(
            left: 15.9942626953125,
            top: 40.48291015625,
            child: _AvailableRow('주변 매장 지도 탐색'),
          ),
          Positioned(
            left: 15.9942626953125,
            top: 64.47442626953125,
            child: _AvailableRow('매장 상세 정보 조회'),
          ),
          Positioned(
            left: 15.9942626953125,
            top: 88.4659423828125,
            child: _AvailableRow('가격 이력 확인'),
          ),
        ],
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  const _AvailableRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 279.4886169433594,
      height: 17.99715805053711,
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: SessionExpiredScreen.green,
            size: 13,
          ),
          const SizedBox(width: 7.991),
          Text(label, style: _availableRowText),
        ],
      ),
    );
  }
}

class _KakaoButton extends StatelessWidget {
  const _KakaoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 319.460205078125,
      height: 51.9886360168457,
      child: Material(
        color: SessionExpiredScreen.kakao,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 15.9942626953125,
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: SessionExpiredScreen.kakaoInk,
                  size: 18,
                ),
              ),
              Text('카카오로 다시 로그인', style: _kakaoButtonText),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaterButton extends StatelessWidget {
  const _LaterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 319.460205078125,
      height: 50,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: SessionExpiredScreen.surface,
          foregroundColor: SessionExpiredScreen.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: SessionExpiredScreen.fontFamily,
            fontFamilyFallback: SessionExpiredScreen.fontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        child: const Text('나중에 할게요'),
      ),
    );
  }
}

const _titleText = TextStyle(
  color: SessionExpiredScreen.ink,
  fontFamily: SessionExpiredScreen.fontFamily,
  fontFamilyFallback: SessionExpiredScreen.fontFallback,
  fontSize: 20,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _bodyText = TextStyle(
  color: SessionExpiredScreen.muted,
  fontFamily: SessionExpiredScreen.fontFamily,
  fontFamilyFallback: SessionExpiredScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.7,
);

const _panelTitleText = TextStyle(
  color: SessionExpiredScreen.muted,
  fontFamily: SessionExpiredScreen.fontFamily,
  fontFamilyFallback: SessionExpiredScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _availableRowText = TextStyle(
  color: SessionExpiredScreen.ink,
  fontFamily: SessionExpiredScreen.fontFamily,
  fontFamilyFallback: SessionExpiredScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _kakaoButtonText = TextStyle(
  color: SessionExpiredScreen.kakaoInk,
  fontFamily: SessionExpiredScreen.fontFamily,
  fontFamilyFallback: SessionExpiredScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

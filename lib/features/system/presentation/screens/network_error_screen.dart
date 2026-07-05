import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class NetworkErrorScreen extends StatelessWidget {
  const NetworkErrorScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
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
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      child: SingleChildScrollView(
        child: SizedBox(
          height: double.infinity,
          child: Stack(
            children: [
              Positioned(
                left: 147.72726440429688,
                top: topOffset + 189.4,
                width: 80,
                height: 80,
                child: const _StateIcon(icon: Icons.wifi_off_rounded, size: 36),
              ),
              Positioned(
                left: 118.3948974609375,
                top: topOffset + 293.4244384765625,
                width: 138.66500854492188,
                height: 26.988636016845703,
                child: const Text(
                  '연결할 수 없어요',
                  textAlign: TextAlign.center,
                  style: _titleText,
                ),
              ),
              Positioned(
                left: 118.15341186523438,
                top: topOffset + 328.4107666015625,
                width: 139.147705078125,
                height: 44.1761360168457,
                child: const Text(
                  '인터넷 연결을 확인하고\n다시 시도해주세요',
                  textAlign: TextAlign.center,
                  style: _bodyText,
                ),
              ),
              Positioned(
                left: 31.9886474609375,
                top: topOffset + 412,
                width: 311.4772644042969,
                child: Column(
                  children: [
                    _PrimaryButton(
                      label: '다시 시도',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('연결 상태를 다시 확인했어요.')),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _SecondaryButton(
                      label: '오프라인 저장 매장 보기',
                      onPressed: () {
                        // TODO(BE): 오프라인 저장 매장 API/로컬 캐시가 붙으면 해당 목록 화면으로 연결하세요.
                        final messenger = ScaffoldMessenger.of(context);
                        context.go(AppRoutes.home);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('저장된 매장 목록으로 이동했어요.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                bottom: bottomOffset + 32,
                right: 0,
                child: const Text(
                  'Wi-Fi 또는 모바일 데이터를 확인해보세요',
                  textAlign: TextAlign.center,
                  style: _footnoteText,
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
        color: NetworkErrorScreen.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Color(0xFF5F708A), size: size),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 311.4772644042969,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: NetworkErrorScreen.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: NetworkErrorScreen.fontFamily,
            fontFamilyFallback: NetworkErrorScreen.fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 311.4772644042969,
      height: 50,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: NetworkErrorScreen.surface,
          foregroundColor: NetworkErrorScreen.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: NetworkErrorScreen.fontFamily,
            fontFamilyFallback: NetworkErrorScreen.fontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

const _titleText = TextStyle(
  color: NetworkErrorScreen.ink,
  fontFamily: NetworkErrorScreen.fontFamily,
  fontFamilyFallback: NetworkErrorScreen.fontFallback,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _bodyText = TextStyle(
  color: NetworkErrorScreen.muted,
  fontFamily: NetworkErrorScreen.fontFamily,
  fontFamilyFallback: NetworkErrorScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.7,
);

const _footnoteText = TextStyle(
  color: NetworkErrorScreen.muted,
  fontFamily: NetworkErrorScreen.fontFamily,
  fontFamilyFallback: NetworkErrorScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

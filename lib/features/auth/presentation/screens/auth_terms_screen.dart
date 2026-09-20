import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTermsScreen extends StatefulWidget {
  const AuthTermsScreen({super.key});

  @override
  State<AuthTermsScreen> createState() => _AuthTermsScreenState();
}

class _AuthTermsScreenState extends State<AuthTermsScreen> {
  bool _serviceTermsAccepted = false;
  bool _privacyPolicyAccepted = false;
  bool _isSaving = false;

  bool get _allAccepted => _serviceTermsAccepted && _privacyPolicyAccepted;

  void _setAllAccepted(bool accepted) {
    setState(() {
      _serviceTermsAccepted = accepted;
      _privacyPolicyAccepted = accepted;
    });
  }

  Future<void> _continueToLogin() async {
    if (!_allAccepted || _isSaving) return;
    setState(() => _isSaving = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('auth_terms_accepted_v1', true);
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFFCFBF7),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20 + safePadding.top,
              20,
              20 + safePadding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressLabel(),
                SizedBox(height: constraints.maxHeight > 680 ? 90 : 22),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7DFAA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF359A6B),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '서비스 이용 전\n약관을 확인해주세요',
                  style: TextStyle(
                    color: Color(0xFF243E35),
                    fontFamily: 'Noto Sans KR',
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '안전한 서비스 이용을 위해 필수 약관에 동의해 주세요.',
                  style: TextStyle(
                    color: Color(0xFF748078),
                    fontFamily: 'Noto Sans KR',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                _AllTermsTile(value: _allAccepted, onChanged: _setAllAccepted),
                const SizedBox(height: 10),
                _RequiredTermsTile(
                  title: '서비스 이용약관',
                  value: _serviceTermsAccepted,
                  onChanged: (value) =>
                      setState(() => _serviceTermsAccepted = value),
                  onOpen: () => context.push(AppRoutes.termsOfService),
                ),
                const SizedBox(height: 8),
                _RequiredTermsTile(
                  title: '개인정보 처리방침',
                  value: _privacyPolicyAccepted,
                  onChanged: (value) =>
                      setState(() => _privacyPolicyAccepted = value),
                  onOpen: () => context.push(AppRoutes.privacyPolicy),
                ),
                SizedBox(height: constraints.maxHeight > 680 ? 72 : 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _allAccepted ? _continueToLogin : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF359A6B),
                      disabledBackgroundColor: const Color(0xFFD8E7DB),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFFAAB3AA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isSaving ? '확인 중...' : '동의하고 로그인하기',
                      style: const TextStyle(
                        fontFamily: 'Noto Sans KR',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    '필수 약관에 동의해야 서비스를 이용할 수 있어요.',
                    style: TextStyle(
                      color: Color(0xFF748078),
                      fontFamily: 'Noto Sans KR',
                      fontSize: 11,
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

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '얼마고?',
          style: TextStyle(
            color: Color(0xFF359A6B),
            fontFamily: 'Noto Sans KR',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        Text(
          '1 / 3',
          style: TextStyle(
            color: Color(0xFF748078),
            fontFamily: 'Noto Sans KR',
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _AllTermsTile extends StatelessWidget {
  const _AllTermsTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFDDF4E5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: const Color(0xFF359A6B),
              ),
              const SizedBox(width: 4),
              const Text(
                '필수 약관 전체 동의',
                style: TextStyle(
                  color: Color(0xFF243E35),
                  fontFamily: 'Noto Sans KR',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequiredTermsTile extends StatelessWidget {
  const _RequiredTermsTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onOpen,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E7DB)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            activeColor: const Color(0xFF359A6B),
          ),
          Expanded(
            child: Text(
              '[필수] $title',
              style: const TextStyle(
                color: Color(0xFF53645B),
                fontFamily: 'Noto Sans KR',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF748078),
            ),
          ),
        ],
      ),
    );
  }
}

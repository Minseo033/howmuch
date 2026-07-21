import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  // ── 색상 상수
  static const _blue = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _hint = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);
  static const _surface = Color(0xFFF8FAFF);
  static const _chipSelected = Color(0xFF2563EB);
  static const _chipSelectedText = Colors.white;
  static const _chipUnselected = Colors.white;
  static const _chipUnselectedBorder = Color(0xFFCBD5E1);
  static const _chipUnselectedText = Color(0xFF475569);

  // ── 폰트
  static const _font = 'Inter';
  static const _fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'sans-serif',
  ];

  static const String _kakaoRestApiKey = 'a262460cc196a9dd283003c7d54743b3';

  final _nicknameController = TextEditingController();
  final _regionController = TextEditingController();
  final _nicknameFocus = FocusNode();
  final _regionFocus = FocusNode();

  static const int _maxNickname = 12;
  static const List<String> _allCategories = [
    '한식', '중식', '일식', '분식', '카페',
    '패스트푸드', '치킨/피자', '생활서비스',
  ];

  final Set<String> _selectedCategories = {};
  bool _isLoading = false;
  bool _nicknameFocused = false;
  bool _regionFocused = false;

  // 동네 자동완성 관련
  List<String> _regionSuggestions = [];
  Timer? _debounce;
  bool _isSearchingLocation = false;

  // 닉네임 유효성: 2~12자
  bool get _nicknameValid => _nicknameController.text.trim().length >= 2;
  bool get _canSubmit =>
      _nicknameValid &&
      _regionController.text.trim().isNotEmpty &&
      _selectedCategories.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 전체 화면 리빌드 방지를 위해 addListener에서 setState 제거. 
    // 대신 submit 버튼 상태만 업데이트하도록 필요할 때만 리빌드.
    _nicknameController.addListener(_onInputChanged);
    _regionController.addListener(_onRegionInputChanged);

    _nicknameFocus.addListener(() => setState(() {
          _nicknameFocused = _nicknameFocus.hasFocus;
        }));
    _regionFocus.addListener(() => setState(() {
          _regionFocused = _regionFocus.hasFocus;
        }));
  }

  void _onInputChanged() {
    // 폼 유효성 검사 결과가 바뀔 때만 리빌드하여 iOS 한글 입력(보라색 박스) 버그 최소화
    setState(() {});
  }

  void _onRegionInputChanged() {
    final query = _regionController.text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchRegionSuggestions(query);
    });
    setState(() {});
  }

  Future<void> _fetchRegionSuggestions(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _regionSuggestions.clear());
      return;
    }
    try {
      final url = Uri.parse(
          'https://dapi.kakao.com/v2/local/search/address.json?query=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {
        'Authorization': 'KakaoAK $_kakaoRestApiKey',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['documents'] as List;
        if (mounted) {
          setState(() {
            _regionSuggestions =
                docs.map((d) => d['address_name'].toString()).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Address search error: $e");
    }
  }

  Future<void> _setCurrentLocation() async {
    if (_isSearchingLocation) return;
    FocusScope.of(context).unfocus();

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('위치 서비스를 활성화해주세요.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
      return;
    }

    setState(() => _isSearchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final url = Uri.parse(
          'https://dapi.kakao.com/v2/local/geo/coord2regioncode.json?x=${position.longitude}&y=${position.latitude}');
      final response = await http.get(url, headers: {
        'Authorization': 'KakaoAK $_kakaoRestApiKey',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['documents'] != null && data['documents'].isNotEmpty) {
          // 행정동 기준 주소 사용 (H)
          final doc = (data['documents'] as List).firstWhere(
              (d) => d['region_type'] == 'H',
              orElse: () => data['documents'][0]);
          _regionController.text = doc['address_name'];
          setState(() => _regionSuggestions.clear());
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      _showErrorSnackBar('위치를 가져오는데 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nicknameController.dispose();
    _regionController.dispose();
    _nicknameFocus.dispose();
    _regionFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider);
      final email = authState.email;

      final service = UserProfileApiService();
      await service.saveProfile(
        nickname: _nicknameController.text.trim(),
        email: email,
        region: _regionController.text.trim(),
        favoriteCategories: _selectedCategories.toList(),
      );

      ref.read(userProfileProvider.notifier).update(
            (state) => state.copyWith(
              nickname: _nicknameController.text.trim(),
              email: email,
              region: _regionController.text.trim(),
              favoriteCategories: _selectedCategories.toList(),
            ),
          );

      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      _showErrorSnackBar('저장 중 오류가 발생했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return FigmaMobileCanvas(
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepBadge(),
                    const SizedBox(height: 12),
                    _buildTitle(),
                    const SizedBox(height: 8),
                    _buildSubtitle(),
                    const SizedBox(height: 32),
                    _buildNicknameSection(),
                    const SizedBox(height: 24),
                    _buildRegionSection(),
                    const SizedBox(height: 24),
                    _buildCategorySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // 키보드가 열려있지 않을 때만 하단 버튼 표시
            if (!isKeyboardOpen) _buildBottomButton(),
          ],
        ),
      ),
    ),
    );
  }

  // ─── AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: () {
          if (context.canPop()) context.pop();
        },
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: _ink),
        splashRadius: 20,
      ),
      title: const Text(
        '프로필 설정',
        style: TextStyle(
          fontFamily: _font,
          fontFamilyFallback: _fontFallback,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _ink,
          letterSpacing: -0.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  // ─── STEP 뱃지
  Widget _buildStepBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            'STEP 2/2  ·  시작 전 마지막 단계',
            style: TextStyle(
              fontFamily: _font,
              fontFamilyFallback: _fontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _blue,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  // ─── 제목
  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '거의 다 왔어요!',
          style: TextStyle(
            fontFamily: _font,
            fontFamilyFallback: _fontFallback,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '프로필을 완성해 볼까요?',
          style: TextStyle(
            fontFamily: _font,
            fontFamilyFallback: _fontFallback,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ─── 부제목
  Widget _buildSubtitle() {
    return const Text(
      '몇 가지만 알려주시면 내 동네에 맞는\n착한가격업소를 추천해드릴게요.',
      style: TextStyle(
        fontFamily: _font,
        fontFamilyFallback: _fontFallback,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: _muted,
        height: 1.55,
      ),
    );
  }

  // ─── 닉네임 섹션 (ValueListenableBuilder 적용하여 보라색 박스 버그 방지)
  Widget _buildNicknameSection() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nicknameController,
      builder: (context, value, child) {
        final len = value.text.length;
        final isValid = len >= 2;
        final hasText = len > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '닉네임',
                  style: TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                if (hasText)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isValid ? const Color(0xFF10B981) : _hint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isValid ? '사용 가능' : '2자 이상 입력',
                        style: TextStyle(
                          fontFamily: _font,
                          fontFamilyFallback: _fontFallback,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isValid ? const Color(0xFF10B981) : _hint,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _nicknameFocused ? _blue : _border,
                  width: _nicknameFocused ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nicknameController,
                      focusNode: _nicknameFocus,
                      maxLength: _maxNickname,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_regionFocus),
                      style: const TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fontFallback,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        hintText: '닉네임을 입력해 주세요',
                        hintStyle: TextStyle(
                          fontFamily: _font,
                          fontFamilyFallback: _fontFallback,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: _hint,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(
                      '$len/$_maxNickname',
                      style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: len > 0 ? _muted : _hint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '리뷰·제보에 표시되는 활동 이름이에요.',
              style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _hint,
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── 주 활동 동네 섹션
  Widget _buildRegionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '주 활동 동네',
              style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            GestureDetector(
              onTap: _setCurrentLocation,
              child: Row(
                children: [
                  if (_isSearchingLocation)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _blue),
                    )
                  else
                    const Icon(Icons.my_location_rounded,
                        size: 13, color: _blue),
                  const SizedBox(width: 4),
                  const Text(
                    '현재 위치로 설정',
                    style: TextStyle(
                      fontFamily: _font,
                      fontFamilyFallback: _fontFallback,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _regionFocused ? _blue : _border,
              width: _regionFocused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search_rounded, size: 18, color: _hint),
              ),
              Expanded(
                child: TextField(
                  controller: _regionController,
                  focusNode: _regionFocus,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fontFallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: '예: 서울시 마포구',
                    hintStyle: TextStyle(
                      fontFamily: _font,
                      fontFamilyFallback: _fontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _hint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 자동완성 결과 리스트
        if (_regionSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _regionSuggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final address = _regionSuggestions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      address,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fontFallback,
                        fontSize: 14,
                        color: _ink,
                      ),
                    ),
                    onTap: () {
                      _regionController.text = address;
                      setState(() => _regionSuggestions.clear());
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          '이 지역의 가격 변동과 새 매장을 우선 추천해드려요.',
          style: TextStyle(
            fontFamily: _font,
            fontFamilyFallback: _fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _hint,
          ),
        ),
      ],
    );
  }

  // ─── 관심 카테고리 섹션
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Text(
                  '관심 카테고리',
                  style: TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '· 다중 선택 가능',
                  style: TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _hint,
                  ),
                ),
              ],
            ),
            Text(
              '${_selectedCategories.length}/${_allCategories.length} 선택됨',
              style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fontFallback,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _selectedCategories.isEmpty ? _hint : _blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allCategories.map((cat) {
            final selected = _selectedCategories.contains(cat);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedCategories.remove(cat);
                  } else {
                    _selectedCategories.add(cat);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? _chipSelected : _chipUnselected,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: selected ? _chipSelected : _chipUnselectedBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      cat,
                      style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fontFallback,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? _chipSelectedText
                            : _chipUnselectedText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Text(
          '선택한 업종 위주로 오늘의 픽과 절약 리포트가 정리돼요.',
          style: TextStyle(
            fontFamily: _font,
            fontFamilyFallback: _fontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _hint,
          ),
        ),
      ],
    );
  }

  // ─── 하단 버튼
  Widget _buildBottomButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _canSubmit ? 1.0 : 0.45,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _blue,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '가입 완료하고 시작하기',
                            style: TextStyle(
                              fontFamily: _font,
                              fontFamilyFallback: _fontFallback,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '입력 정보는 추천 정확도 향상에만 사용되며\n언제든 마이페이지에서 수정할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              fontFamilyFallback: _fontFallback,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: _hint,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

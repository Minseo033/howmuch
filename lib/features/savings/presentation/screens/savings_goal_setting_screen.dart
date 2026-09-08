import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/features/savings/presentation/state/savings_state.dart';

class SavingsGoalSettingScreen extends StatefulWidget {
  const SavingsGoalSettingScreen({super.key});

  @override
  State<SavingsGoalSettingScreen> createState() =>
      _SavingsGoalSettingScreenState();
}

class _SavingsGoalSettingScreenState extends State<SavingsGoalSettingScreen> {
  late TextEditingController _goalController;
  final SavingsGlobalState _state = SavingsGlobalState();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController();
    // 저장된 목표를 서버에서 불러와 초기값으로 반영
    _loadGoal();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  /// GET /api/savings/goal — 저장된 목표 금액을 입력창에 반영
  Future<void> _loadGoal() async {
    try {
      final responses = await Future.wait([
        ApiClient.get(
          ApiClient.uri('/api/savings/goal'),
          headers: ApiClient.jsonHeaders(auth: true),
        ).timeout(ApiClient.defaultTimeout),
        ApiClient.get(
          ApiClient.uri('/api/savings/stats', {'period': 'this_month'}),
          headers: ApiClient.jsonHeaders(auth: true),
        ).timeout(ApiClient.defaultTimeout),
      ]);
      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw StateError('절약 정보를 불러오지 못했습니다.');
      }
      final goalData =
          jsonDecode(utf8.decode(responses[0].bodyBytes))
              as Map<String, dynamic>;
      final statsData =
          jsonDecode(utf8.decode(responses[1].bodyBytes))
              as Map<String, dynamic>;
      final goal = (goalData['goalAmount'] as num?)?.toInt() ?? 0;
      final saved = (statsData['totalSavedAmount'] as num?)?.toInt() ?? 0;
      final visits = (statsData['totalVisits'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      _goalController.text = goal > 0 ? goal.toString() : '';
      _state.monthlyGoal.value = goal;
      _state.currentSaved.value = saved;
      _state.visitCount.value = visits;
      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('절약 목표 조회 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = '절약 정보를 불러오지 못했어요.';
        });
      }
    }
  }

  Future<void> _saveGoal() async {
    if (_isSaving || _isLoading || _loadError != null) return;
    final newGoal = int.tryParse(_goalController.text.replaceAll(',', ''));
    if (newGoal == null || newGoal <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('목표 금액을 입력해주세요.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final response = await ApiClient.post(
        ApiClient.uri('/api/savings/goal'),
        headers: ApiClient.jsonHeaders(auth: true),
        body: jsonEncode({'goalAmount': newGoal}),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('목표 저장 실패');
      }
      _state.monthlyGoal.value = newGoal;
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('절약 목표 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목표를 저장하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          // Content Scroll
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topOffset + 48.878, // Below header
                bottom: 88.878 + bottomOffset, // Above bottom button
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSizes.itemSpacing),
                  // This Month's Goal Card
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.horizontalPadding,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 0.909,
                        ),
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _goalController,
                        builder: (context, textValue, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '이번 달 절약 목표',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontFamilyFallback: ['Noto Sans KR'],
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 56,
                                child: TextField(
                                  controller: _goalController,
                                  enabled:
                                      !_isLoading &&
                                      !_isSaving &&
                                      _loadError == null,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  cursorColor: const Color(0xFF2563EB),
                                  keyboardType: TextInputType.number,
                                  textAlignVertical: TextAlignVertical.center,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    fontSize: 22,
                                    height: 1.2,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '예: 50000',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    suffixText: '원',
                                    suffixStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF4F6FA),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                        width: 0.909,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.largeSpacing),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: _buildCurrentProgress(),
                  ),
                  const SizedBox(height: AppSizes.largeSpacing),
                  // Info Box
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.horizontalPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF065F46),
                          ),
                          SizedBox(width: AppSizes.smallSpacing),
                          Expanded(
                            child: Text(
                              '목표를 저장하면 절약 리포트에서 이번 달 달성률을 확인할 수 있어요.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF065F46),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Custom AppBar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: topOffset + 48.878,
              padding: EdgeInsets.only(top: topOffset),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 0,
                    child: IconButton(
                      tooltip: '뒤로가기',
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        '절약 목표',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0A0A),
                          fontSize: 16,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Fixed Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSizes.horizontalPadding,
                    right: AppSizes.horizontalPadding,
                    top: 13,
                    bottom: 12,
                  ),
                  child: FilledButton(
                    onPressed: _isSaving || _isLoading || _loadError != null
                        ? null
                        : _saveGoal,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['Noto Sans KR'],
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSaving) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(_isSaving ? '저장 중…' : '목표 저장하기'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentProgress() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return OutlinedButton.icon(
        onPressed: _loadGoal,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(_loadError!),
      );
    }
    final saved = _state.currentSaved.value;
    final goal = _state.monthlyGoal.value;
    final progress = goal > 0 ? (saved / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.909),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.savings_outlined, size: 18, color: Color(0xFF047857)),
              SizedBox(width: AppSizes.smallSpacing),
              Expanded(
                child: Text(
                  '이번 달 실제 기록',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['Noto Sans KR'],
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    height: 19.5 / 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_formatWon(saved)}원',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontFamilyFallback: ['Noto Sans KR'],
                  color: Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${_state.visitCount.value}회 방문',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goal > 0
                ? '현재 목표 ${_formatWon(goal)}원 기준'
                : '목표를 저장하면 달성률을 확인할 수 있어요.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  String _formatWon(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

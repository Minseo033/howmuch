import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/figma_mobile_canvas.dart';
import '../../../../shared/widgets/howmuch_top_bar.dart';

String? formatVisitVerification(String? method, double? distanceMeters) {
  if (method == 'LOCATION' && distanceMeters != null) {
    return '위치 인증 · ${distanceMeters.round()}m';
  }
  if (method == 'RECEIPT_OCR') return '영수증 OCR 인증';
  return null;
}

/// Visits are counted per Korean calendar day by the server, so the list
/// shows the KST date regardless of the device time zone.
String formatVisitDateKst(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) return '최근 방문';
  final parsed = DateTime.tryParse(rawDate);
  if (parsed == null) return rawDate;
  final kst = parsed.toUtc().add(const Duration(hours: 9));
  return '${kst.year.toString().padLeft(4, '0')}.'
      '${kst.month.toString().padLeft(2, '0')}.'
      '${kst.day.toString().padLeft(2, '0')}';
}

/// The server accepts 0원 only for an approved free menu, so a recorded 0 is
/// a free visit; a missing price is unknown.
bool isFreeVisit(Map<dynamic, dynamic> item) {
  if (item['isFree'] == true) return true;
  final price = item['price'];
  return price is num && price == 0;
}

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  /// A pull to refresh keeps what is on screen under its indicator; the
  /// first load and a retry show the spinner instead.
  Future<void> _fetchVisits({bool refreshing = false}) async {
    if (!refreshing) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/visits'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final parsed = data.map((item) {
          final isGov = item['isGov'] == true;
          final isFree = item is Map && isFreeVisit(item);
          final savedAmt = isFree
              ? 0
              : (item['savedAmount'] as num?)?.toInt() ?? 0;
          final priceAmt = (item['price'] as num?)?.toInt() ?? 0;
          final verificationMethod = item['verificationMethod']?.toString();
          final verificationDistance =
              (item['verificationDistanceMeters'] as num?)?.toDouble();
          final visitedAt = item['visitedAt']?.toString();
          final dateStr = formatVisitDateKst(visitedAt);

          return {
            'isGov': isGov,
            'name': item['storeName'] ?? '미등록 매장',
            'menu': item['menu'] ?? '일반 방문',
            'price': isFree
                ? '무료'
                : priceAmt > 0
                ? '${_formatCurrency(priceAmt)}원'
                : '가격 정보 없음',
            'savedAmount': savedAmt,
            'saving': isFree ? '무료 이용' : '${_formatCurrency(savedAmt)}원 절약',
            'date': dateStr,
            'visitedAt': visitedAt,
            'verification': formatVisitVerification(
              verificationMethod,
              verificationDistance,
            ),
          };
        }).toList();

        setState(() {
          _visits = parsed;
          _errorMessage = null;
          _isLoading = false;
        });
      } else {
        _showFetchError(
          response.statusCode == 401
              ? '로그인 후 방문 기록을 확인할 수 있어요.'
              : '잠시 후 다시 시도해 주세요.',
        );
      }
    } catch (e) {
      _showFetchError('네트워크 상태를 확인한 뒤 다시 시도해주세요.');
    }
  }

  void _showFetchError(String message) {
    // The request can fail after the user already left this screen.
    if (!mounted) return;
    setState(() {
      _visits = [];
      _errorMessage = message;
      _isLoading = false;
    });
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  int get _totalSavedAmount {
    return _thisMonthVisits.fold(
      0,
      (sum, item) => sum + ((item['savedAmount'] as int?) ?? 0),
    );
  }

  DateTime? _koreanVisitDate(Map<String, dynamic> visit) {
    final raw = visit['visitedAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc().add(const Duration(hours: 9));
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _thisMonthVisits {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return _visits.where((visit) {
      final visitedAt = _koreanVisitDate(visit);
      return visitedAt != null &&
          visitedAt.year == now.year &&
          visitedAt.month == now.month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    return FigmaMobileCanvas(
      backgroundColor: AppColors.surface,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: CustomAppBar(
          title: '방문 기록',
          // Named by the tooltip alone (QA 10/7 #50, #51).
          leading: IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            tooltip: '뒤로가기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: HowmuchTopBar.iconSize,
            ),
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              // A flat pale-blue disc: no Material shadow, and it stays
              // visible over the white cards it slides across.
              : RefreshIndicator(
                  onRefresh: () => _fetchVisits(refreshing: true),
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  elevation: 0,
                  child: errorMessage != null
                      // Zeros above a failed load would read as no visits.
                      ? _ScrollableMessage(
                          child: _LoadError(
                            message: errorMessage,
                            onRetry: _fetchVisits,
                          ),
                        )
                      : Column(
                          children: [
                            _buildSummary(),
                            Expanded(
                              child: _visits.isEmpty
                                  ? const _ScrollableMessage(
                                      child: _EmptyVisits(),
                                    )
                                  : _buildList(),
                            ),
                          ],
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      // Both cards keep one height when large text wraps a label.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                label: '이번 달 방문',
                value: '${_thisMonthVisits.length}회',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: '이번 달 절약',
                value: '${_formatCurrency(_totalSavedAmount)}원',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _visits.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 10),
      itemBuilder: (context, index) => index == 0
          ? _ListHeader(count: _visits.length)
          : _VisitCard(item: _visits[index - 1]),
    );
  }
}

/// One monthly figure in a white card, like the 내 리뷰 stats.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border, width: .909),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            // A figure stays on one line; '원' never wraps on its own.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list title with every visit counted, like 내 문의's '문의 내역 N건'.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          const Text(
            '방문 내역',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '총 $count회',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final isGov = item['isGov'] as bool;
    final verification = item['verification'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border, width: .909),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGov ? AppColors.primaryLight : AppColors.orangeLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: isGov ? AppColors.primary : AppColors.orangeTheme,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge and date on top and the name on its own line, like
                // the 내 리뷰 cards, so a long name or large text keeps room.
                Row(
                  children: [
                    _VisitBadge(isGov: isGov),
                    const Spacer(),
                    const SizedBox(width: 8),
                    Text(
                      item['date'] as String,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['menu']} · ${item['price']}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (verification != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    verification,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.savings_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        item['saving'] as String,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  final bool isGov;
  const _VisitBadge({required this.isGov});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isGov ? AppColors.primaryLight : AppColors.orangeLight,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        isGov ? '정부인증' : '사용자제보',
        style: TextStyle(
          // The darker orange keeps the small label readable (WCAG AA).
          color: isGov ? AppColors.primary : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.6,
        ),
      ),
    );
  }
}

/// Places a message a little above the middle of the space left while it
/// still scrolls, so pull to refresh works on empty and error states too.
class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Align(alignment: const Alignment(0, -.2), child: child),
        ),
      ),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.where_to_vote_outlined, color: AppColors.muted, size: 48),
        SizedBox(height: 14),
        Text(
          '아직 방문 기록이 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '매장 상세 화면에서 방문 인증을 하면 여기에 모여요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}

/// The app's load error: what failed, why, and a retry.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: .909),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.warning,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '방문 기록을 불러오지 못했어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            // 40 tall like the other error blocks, with a 48px tap area.
            minimumSize: const Size(140, 40),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontFamilyFallback: ['Noto Sans KR'],
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('다시 시도'),
        ),
      ],
    );
  }
}

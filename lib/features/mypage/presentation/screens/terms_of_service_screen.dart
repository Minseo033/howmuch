import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const blue = AppColors.primary;
  static const red = AppColors.error;
  static const amber = AppColors.warningDark;
  static const ink = AppColors.ink;
  static const black = AppColors.black;
  static const muted = AppColors.muted;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
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
    final contentHeight = 1245 + topOffset + bottomOffset;

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SizedBox(
                width: double.infinity,
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 20,
                      top: 64.8720703125 + topOffset,
                      right: 20,
                      height: 200,
                      child: const _TermsSummaryCard(),
                    ),
                    Positioned(
                      left: 23.99169921875,
                      top: 281.7783203125 + topOffset,
                      child: const Text('핵심 조항', style: _sectionText),
                    ),
                    Positioned(
                      left: 20,
                      top: 304.26416015625 + topOffset,
                      right: 20,
                      height: 840.9005126953125,
                      child: _TermsListCard(
                        onOpen: (item) => _showTermsDetail(context, item),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 1157.1533203125 + topOffset,
                      right: 20,
                      height: 41.008522033691406,
                      child: const _TermsNotice(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _TermsHeader(
            topOffset: topOffset,
            onBack: () => _goBack(context),
            onAction: () => _copyDocumentLink(context),
          ),
        ],
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.accountManagement);
    }
  }

  void _copyDocumentLink(BuildContext context) {
    Clipboard.setData(
      const ClipboardData(text: 'https://eolmago.kr/terms/v2.4'),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('서비스 이용약관 링크를 복사했어요.')));
  }

  void _showTermsDetail(BuildContext context, _TermsItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: _sheetTitleText),
                const SizedBox(height: 8),
                Text(item.body, style: _sheetBodyText),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TermsHeader extends StatelessWidget {
  const _TermsHeader({
    required this.topOffset,
    required this.onBack,
    required this.onAction,
  });

  final double topOffset;
  final VoidCallback onBack;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 48.877838134765625 + topOffset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: TermsOfServiceScreen.border, width: .909),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 72,
              height: 48.877838134765625,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: TermsOfServiceScreen.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 11.98876953125 + topOffset,
              child: const IgnorePointer(
                child: Text(
                  '서비스 이용약관',
                  textAlign: TextAlign.center,
                  style: _headerText,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: topOffset + 4,
              width: 44,
              height: 44,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onAction,
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: TermsOfServiceScreen.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSummaryCard extends StatelessWidget {
  const _TermsSummaryCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarySubtle, AppColors.backgroundLight],
        ),
        border: Border.all(color: AppColors.primaryAlpha, width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.903, 16.903, 16.903, 0.909),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: TermsOfServiceScreen.blue,
                ),
                SizedBox(width: 7.997),
                Text('한눈에 보는 약관', style: _blueLabelText),
              ],
            ),
            const SizedBox(height: 7.997),
            Wrap(
              spacing: 7.997,
              runSpacing: 7.997,
              children: const [
                _SummaryMetric(label: '버전', value: 'v2.4'),
                _SummaryMetric(label: '시행일', value: '2026.04.01'),
                _SummaryMetric(label: '최소 이용 연령', value: '만 14세 이상'),
                _SummaryMetric(label: '준거법', value: '대한민국 법령'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146.81817626953125,
      height: 66,
      padding: const EdgeInsets.fromLTRB(12.897, 8.906, 12.897, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: TermsOfServiceScreen.border, width: .909),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _metricLabelText),
          const SizedBox(height: .994),
          Text(value, style: _metricValueText),
        ],
      ),
    );
  }
}

class _TermsListCard extends StatelessWidget {
  const _TermsListCard({required this.onOpen});

  final ValueChanged<_TermsItem> onOpen;

  static const items = [
    _TermsItem(
      number: '2',
      title: '회원 가입 및 자격',
      body: '만 14세 이상이 소셜 로그인으로 가입할 수 있으며, 1인 1계정을 원칙으로 합니다.',
    ),
    _TermsItem(
      number: '3',
      title: '제보·리뷰 게시 책임',
      body: '허위 정보·악의적 가격 정보 등록 시 사전 통보 없이 게시물이 삭제되거나 계정이 제한될 수 있습니다.',
      important: true,
    ),
    _TermsItem(
      number: '4',
      title: '공공데이터 활용',
      body: '행정안전부 착한가격업소 데이터를 활용하며, 원본의 정확성·완전성은 보장하지 않습니다.',
    ),
    _TermsItem(
      number: '5',
      title: '가격 정보 정확성',
      body: '사용자 제보 가격은 실제와 다를 수 있으며, 회사는 이로 인한 손해를 책임지지 않습니다.',
    ),
    _TermsItem(
      number: '6',
      title: '저작권 및 콘텐츠',
      body: '이용자가 게시한 콘텐츠의 저작권은 본인에게 있으나, 서비스 운영을 위해 회사에 사용권을 부여합니다.',
    ),
    _TermsItem(
      number: '7',
      title: '계정 정지 및 이용 제한',
      body: '약관 위반 시 경고 → 일시 정지 → 영구 정지 순으로 조치되며, 사유는 알림으로 통지됩니다.',
      important: true,
    ),
    _TermsItem(
      number: '8',
      title: '서비스 변경·중단',
      body: '기술적 필요에 따라 서비스의 일부 또는 전부가 변경·중단될 수 있으며 30일 전 사전 공지합니다.',
    ),
    _TermsItem(
      number: '9',
      title: '면책 조항',
      body: '천재지변, 공공데이터 오류 등 회사의 통제를 벗어난 사유로 인한 손해는 면책됩니다.',
    ),
    _TermsItem(
      number: '10',
      title: '분쟁 해결',
      body: '서울중앙지방법원을 1심 관할 법원으로 합니다.',
      compact: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.903, 11.988, 16.903, 0),
        child: Column(
          children: [
            const SizedBox(
              height: 67.798,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('제 1조 (목적)', style: _termTitleText),
                  SizedBox(height: 2.998),
                  Text(
                    '본 약관은 얼마고? 서비스 이용에 관한 회사와 회원 간의 권리·의무를 정함을 목적으로 합니다.',
                    style: _termBodyText,
                  ),
                ],
              ),
            ),
            for (final item in items)
              _TermsRow(item: item, onTap: () => onOpen(item)),
          ],
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.item, required this.onTap});

  final _TermsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rowHeight = item.compact
        ? 63.665
        : item.important || item.number == '6'
        ? 97.727
        : 80.696;
    final badgeColor = item.important
        ? AppColors.errorLight
        : AppColors.background;
    final badgeTextColor = item.important
        ? TermsOfServiceScreen.red
        : TermsOfServiceScreen.ink;

    return SizedBox(
      height: rowHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: TermsOfServiceScreen.border, width: .909),
          ),
        ),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(top: 11.988),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 21.988636016845703,
                    height: 21.988636016845703,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.number,
                      style: _termNumberText.copyWith(color: badgeTextColor),
                    ),
                  ),
                  const SizedBox(width: 11.988),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(item.title, style: _termTitleText),
                            ),
                            if (item.important) ...[
                              const SizedBox(width: 5.994),
                              const _ImportantBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2.997),
                        Text(
                          item.body,
                          style: _termBodyText,
                          maxLines: item.compact
                              ? 1
                              : item.important || item.number == '6'
                              ? 3
                              : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 3.991),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: TermsOfServiceScreen.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportantBadge extends StatelessWidget {
  const _ImportantBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28.011362075805664,
      height: 15.497159004211426,
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text('중요', style: _importantText),
    );
  }
}

class _TermsNotice extends StatelessWidget {
  const _TermsNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(width: 11.988),
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: TermsOfServiceScreen.amber,
          ),
          SizedBox(width: 7.997),
          Expanded(
            child: Text(
              '본 약관에 동의하지 않으시면 서비스 이용이 제한됩니다.',
              style: _noticeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 11.988),
        ],
      ),
    );
  }
}

class _TermsItem {
  const _TermsItem({
    required this.number,
    required this.title,
    required this.body,
    this.important = false,
    this.compact = false,
  });

  final String number;
  final String title;
  final String body;
  final bool important;
  final bool compact;
}

class _RoundedPanel extends StatelessWidget {
  const _RoundedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: TermsOfServiceScreen.border, width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

const _headerText = TextStyle(
  color: TermsOfServiceScreen.black,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _blueLabelText = TextStyle(
  color: TermsOfServiceScreen.blue,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  height: 1.5,
  letterSpacing: .3,
);

const _sectionText = TextStyle(
  color: TermsOfServiceScreen.muted,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .3,
);

const _metricLabelText = TextStyle(
  color: TermsOfServiceScreen.muted,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _metricValueText = TextStyle(
  color: TermsOfServiceScreen.ink,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _termTitleText = TextStyle(
  color: TermsOfServiceScreen.ink,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _termBodyText = TextStyle(
  color: TermsOfServiceScreen.muted,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _termNumberText = TextStyle(
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _importantText = TextStyle(
  color: TermsOfServiceScreen.red,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 9,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _noticeText = TextStyle(
  color: TermsOfServiceScreen.amber,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const _sheetTitleText = TextStyle(
  color: TermsOfServiceScreen.ink,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.35,
);

const _sheetBodyText = TextStyle(
  color: TermsOfServiceScreen.muted,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

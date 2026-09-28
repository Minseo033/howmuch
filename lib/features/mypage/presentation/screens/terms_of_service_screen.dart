import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
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
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    return FigmaMobileCanvas(
      backgroundColor: surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                48.877838134765625 + topOffset + 16,
                20,
                24 + bottomOffset,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TermsSummaryCard(),
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.only(left: 3.99),
                    child: Text('핵심 조항', style: _sectionText),
                  ),
                  const SizedBox(height: 10),
                  _TermsListCard(
                    onOpen: (item) => _showTermsDetail(context, item),
                  ),
                  const SizedBox(height: 12),
                  const _TermsNotice(),
                ],
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
      const ClipboardData(text: '얼마고? 서비스 이용약관 — 앱 내 마이페이지에서 확인'),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(HowmuchSnackBar(content: Text('서비스 이용약관 링크를 복사했어요.')));
  }

  void _showTermsDetail(BuildContext context, _TermsItem item) {
    final mediaQuery = MediaQuery.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: math.min(
          FigmaMobileCanvas.maxWebWidth,
          mediaQuery.size.width,
        ),
        maxHeight: math.max(
          0,
          mediaQuery.size.height - mediaQuery.padding.top - 8,
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          key: const ValueKey('terms-detail-bottom-sheet'),
          top: false,
          child: SingleChildScrollView(
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
        key: const ValueKey('terms-of-service-header'),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: TermsOfServiceScreen.border, width: .909),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: topOffset,
              width: 48,
              height: 48.877838134765625,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: AppColors.primaryLight,
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: Alignment.center,
                      child: Icon(
                        key: ValueKey('terms-of-service-back-icon'),
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
              right: 8,
              top: topOffset,
              width: 48,
              height: 48.877838134765625,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: AppColors.primaryLight,
                  onTap: onAction,
                  child: const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      key: ValueKey('terms-of-service-action-icon'),
                      Icons.content_copy_rounded,
                      size: 22,
                      color: TermsOfServiceScreen.ink,
                    ),
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
    return Container(
      key: const ValueKey('terms-summary-card'),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: const Color(0xFFE1E7F0)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TermsOfServiceScreen.ink,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.menu_book_outlined,
                    size: 20,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('한눈에 보는 약관', style: _summaryTitleText),
                      SizedBox(height: 2),
                      Text('이용 전 꼭 확인해 주세요', style: _summaryCaptionText),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_outlined,
                  color: TermsOfServiceScreen.blue,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: const _SummaryMetric(label: '버전', value: 'v2.4'),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: _SummaryMetric(label: '시행일', value: '2026.04.01'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Expanded(
                      child: _SummaryMetric(
                        label: '최소 이용 연령',
                        value: '만 14세 이상',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _SummaryMetric(label: '준거법', value: '대한민국 법령'),
                    ),
                  ],
                ),
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
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: _metricOnPrimaryLabelText),
          const SizedBox(height: 1),
          Text(value, style: _metricOnPrimaryValueText),
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
    return Column(
      children: [
        const _PurposeCard(),
        const SizedBox(height: 12),
        for (var index = 0; index < items.length; index++) ...[
          _TermsRow(item: items[index], onTap: () => onOpen(items[index])),
          if (index < items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PurposeCard extends StatelessWidget {
  const _PurposeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF172554),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('제 1조  ·  목적', style: _purposeEyebrowText),
          SizedBox(height: 8),
          Text('얼마고? 서비스를 위한 약속', style: _purposeTitleText),
          SizedBox(height: 6),
          Text(
            '본 약관은 얼마고? 서비스 이용에 관한 회사와 회원 간의 권리·의무를 정함을 목적으로 합니다.',
            style: _purposeBodyText,
          ),
        ],
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
    return Material(
      color: AppColors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        hoverColor: AppColors.primaryLight,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: item.important
                  ? const Color(0xFFFDD7D7)
                  : const Color(0xFFE5EAF2),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.important
                      ? AppColors.errorLight
                      : AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  item.number,
                  style: _termNumberText.copyWith(
                    color: item.important
                        ? TermsOfServiceScreen.red
                        : TermsOfServiceScreen.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: _termBodyText,
                      maxLines: item.compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: TermsOfServiceScreen.muted,
                ),
              ),
            ],
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
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFED7AA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: TermsOfServiceScreen.amber,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '본 약관에 동의하지 않으시면 서비스 이용이 제한됩니다.',
                style: _noticeText,
                maxLines: 2,
              ),
            ),
          ],
        ),
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

const _headerText = TextStyle(
  color: TermsOfServiceScreen.black,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _summaryTitleText = TextStyle(
  color: TermsOfServiceScreen.ink,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _summaryCaptionText = TextStyle(
  color: TermsOfServiceScreen.muted,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _metricOnPrimaryLabelText = TextStyle(
  color: TermsOfServiceScreen.muted,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _metricOnPrimaryValueText = TextStyle(
  color: TermsOfServiceScreen.ink,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _purposeEyebrowText = TextStyle(
  color: Color(0xFF93C5FD),
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .3,
);

const _purposeTitleText = TextStyle(
  color: AppColors.white,
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 15,
  fontWeight: FontWeight.w800,
  height: 1.4,
);

const _purposeBodyText = TextStyle(
  color: Color(0xFFD8E5FF),
  fontFamily: TermsOfServiceScreen.fontFamily,
  fontFamilyFallback: TermsOfServiceScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.55,
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

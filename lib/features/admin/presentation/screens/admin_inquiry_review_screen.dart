import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/admin/presentation/state/admin_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class AdminInquiryReviewScreen extends ConsumerStatefulWidget {
  const AdminInquiryReviewScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
  static const navy = Color(0xFF0F172A);
  static const ink = Color(0xFF0F172A);
  static const black = Color(0xFF0A0A0A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const surface = Color(0xFFF4F6FA);
  static const border = Color(0xFFE5E7EB);
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
  ConsumerState<AdminInquiryReviewScreen> createState() =>
      _AdminInquiryReviewScreenState();
}

class _AdminInquiryReviewScreenState
    extends ConsumerState<AdminInquiryReviewScreen> {
  final _searchController = TextEditingController();
  _InquiryTab _selectedTab = _InquiryTab.waiting;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;
    final inquiries = ref.watch(adminInquiriesProvider);
    final filtered = _filteredInquiries(inquiries);
    final contentHeight = math.max(
      880.0 + topOffset,
      319.0 + topOffset + (filtered.length * 164.432),
    );

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.mypage);
      }
    }

    return FigmaMobileCanvas(
      backgroundColor: AdminInquiryReviewScreen.surface,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            width: FigmaMobileCanvas.width,
            height: contentHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: FigmaMobileCanvas.width,
                  height: 45.96590805053711 + topOffset,
                  child: _AdminBar(topOffset: topOffset),
                ),
                Positioned(
                  left: 0,
                  top: 45.9658203125 + topOffset,
                  width: FigmaMobileCanvas.width,
                  height: 65.61079406738281,
                  child: _TitleHeader(onBack: goBack),
                ),
                Positioned(
                  left: 20,
                  top: 123.5654296875 + topOffset,
                  width: 335.45452880859375,
                  child: _StatsRow(inquiries: inquiries),
                ),
                Positioned(
                  left: 0,
                  top: 206.2646484375 + topOffset,
                  width: FigmaMobileCanvas.width,
                  height: 43.63636016845703,
                  child: _TabBar(
                    inquiries: inquiries,
                    selectedTab: _selectedTab,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 261.8896484375 + topOffset,
                  width: 335.45452880859375,
                  height: 37.99715805053711,
                  child: _SearchBox(controller: _searchController),
                ),
                Positioned(
                  left: 20,
                  top: 315.8662109375 + topOffset,
                  width: 335.45452880859375,
                  child: Row(
                    children: [
                      Text(
                        '${_selectedTab.title} · ${filtered.length}건',
                        style: _listLabelText,
                      ),
                      const Spacer(),
                      const Text('최신순 ↓', style: _sortText),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  Positioned(
                    left: 20,
                    top: 341.60546875 + topOffset,
                    width: 335.45452880859375,
                    child: const _EmptyInquiryCard(),
                  )
                else
                  ...List.generate(filtered.length, (index) {
                    final inquiry = filtered[index];
                    return Positioned(
                      left: 20,
                      top: 341.60546875 + topOffset + (index * 164.432),
                      width: 335.45452880859375,
                      child: _InquiryCard(
                        inquiry: inquiry,
                        onReply: () => _showReplySheet(inquiry),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AdminInquiry> _filteredInquiries(List<AdminInquiry> inquiries) {
    final keyword = _searchController.text.trim().toLowerCase();
    return inquiries.where((inquiry) {
      final matchesTab = switch (_selectedTab) {
        _InquiryTab.all => true,
        _InquiryTab.waiting => inquiry.status == AdminInquiryStatus.waiting,
        _InquiryTab.inProgress =>
          inquiry.status == AdminInquiryStatus.inProgress,
        _InquiryTab.completed => inquiry.status == AdminInquiryStatus.completed,
      };
      final searchSource =
          '${inquiry.type} ${inquiry.title} ${inquiry.body} ${inquiry.author}'
              .toLowerCase();
      return matchesTab && (keyword.isEmpty || searchSource.contains(keyword));
    }).toList();
  }

  void _showReplySheet(AdminInquiry inquiry) {
    final controller = TextEditingController(
      text: inquiry.answer ?? '문의해주신 내용을 확인했습니다. 현재 검토 결과와 처리 상태를 안내드립니다.',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 22, 24, 24 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inquiry.title, style: _sheetTitleText),
                const SizedBox(height: 8),
                Text(inquiry.body, style: _bodyText),
                const SizedBox(height: 18),
                const Text('답변 내용', style: _sectionText),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  minLines: 4,
                  autofocus: false,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    hintText: '사용자에게 전달할 답변을 입력하세요.',
                    hintStyle: _hintText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AdminInquiryReviewScreen.border,
                        width: .909,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AdminInquiryReviewScreen.blue,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.text =
                              '확인 후 담당 팀에 전달했습니다. 처리 결과는 알림으로 다시 안내드릴게요.';
                        },
                        child: const Text('처리 안내'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.text =
                              '제보 검토 지연으로 불편을 드려 죄송합니다. 오늘 중 우선 검토하겠습니다.';
                        },
                        child: const Text('검토 지연'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('send_admin_inquiry_reply'),
                    onPressed: () {
                      final answer = controller.text.trim();
                      if (answer.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('답변 내용을 입력해주세요.')),
                        );
                        return;
                      }

                      // TODO(BE): 박지환 팀원의 관리자 문의 답변 API로 교체하세요.
                      ref.read(adminInquiriesProvider.notifier).state = [
                        for (final item in ref.read(adminInquiriesProvider))
                          item.id == inquiry.id
                              ? item.copyWith(
                                  status: AdminInquiryStatus.completed,
                                  answer: answer,
                                )
                              : item,
                      ];
                      Navigator.of(context).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('${inquiry.author}님 문의에 답변했어요.'),
                          ),
                        );
                      });
                    },
                    child: const Text('답변 보내기'),
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

enum _InquiryTab {
  all('전체'),
  waiting('대기'),
  inProgress('처리 중'),
  completed('완료');

  const _InquiryTab(this.title);

  final String title;
}

class _AdminBar extends StatelessWidget {
  const _AdminBar({required this.topOffset});

  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AdminInquiryReviewScreen.navy),
      child: Padding(
        padding: EdgeInsets.only(top: topOffset),
        child: Row(
          children: [
            const SizedBox(width: 20),
            const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
            const SizedBox(width: 7.997),
            const Text('얼마고 어드민', style: _adminTitleText),
            const SizedBox(width: 7.997),
            Container(
              height: 18.22443199157715,
              padding: const EdgeInsets.symmetric(horizontal: 5.994),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(child: Text('v2.4', style: _versionText)),
            ),
            const Spacer(),
            Container(
              width: 21.988636016845703,
              height: 21.988636016845703,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5.994),
            const Text('관리자 김', style: _adminUserText),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

class _TitleHeader extends StatelessWidget {
  const _TitleHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AdminInquiryReviewScreen.border,
            width: .909,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: AdminInquiryReviewScreen.ink,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.inbox_outlined,
            size: 18,
            color: AdminInquiryReviewScreen.blue,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('문의 검토', style: _titleText),
                SizedBox(height: .994),
                Text('이번 주 신규 17건 · 평균 응답 4.2시간', style: _subtitleText),
              ],
            ),
          ),
          Container(
            width: 31.988636016845703,
            height: 31.988636016845703,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_alt_outlined,
              size: 17,
              color: AdminInquiryReviewScreen.ink,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.inquiries});

  final List<AdminInquiry> inquiries;

  @override
  Widget build(BuildContext context) {
    final waiting = _displayCount(AdminInquiryStatus.waiting);
    final progress = _displayCount(AdminInquiryStatus.inProgress);
    final completed = _displayCount(AdminInquiryStatus.completed);

    return Row(
      children: [
        _StatCard(
          value: '$waiting',
          label: '대기',
          background: const Color(0xFFFEE2E2),
          foreground: AdminInquiryReviewScreen.red,
        ),
        const SizedBox(width: 7.997),
        _StatCard(
          value: '$progress',
          label: '처리 중',
          background: const Color(0xFFFEF3C7),
          foreground: const Color(0xFF92400E),
        ),
        const SizedBox(width: 7.997),
        _StatCard(
          value: '$completed',
          label: '완료',
          background: const Color(0xFFE8F8F1),
          foreground: AdminInquiryReviewScreen.green,
        ),
      ],
    );
  }

  int _displayCount(AdminInquiryStatus status) {
    const figmaBase = {
      AdminInquiryStatus.waiting: 8,
      AdminInquiryStatus.inProgress: 3,
      AdminInquiryStatus.completed: 142,
    };
    const initialVisible = {
      AdminInquiryStatus.waiting: 2,
      AdminInquiryStatus.inProgress: 1,
      AdminInquiryStatus.completed: 1,
    };
    final current = inquiries
        .where((inquiry) => inquiry.status == status)
        .length;
    return math.max(0, figmaBase[status]! + current - initialVisible[status]!);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String value;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 106.4772720336914,
      height: 70.7102279663086,
      padding: const EdgeInsets.fromLTRB(11.989, 11.989, 11.989, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: _statValueText.copyWith(color: foreground)),
          const Spacer(),
          Text(label, style: _statLabelText.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.inquiries,
    required this.selectedTab,
    required this.onChanged,
  });

  final List<AdminInquiry> inquiries;
  final _InquiryTab selectedTab;
  final ValueChanged<_InquiryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AdminInquiryReviewScreen.border,
            width: .909,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        children: _InquiryTab.values.map((tab) {
          final selected = tab == selectedTab;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(tab),
            child: Container(
              width: tab == _InquiryTab.inProgress ? 88 : 76,
              padding: const EdgeInsets.only(top: 11.989),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Text(
                        tab.title,
                        style: selected ? _selectedTabText : _tabText,
                      ),
                      const SizedBox(width: 3.991),
                      _CountPill(value: _countFor(tab), selected: selected),
                    ],
                  ),
                  if (selected)
                    const Positioned(
                      left: 0,
                      bottom: 0,
                      width: 46.789772033691406,
                      height: 1.9886362552642822,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AdminInquiryReviewScreen.blue,
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _countFor(_InquiryTab tab) {
    const figmaCounts = {
      _InquiryTab.all: 153,
      _InquiryTab.waiting: 8,
      _InquiryTab.inProgress: 3,
      _InquiryTab.completed: 142,
    };
    if (tab == _InquiryTab.all) {
      return figmaCounts[tab]!;
    }
    final status = switch (tab) {
      _InquiryTab.waiting => AdminInquiryStatus.waiting,
      _InquiryTab.inProgress => AdminInquiryStatus.inProgress,
      _InquiryTab.completed => AdminInquiryStatus.completed,
      _InquiryTab.all => AdminInquiryStatus.waiting,
    };
    final current = inquiries
        .where((inquiry) => inquiry.status == status)
        .length;
    const initial = {
      AdminInquiryStatus.waiting: 2,
      AdminInquiryStatus.inProgress: 1,
      AdminInquiryStatus.completed: 1,
    };
    const base = {
      AdminInquiryStatus.waiting: 8,
      AdminInquiryStatus.inProgress: 3,
      AdminInquiryStatus.completed: 142,
    };
    return math.max(0, base[status]! + current - initial[status]!);
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value, required this.selected});

  final int value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16.988636016845703,
      constraints: const BoxConstraints(minWidth: 17.798294067382812),
      padding: const EdgeInsets.symmetric(horizontal: 5.994),
      decoration: BoxDecoration(
        color: selected
            ? AdminInquiryReviewScreen.blue
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          '$value',
          style: _countText.copyWith(
            color: selected ? Colors.white : AdminInquiryReviewScreen.muted,
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminInquiryReviewScreen.border, width: .909),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12.898),
          const Icon(
            Icons.search_rounded,
            size: 16,
            color: AdminInquiryReviewScreen.hint,
          ),
          const SizedBox(width: 7.997),
          Expanded(
            child: TextField(
              controller: controller,
              style: _inputText,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                hintText: '제목·내용·작성자 검색',
                hintStyle: _hintText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.inquiry, required this.onReply});

  final AdminInquiry inquiry;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final colors = _InquiryColors.forType(inquiry.type);
    return Container(
      height: 154.4318084716797,
      padding: const EdgeInsets.fromLTRB(14.9, 14.9, 14.9, 14.9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inquiry.status == AdminInquiryStatus.completed
              ? AdminInquiryReviewScreen.border
              : AdminInquiryReviewScreen.blue.withValues(alpha: .2),
          width: .909,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SmallBadge(
                label: inquiry.type,
                background: colors.typeBg,
                foreground: colors.typeFg,
              ),
              const SizedBox(width: 7.997),
              _StatusPill(status: inquiry.status),
              const Spacer(),
              Text(inquiry.elapsed, style: _timeText),
              if (inquiry.status != AdminInquiryStatus.completed)
                Container(
                  width: 6.988636016845703,
                  height: 6.988636016845703,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: const BoxDecoration(
                    color: AdminInquiryReviewScreen.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              inquiry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cardTitleText,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              inquiry.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyText,
            ),
          ),
          const Spacer(),
          const Divider(color: AdminInquiryReviewScreen.border, height: .909),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 17.99715805053711,
                height: 17.99715805053711,
                decoration: BoxDecoration(
                  color: colors.typeFg.withValues(alpha: .13),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5.994),
              Text(inquiry.author, style: _authorText),
              const Spacer(),
              GestureDetector(
                onTap: onReply,
                child: Row(
                  children: const [
                    Text('답변하기 ', style: _replyText),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AdminInquiryReviewScreen.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18.977272033691406,
      padding: const EdgeInsets.symmetric(horizontal: 5.994),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(label, style: _smallBadgeText.copyWith(color: foreground)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AdminInquiryStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      AdminInquiryStatus.waiting => (
        bg: const Color(0xFFFEE2E2),
        fg: AdminInquiryReviewScreen.red,
      ),
      AdminInquiryStatus.inProgress => (
        bg: const Color(0xFFFEF3C7),
        fg: const Color(0xFF92400E),
      ),
      AdminInquiryStatus.completed => (
        bg: const Color(0xFFE8F8F1),
        fg: AdminInquiryReviewScreen.green,
      ),
    };

    return Container(
      height: 18.977272033691406,
      padding: const EdgeInsets.symmetric(horizontal: 7.997),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
            child: const SizedBox(width: 5, height: 5),
          ),
          const SizedBox(width: 3.991),
          Text(status.label, style: _smallBadgeText.copyWith(color: colors.fg)),
        ],
      ),
    );
  }
}

class _InquiryColors {
  const _InquiryColors({required this.typeBg, required this.typeFg});

  final Color typeBg;
  final Color typeFg;

  static _InquiryColors forType(String type) {
    if (type.contains('제보')) {
      return const _InquiryColors(
        typeBg: Color(0x14F97316),
        typeFg: AdminInquiryReviewScreen.orange,
      );
    }
    if (type.contains('버그')) {
      return const _InquiryColors(
        typeBg: Color(0x14EF4444),
        typeFg: AdminInquiryReviewScreen.red,
      );
    }
    if (type.contains('기능')) {
      return const _InquiryColors(
        typeBg: Color(0x142563EB),
        typeFg: AdminInquiryReviewScreen.blue,
      );
    }
    return const _InquiryColors(
      typeBg: Color(0x1464748B),
      typeFg: AdminInquiryReviewScreen.muted,
    );
  }
}

class _EmptyInquiryCard extends StatelessWidget {
  const _EmptyInquiryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminInquiryReviewScreen.border, width: .909),
      ),
      child: const Text('조건에 맞는 문의가 없어요.', style: _bodyText),
    );
  }
}

const _adminTitleText = TextStyle(
  color: Colors.white,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _versionText = TextStyle(
  color: Colors.white,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 9.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _adminUserText = TextStyle(
  color: Colors.white,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _titleText = TextStyle(
  color: AdminInquiryReviewScreen.ink,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 16,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _subtitleText = TextStyle(
  color: AdminInquiryReviewScreen.muted,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _statValueText = TextStyle(
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 20,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _statLabelText = TextStyle(
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _tabText = TextStyle(
  color: AdminInquiryReviewScreen.muted,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _selectedTabText = TextStyle(
  color: AdminInquiryReviewScreen.blue,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _countText = TextStyle(
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _hintText = TextStyle(
  color: AdminInquiryReviewScreen.hint,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _inputText = TextStyle(
  color: AdminInquiryReviewScreen.ink,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _listLabelText = TextStyle(
  color: AdminInquiryReviewScreen.muted,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .3,
);

const _sortText = TextStyle(
  color: AdminInquiryReviewScreen.blue,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
  letterSpacing: .3,
);

const _smallBadgeText = TextStyle(
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _cardTitleText = TextStyle(
  color: AdminInquiryReviewScreen.ink,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _bodyText = TextStyle(
  color: AdminInquiryReviewScreen.muted,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _timeText = TextStyle(
  color: AdminInquiryReviewScreen.muted,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _authorText = TextStyle(
  color: AdminInquiryReviewScreen.ink,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _replyText = TextStyle(
  color: AdminInquiryReviewScreen.blue,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

const _sheetTitleText = TextStyle(
  color: AdminInquiryReviewScreen.ink,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _sectionText = TextStyle(
  color: AdminInquiryReviewScreen.ink,
  fontFamily: AdminInquiryReviewScreen.fontFamily,
  fontFamilyFallback: AdminInquiryReviewScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  height: 1.5,
);

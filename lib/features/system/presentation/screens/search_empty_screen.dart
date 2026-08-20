import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class SearchEmptyScreen extends StatefulWidget {
  const SearchEmptyScreen({super.key});

  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
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
  State<SearchEmptyScreen> createState() => _SearchEmptyScreenState();
}

class _SearchEmptyScreenState extends State<SearchEmptyScreen> {
  final String _query = '주차요금';
  List<String> _filters = const ['음식점', '1만원 이하', '500m 이내'];

  @override
  Widget build(BuildContext context) {
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;

    return FigmaMobileCanvas(
      backgroundColor: SearchEmptyScreen.surface,
      child: Stack(
        children: [
          _SearchHeader(
            topOffset: topOffset,
            query: _query,
            filters: _filters,
            onClose: () => context.go(AppRoutes.home),
            onRemoveFilter: (filter) {
              setState(() {
                _filters = _filters.where((item) => item != filter).toList();
              });
            },
          ),
          Positioned(
            left: 0,
            top: topOffset + 225.1708984375,
            right: 0,
            bottom: 0,
            child: _EmptyResultBody(
              onSuggestionTap: (suggestion) {
                context.push(
                  AppRoutes.searchResult,
                  extra: {'query': suggestion},
                );
              },
              onResetTap: () {
                setState(() {
                  _filters = const [];
                });
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(const SnackBar(content: Text('필터를 초기화했어요.')));
              },
              onViewAllTap: () => context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.topOffset,
    required this.query,
    required this.filters,
    required this.onClose,
    required this.onRemoveFilter,
  });

  final double topOffset;
  final String query;
  final List<String> filters;
  final VoidCallback onClose;
  final ValueChanged<String> onRemoveFilter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: topOffset + 105.17044830322266,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: SearchEmptyScreen.border, width: .909),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: topOffset + 12),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(child: _SearchInput(query: query)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _CloseButton(onTap: onClose),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 27,
                child: _FilterChips(
                  filters: filters,
                  onRemoveFilter: onRemoveFilter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: SearchEmptyScreen.blue, width: .909),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 15.99432373046875),
          const Icon(
            Icons.search_rounded,
            color: SearchEmptyScreen.blue,
            size: 16,
          ),
          const SizedBox(width: 7.997158050537109),
          Text(query, style: _searchText),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: SearchEmptyScreen.border, width: .909),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.close_rounded,
            color: SearchEmptyScreen.muted,
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filters, required this.onRemoveFilter});

  final List<String> filters;
  final ValueChanged<String> onRemoveFilter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in filters) ...[
            _FilterChip(label: filter, onTap: () => onRemoveFilter(filter)),
            const SizedBox(width: 7.997158050537109),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 26.292612075805664,
          padding: const EdgeInsets.only(left: 10, right: 9),
          decoration: BoxDecoration(
            border: Border.all(color: SearchEmptyScreen.blue, width: .909),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: _filterText),
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                color: SearchEmptyScreen.blue,
                size: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResultBody extends StatelessWidget {
  const _EmptyResultBody({
    required this.onSuggestionTap,
    required this.onResetTap,
    required this.onViewAllTap,
  });

  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onResetTap;
  final VoidCallback onViewAllTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 71.98863220214844,
              height: 71.98863220214844,
              child: _EmptyIcon(),
            ),
            const SizedBox(height: 20),
            const Text(
              '검색 결과가 없어요',
              textAlign: TextAlign.center,
              style: _emptyTitleText,
            ),
            const SizedBox(height: 6),
            const Text(
              '필터를 넓히거나 검색어를 바꿔보세요.\n다른 업종을 찾아볼 수도 있어요.',
              textAlign: TextAlign.center,
              style: _emptyBodyText,
            ),
            const SizedBox(height: 28),
            _Suggestions(onSuggestionTap: onSuggestionTap),
            const SizedBox(height: 24),
            SizedBox(
              width: 311.4772644042969,
              child: Column(
                children: [
                  _ActionButton(
                    label: '필터 초기화하기',
                    primary: true,
                    onTap: onResetTap,
                  ),
                  const SizedBox(height: 7.8),
                  _ActionButton(label: '전체 매장 보기', onTap: onViewAllTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: SearchEmptyScreen.border, width: .909),
      ),
      child: const Icon(
        Icons.search_off_rounded,
        color: Color(0xFF5F708A),
        size: 32,
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    const suggestions = <(String, double)>[
      ('김치찌개', 73.80681610107422),
      ('아메리카노', 85.79544830322266),
      ('커트', 49.8011360168457),
      ('백반', 49.8011360168457),
    ];

    return Column(
      children: [
        const SizedBox(
          height: 16.49147605895996,
          child: Center(child: Text('이런 건 어때요?', style: _suggestionTitle)),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7.997158050537109,
          runSpacing: 8,
          children: [
            for (var index = 0; index < suggestions.length; index++) ...[
              _SuggestionChip(
                label: suggestions[index].$1,
                width: suggestions[index].$2,
                onTap: () => onSuggestionTap(suggestions[index].$1),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.width,
    required this.onTap,
  });

  final String label;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: width,
          height: 31.80397605895996,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: SearchEmptyScreen.border, width: .909),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: _suggestionText),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47.99715805053711,
      child: Material(
        color: primary ? SearchEmptyScreen.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: primary
                  ? null
                  : Border.all(color: SearchEmptyScreen.border, width: .909),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: primary ? _primaryButtonText : _secondaryButtonText,
            ),
          ),
        ),
      ),
    );
  }
}

const _searchText = TextStyle(
  color: SearchEmptyScreen.ink,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

const _filterText = TextStyle(
  color: SearchEmptyScreen.blue,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _emptyTitleText = TextStyle(
  color: SearchEmptyScreen.ink,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _emptyBodyText = TextStyle(
  color: SearchEmptyScreen.muted,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.7,
);

const _suggestionTitle = TextStyle(
  color: SearchEmptyScreen.muted,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _suggestionText = TextStyle(
  color: SearchEmptyScreen.ink,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

const _primaryButtonText = TextStyle(
  color: Colors.white,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _secondaryButtonText = TextStyle(
  color: SearchEmptyScreen.ink,
  fontFamily: SearchEmptyScreen.fontFamily,
  fontFamilyFallback: SearchEmptyScreen.fontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 1.5,
);

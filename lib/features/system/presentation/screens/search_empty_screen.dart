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
  String _query = '주차요금';
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
            height: 377.9261169433594,
            child: _EmptyResultBody(
              onSuggestionTap: (suggestion) {
                // TODO(박지환 BE): 검색 API가 붙으면 추천 검색어로 재조회하고 결과 화면으로 분기하세요.
                setState(() {
                  _query = suggestion;
                });
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text('$suggestion 검색어로 다시 찾아볼게요.')),
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
        child: Stack(
          children: [
            Positioned(
              left: 15.99432373046875,
              top: topOffset + 11.9892578125,
              width: 291.4772644042969,
              height: 43.99147415161133,
              child: _SearchInput(query: query),
            ),
            Positioned(
              left: 315.46881103515625,
              top: topOffset + 11.9892578125,
              width: 43.99147415161133,
              height: 43.99147415161133,
              child: _CloseButton(onTap: onClose),
            ),
            Positioned(
              left: 15.99432373046875,
              top: topOffset + 65.98046875,
              width: 343.4659118652344,
              height: 26.292612075805664,
              child: _FilterChips(
                filters: filters,
                onRemoveFilter: onRemoveFilter,
              ),
            ),
          ],
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
    return Stack(
      children: [
        const Positioned(
          left: 151.73297119140625,
          top: 0,
          width: 71.98863220214844,
          height: 71.98863220214844,
          child: _EmptyIcon(),
        ),
        const Positioned(
          left: 113.75,
          top: 91.98828125,
          width: 147.9545440673828,
          height: 25.49715805053711,
          child: Text(
            '검색 결과가 없어요',
            textAlign: TextAlign.center,
            style: _emptyTitleText,
          ),
        ),
        const Positioned(
          left: 75.44036865234375,
          top: 123.48046875,
          width: 224.5596466064453,
          height: 44.1761360168457,
          child: Text(
            '필터를 넓히거나 검색어를 바꿔보세요.\n다른 업종을 찾아볼 수도 있어요.',
            textAlign: TextAlign.center,
            style: _emptyBodyText,
          ),
        ),
        Positioned(
          left: 46.1221923828125,
          top: 191.6474609375,
          width: 283.1960144042969,
          height: 58.29545211791992,
          child: _Suggestions(onSuggestionTap: onSuggestionTap),
        ),
        Positioned(
          left: 31.9886474609375,
          top: 273.9345703125,
          width: 311.4772644042969,
          height: 103.99147033691406,
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
        Row(
          children: [
            for (var index = 0; index < suggestions.length; index++) ...[
              _SuggestionChip(
                label: suggestions[index].$1,
                width: suggestions[index].$2,
                onTap: () => onSuggestionTap(suggestions[index].$1),
              ),
              if (index != suggestions.length - 1)
                const SizedBox(width: 7.997158050537109),
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
      width: 311.4772644042969,
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

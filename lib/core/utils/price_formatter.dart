/// Prices are values, alternatives, or ranges; stripping every non-digit
/// silently turns `3,000 / 3,500` into 30,003,500 won.
class ParsedPrice {
  const ParsedPrice(this.amounts, {this.isRange = false});
  final List<int> amounts;
  final bool isRange;
  bool get isExact => amounts.length == 1;
  int get minimum => amounts.reduce((a, b) => a < b ? a : b);
  int get maximum => amounts.reduce((a, b) => a > b ? a : b);
}

ParsedPrice? parsePriceValue(Object? value) {
  if (value == null) return null;
  if (value is num) {
    if (!value.isFinite ||
        value < 0 ||
        value > 10000000 ||
        value != value.roundToDouble()) {
      return null;
    }
    return ParsedPrice([value.toInt()]);
  }
  final raw = value.toString().trim();
  if (raw.isEmpty || raw.startsWith('-')) return null;
  final isRange = RegExp(r'[~〜–-]').hasMatch(raw);
  final parts = raw.split(RegExp(r'\s*[/~〜–-]\s*'));
  if (parts.length > 4 || (isRange && parts.length != 2)) return null;
  final amounts = <int>[];
  for (final part in parts) {
    final token = part.trim().replaceFirst(RegExp(r'원$'), '').trim();
    if (!RegExp(r'^(?:\d+|\d{1,3}(?:,\d{3})+)$').hasMatch(token)) {
      return null;
    }
    final amount = int.tryParse(token.replaceAll(',', ''));
    if (amount == null || amount < 0 || amount > 10000000) return null;
    amounts.add(amount);
  }
  if (isRange && amounts.first > amounts.last) return null;
  return ParsedPrice(List.unmodifiable(amounts), isRange: isRange);
}

int? minimumMenuPrice(Object? value, {bool free = false}) {
  final parsed = parsePriceValue(value);
  if (parsed == null ||
      (free && (!parsed.isExact || parsed.minimum != 0)) ||
      (parsed.minimum == 0 && !free)) {
    return null;
  }
  return parsed.minimum;
}

String formatMenuPrice(Object? value, {bool free = false}) {
  final parsed = parsePriceValue(value);
  if (free) {
    return parsed != null && parsed.isExact && parsed.minimum == 0
        ? '무료'
        : '가격 확인 필요';
  }
  if (parsed?.minimum == 0) return '가격 확인 필요';
  return formatWon(value, fallback: '가격 정보 없음');
}

String formatWon(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;

  if (value is num) {
    if (!value.isFinite || value < 0) return fallback;
    return '${_withThousandsSeparator(value.round())}원';
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return fallback;
  final parsed = parsePriceValue(raw);
  if (parsed == null) return raw;
  return '${parsed.amounts.map(_withThousandsSeparator).join(parsed.isRange ? ' ~ ' : ' / ')}원';
}

String formatWonAmount(Object? value, {String fallback = ''}) {
  final formatted = formatWon(value, fallback: fallback);
  return formatted.endsWith('원')
      ? formatted.substring(0, formatted.length - 1)
      : formatted;
}

String _withThousandsSeparator(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

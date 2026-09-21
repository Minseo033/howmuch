String formatWon(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;

  if (value is num) {
    if (!value.isFinite || value < 0) return fallback;
    return '${_withThousandsSeparator(value.round())}원';
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return fallback;
  final normalized = raw
      .replaceAll(',', '')
      .replaceFirst(RegExp(r'원$'), '')
      .trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) return raw;

  final amount = int.tryParse(normalized);
  if (amount == null) return raw;
  return '${_withThousandsSeparator(amount)}원';
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

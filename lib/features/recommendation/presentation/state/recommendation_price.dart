int? parseRecommendationPrice(Object? value) {
  if (value is num) {
    final rounded = value.round();
    return rounded >= 0 ? rounded : null;
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.startsWith('-')) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

String formatRecommendationPrice(
  Object? value, {
  String unavailable = '가격 정보 없음',
}) {
  final price = parseRecommendationPrice(value);
  if (price == null) return unavailable;
  final digits = price.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  buffer.write('원');
  return buffer.toString();
}

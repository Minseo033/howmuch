String formatForecastTime(Object? value) {
  final digits = value?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  if (digits.length < 10) return '';

  final hour = int.tryParse(digits.substring(8, 10));
  if (hour == null || hour < 0 || hour > 23) return '';
  return '$hour시 기준';
}

/// Half-open Korean calendar dates, independent of the device's time zone.
class SavingsPeriod {
  const SavingsPeriod(this.start, this.endExclusive);
  final DateTime start;
  final DateTime endExclusive;

  static DateTime? date(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null || formatDate(parsed) != value) return null;
    return parsed;
  }

  static String formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static SavingsPeriod? fromDates(String? start, String? end) {
    final a = date(start);
    final b = date(end);
    return a != null && b != null && a.isBefore(b) ? SavingsPeriod(a, b) : null;
  }

  factory SavingsPeriod.currentMonth(DateTime now) {
    final kst = now.toUtc().add(const Duration(hours: 9));
    return SavingsPeriod(
      DateTime.utc(kst.year, kst.month),
      DateTime.utc(kst.year, kst.month + 1),
    );
  }

  String get startDate => formatDate(start);
  String get endDateExclusive => formatDate(endExclusive);

  String get title {
    if (start.day == 1 &&
        endExclusive == DateTime.utc(start.year, start.month + 1)) {
      return '${start.year}년 ${start.month}월';
    }
    if (start.month == 1 &&
        start.day == 1 &&
        endExclusive == DateTime.utc(start.year + 1)) {
      return '${start.year}년';
    }
    return '$startDate ~ ${formatDate(endExclusive.subtract(const Duration(days: 1)))}';
  }

  bool contains(DateTime koreanDate) {
    final day = DateTime.utc(koreanDate.year, koreanDate.month, koreanDate.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  static DateTime? koreanDate(String raw) {
    if (raw.contains('T')) {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      // ISO local date-times emitted without an offset already mean KST.
      if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw)) {
        return DateTime.utc(parsed.year, parsed.month, parsed.day);
      }
      final kst = parsed.toUtc().add(const Duration(hours: 9));
      return DateTime.utc(kst.year, kst.month, kst.day);
    }
    return date(raw.trim().replaceAll('.', '-'));
  }
}

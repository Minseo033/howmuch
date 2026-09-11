/// Source-checked prose, not a complete schedule for calculating open/closed status.
class StoreHours {
  final String text;
  final String sourceName;
  final String sourceUrl;
  final String checkedAt;
  final bool parkingYn;
  final bool packingYn;
  final String? areaCurrency;
  final List<String> imageUrls;

  const StoreHours({
    required this.text,
    required this.sourceName,
    required this.sourceUrl,
    required this.checkedAt,
    this.parkingYn = false,
    this.packingYn = false,
    this.areaCurrency,
    this.imageUrls = const [],
  });

  static StoreHours? tryParse(Object? value) {
    if (value is! Map || value['status'] != 'SOURCE_VERIFIED') return null;
    final text = value['text'];
    final name = value['sourceName'];
    final url = value['sourceUrl'];
    final date = value['checkedAt'];
    if (text is! String ||
        text.trim().isEmpty ||
        text.length > 1000 ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        url is! String ||
        date is! String) {
      return null;
    }
    final uri = Uri.tryParse(url);
    final parsedDate = DateTime.tryParse(date);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != date) {
      return null;
    }
    final parking = value['parkingYn'] == true;
    final packing = value['packingYn'] == true;
    final currency =
        value['areaCurrency'] is String &&
            (value['areaCurrency'] as String).trim().isNotEmpty
        ? (value['areaCurrency'] as String).trim()
        : null;

    final rawImgs = value['imageUrls'];
    final imgs = rawImgs is List
        ? rawImgs
              .whereType<String>()
              .where((s) => s.startsWith('https://'))
              .toList()
        : const <String>[];

    return StoreHours(
      text: text.trim(),
      sourceName: name.trim(),
      sourceUrl: url,
      checkedAt: date,
      parkingYn: parking,
      packingYn: packing,
      areaCurrency: currency,
      imageUrls: imgs,
    );
  }

  String get sourceLabel =>
      '$sourceName · ${checkedAt.replaceAll('-', '.')} 자료 조회';

  bool isStale(DateTime now) {
    final koreaNow = now.toUtc().add(const Duration(hours: 9));
    final today = DateTime.utc(koreaNow.year, koreaNow.month, koreaNow.day);
    return today.difference(DateTime.parse('${checkedAt}T00:00:00Z')).inDays >
        90;
  }

  Map<String, dynamic> toJson() => {
    'status': 'SOURCE_VERIFIED',
    'text': text,
    'sourceName': sourceName,
    'sourceUrl': sourceUrl,
    'checkedAt': checkedAt,
    'parkingYn': parkingYn,
    'packingYn': packingYn,
    if (areaCurrency != null) 'areaCurrency': areaCurrency,
    if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
  };
}

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const maxItems = 8;
  static const _storageKey = 'howmuch.recent_searches.v1';

  final Future<SharedPreferences> Function() _preferences;

  Future<List<String>> load() async {
    try {
      final prefs = await _preferences();
      return normalize(prefs.getStringList(_storageKey) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> add(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return load();

    final current = await load();
    final updated = normalize([
      normalizedQuery,
      ...current.where(
        (item) => item.toLowerCase() != normalizedQuery.toLowerCase(),
      ),
    ]);
    await _save(updated);
    return updated;
  }

  Future<List<String>> remove(String query) async {
    final current = await load();
    final updated = current.where((item) => item != query).toList();
    await _save(updated);
    return updated;
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> history) async {
    try {
      final prefs = await _preferences();
      await prefs.setStringList(_storageKey, history);
    } catch (_) {
      // 검색은 저장소 상태와 무관하게 계속 동작해야 한다.
    }
  }

  static List<String> normalize(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final item = value.trim();
      final comparisonKey = item.toLowerCase();
      if (item.isEmpty || item.length > 50 || !seen.add(comparisonKey)) {
        continue;
      }
      normalized.add(item);
      if (normalized.length == maxItems) break;
    }
    return List.unmodifiable(normalized);
  }
}

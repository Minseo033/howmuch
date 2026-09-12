import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const maxItems = 8;
  static const _storageKey = 'howmuch.recent_searches.v1';
  // Screens share the same preference key, so read-modify-write operations
  // must be ordered across instances as well as within one screen.
  static Future<void>? _pending;

  final Future<SharedPreferences> Function() _preferences;

  Future<T> _ordered<T>(Future<T> Function() operation) {
    final result = _pending == null
        ? operation()
        : _pending!.then((_) => operation());
    final pending = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = pending;
    pending.then((_) {
      if (identical(_pending, pending)) _pending = null;
    });
    return result;
  }

  Future<List<String>> load() => _ordered(_load);

  Future<List<String>> _load() async {
    try {
      final prefs = await _preferences();
      return normalize(prefs.getStringList(_storageKey) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> add(String query) => _ordered(() async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return _load();

    final current = await _load();
    final updated = normalize([
      normalizedQuery,
      ...current.where(
        (item) => item.toLowerCase() != normalizedQuery.toLowerCase(),
      ),
    ]);
    await _save(updated);
    return updated;
  });

  Future<List<String>> remove(String query) => _ordered(() async {
    final current = await _load();
    final updated = current.where((item) => item != query).toList();
    await _save(updated);
    return updated;
  });

  Future<void> clear() => _ordered(() => _save(const []));

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

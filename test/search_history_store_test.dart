import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/search/presentation/state/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'recent searches are newest first, unique, and capped at eight',
    () async {
      final store = SearchHistoryStore();

      for (var index = 0; index < 10; index++) {
        await store.add('검색어 $index');
      }
      await store.add('  검색어 5  ');

      expect(await store.load(), [
        '검색어 5',
        '검색어 9',
        '검색어 8',
        '검색어 7',
        '검색어 6',
        '검색어 4',
        '검색어 3',
        '검색어 2',
      ]);
    },
  );

  test('recent searches can be removed or cleared', () async {
    final store = SearchHistoryStore();
    await store.add('한식');
    await store.add('커피');

    expect(await store.remove('한식'), ['커피']);
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test(
    'overlapping searches from different screens retain both entries',
    () async {
      final first = SearchHistoryStore();
      final second = SearchHistoryStore();
      await Future.wait([first.add('한식'), second.add('커피')]);
      expect(await second.load(), ['커피', '한식']);
    },
  );

  test(
    'clear after a pending search cannot resurrect deleted history',
    () async {
      final store = SearchHistoryStore();
      await Future.wait([store.add('한식'), store.clear()]);
      expect(await SearchHistoryStore().load(), isEmpty);
    },
  );
}

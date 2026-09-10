import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Korean font is registered in the startup asset manifest', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final family = manifest.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['family'] == 'Noto Sans KR',
    );
    final fonts = family['fonts'] as List<dynamic>;
    final path = fonts.single['asset'] as String;
    final data = await rootBundle.load(path);

    // Reject a missing font, HTML fallback, or a corrupted download.
    expect(data.getUint32(0), 0x00010000);
    expect(data.lengthInBytes, greaterThan(100000));
    await (FontLoader(
      'Bundled Korean test',
    )..addFont(Future.value(data))).load();
  });

  test(
    'browser and Flutter use the same local font without an external swap',
    () {
      final html = File('web/index.html').readAsStringSync();
      expect(
        html,
        contains('<script src="flutter_bootstrap.js" async></script>'),
      );
      expect(html, contains('assets/assets/fonts/NotoSansKR-Variable.ttf'));
      expect(html, contains('as="fetch" type="font/ttf" crossorigin'));
      expect(html, contains('font-display: block'));
      expect(html, isNot(contains('fonts.googleapis.com')));
      expect(html, isNot(contains('media="print"')));
      expect(html, isNot(contains('setTimeout(resolve')));
      expect(html, contains("window.addEventListener('flutter-first-frame'"));
      expect(
        html,
        contains("document.getElementById('startup-loading')?.remove()"),
      );
    },
  );

  test('all themed buttons retain the bundled Korean font', () {
    final theme = AppTheme.light();
    for (final style in [
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      expect(
        style!.textStyle!.resolve(<WidgetState>{})!.fontFamily,
        'Noto Sans KR',
      );
    }
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Noto Sans KR');
    expect(
      theme.textTheme.labelLarge!.fontFamilyFallback,
      contains('Noto Sans KR'),
    );
  });
}

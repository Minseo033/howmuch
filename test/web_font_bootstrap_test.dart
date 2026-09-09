import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not block Flutter bootstrap on the Korean web font', () {
    final html = File('web/index.html').readAsStringSync();

    expect(
      html,
      contains('<script src="flutter_bootstrap.js" async></script>'),
    );
    expect(html, contains('rel="stylesheet" media="print"'));
    expect(html, contains("onload=\"this.media='all'\""));
    expect(html, isNot(contains('document.fonts.load')));
    expect(html, isNot(contains('setTimeout(resolve')));
  });
}

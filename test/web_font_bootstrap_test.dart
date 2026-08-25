import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the Korean web font before Flutter bootstrap', () {
    final html = File('web/index.html').readAsStringSync();
    final fontLoadIndex = html.indexOf('document.fonts.load');
    final bootstrapIndex = html.indexOf(
      "bootstrap.src = 'flutter_bootstrap.js'",
    );

    expect(fontLoadIndex, greaterThanOrEqualTo(0));
    expect(bootstrapIndex, greaterThan(fontLoadIndex));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/theme/app_colors.dart';

void main() {
  test('keeps the original HowMuch brand palette', () {
    expect(AppColors.primary, const Color(0xFF2563EB));
    expect(AppColors.primaryPressed, const Color(0xFF1D4ED8));
    expect(AppColors.primaryLight, const Color(0xFFEFF4FF));
    expect(AppColors.orangeTheme, const Color(0xFFF27E22));
    expect(AppColors.success, const Color(0xFF047857));
    expect(AppColors.error, const Color(0xFFEF4444));
    expect(AppColors.ink, const Color(0xFF0F172A));
    expect(AppColors.surface, const Color(0xFFF4F6FA));
    expect(AppColors.white, Colors.white);
  });
}

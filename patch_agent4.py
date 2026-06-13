import re

with open("lib/features/community/presentation/screens/report_create_screen.dart", "r") as f:
    code = f.read()

# Add imports
imports = """import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
"""
code = code.replace("import 'package:howmuch/features/community/presentation/state/user_reports_state.dart';", imports)

# Replace _submit function
old_submit = """  void _submit() {
    // TODO(박지환 BE): 제보 등록 API와 이미지 업로드 API가 붙으면 이 로컬 완료 처리를 교체하세요.
    final firstMenu = _menuPrices.first;
    final report = UserReportStatus(
      id: 'report-${DateTime.now().millisecondsSinceEpoch}',
      store: _storeController.text.trim(),
      menu: '${firstMenu.menu.text.trim()} ${firstMenu.price.text.trim()}원',
      status: '검토 중',
      statusColor: 0xFFF59E0B,
      statusBg: 0xFFFEF3C7,
      date: DateTime.now().toIso8601String().split('T').first,
    );
    ref.read(userReportsProvider.notifier).addReport(report);
    
    if (mounted) {
      context.push(AppRoutes.reportComplete);
    }
  }"""

new_submit = """  Future<void> _submit() async {
    if (!_basicInfoComplete || !_priceInfoComplete) {
      _showSnack('필수 정보를 모두 입력해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = ref.read(authStateProvider);

      final menu1 = _menuPrices.isNotEmpty ? _menuPrices[0].menu.text.trim() : '';
      final price1 = _menuPrices.isNotEmpty ? _menuPrices[0].price.text.trim() : '';
      final menu2 = _menuPrices.length > 1 ? _menuPrices[1].menu.text.trim() : '';
      final price2 = _menuPrices.length > 1 ? _menuPrices[1].price.text.trim() : '';
      final menu3 = _menuPrices.length > 2 ? _menuPrices[2].menu.text.trim() : '';
      final price3 = _menuPrices.length > 2 ? _menuPrices[2].price.text.trim() : '';
      final menu4 = _menuPrices.length > 3 ? _menuPrices[3].menu.text.trim() : '';
      final price4 = _menuPrices.length > 3 ? _menuPrices[3].price.text.trim() : '';

      final report = UserReport(
        cityProvince: '',
        cityDistrict: '',
        storeName: _storeController.text.trim(),
        industry: _categoryController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: '',
        menu1: menu1,
        price1: price1,
        menu2: menu2,
        price2: price2,
        menu3: menu3,
        price3: price3,
        menu4: menu4,
        price4: price4,
        imageUrls: [],
        reporterId: auth.email,
        visitedRecently: _visitedRecently,
        checkedMenuPrice: _checkedMenuPrice,
        latitude: 0.0,
        longitude: 0.0,
      );

      final success = await ref.read(reportServiceProvider).submitReport(report);

      if (success) {
        if (mounted) {
          context.push(AppRoutes.reportComplete);
        }
      } else {
        _showSnack('제보 제출에 실패했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }"""

code = code.replace(old_submit, new_submit)

with open("lib/features/community/presentation/screens/report_create_screen.dart", "w") as f:
    f.write(code)


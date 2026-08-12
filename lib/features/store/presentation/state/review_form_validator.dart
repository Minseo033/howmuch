class ReviewFormValidator {
  ReviewFormValidator._();

  static const int maxPrice = 10000000;

  static String? validateMenu(String? value) {
    final menu = value?.trim() ?? '';
    if (menu.isEmpty) return '방문 메뉴를 입력해주세요.';
    if (menu.length > 100) return '방문 메뉴는 100자 이내로 입력해주세요.';
    return null;
  }

  static String? validatePrice(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '실제 결제 가격을 입력해주세요.';

    final normalized = raw.replaceAll(',', '');
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      return '결제 가격은 숫자로 입력해주세요.';
    }

    final price = int.tryParse(normalized);
    if (price == null || price <= 0 || price > maxPrice) {
      return '결제 가격은 1원 이상 1,000만원 이하로 입력해주세요.';
    }
    return null;
  }

  static int? parsePrice(String value) {
    if (validatePrice(value) != null) return null;
    return int.parse(value.trim().replaceAll(',', ''));
  }

  static String? validateContent(String? value) {
    final content = value?.trim() ?? '';
    if (content.isEmpty) return '리뷰 내용을 입력해주세요.';
    if (content.length > 2000) {
      return '리뷰 내용은 2000자 이내로 입력해주세요.';
    }
    return null;
  }

  static String? validateRating(int rating) {
    if (rating < 1 || rating > 5) return '별점을 선택해주세요.';
    return null;
  }

  static String? validateConfirmations({
    required bool visitedRecently,
    required bool priceChecked,
  }) {
    if (!visitedRecently || !priceChecked) {
      return '방문 및 가격 확인 항목에 동의해주세요.';
    }
    return null;
  }
}

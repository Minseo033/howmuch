import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';

void main() {
  test('refreshes only when entering the mypage tab', () {
    expect(
      shouldRefreshMypageOnRouteChange(AppRoutes.home, AppRoutes.mypage),
      isTrue,
    );
    expect(
      shouldRefreshMypageOnRouteChange(AppRoutes.profileEdit, AppRoutes.mypage),
      isTrue,
    );
    expect(
      shouldRefreshMypageOnRouteChange(AppRoutes.mypage, AppRoutes.mypage),
      isFalse,
    );
    expect(
      shouldRefreshMypageOnRouteChange(AppRoutes.mypage, AppRoutes.home),
      isFalse,
    );
  });
}

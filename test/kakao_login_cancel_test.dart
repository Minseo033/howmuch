import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

void main() {
  for (final installed in [false, true]) {
    test(
      'OAuth cancellation ($installed) leaves existing auth untouched',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(authStateProvider.notifier).state = const AuthState(
          isLoggedIn: true, provider: '카카오', email: '', sessionToken: 'retained-session');
        final before = container.read(authStateProvider);
        var oauthCalls = 0;
        final serviceProvider = Provider(
          (ref) => KakaoLoginService(
            ref,
            talkInstalled: () async => installed,
            talkLogin: () async {
              oauthCalls++;
              throw PlatformException(code: 'CANCELED');
            },
            accountLogin: () async {
              oauthCalls++;
              throw KakaoClientException(ClientErrorCause.cancelled, '취소됨');
            },
          ),
        );
        final result = await container.read(serviceProvider).login();
        expect(result.status, KakaoLoginStatus.cancelled);
        expect(result.errorMessage, isNull);
        expect(oauthCalls, 1);
        expect(container.read(authStateProvider), same(before));
        expect(
          (await container.read(serviceProvider).login()).status,
          KakaoLoginStatus.cancelled,
        );
        expect(oauthCalls, 2);
      },
    );
  }
  test('only typed cancellations are cancellation', () {
    expect(
      isKakaoLoginCancellation(
        KakaoClientException(ClientErrorCause.cancelled, 'any message'),
      ),
      isTrue,
    );
    expect(
      isKakaoLoginCancellation(PlatformException(code: 'CANCELED')),
      isTrue,
    );
    expect(isKakaoLoginCancellation(KakaoAuthException(AuthErrorCause.accessDenied, '사용자 취소')), isTrue);
    expect(isKakaoLoginCancellation(KakaoAuthException(AuthErrorCause.invalidGrant, '토큰 오류')), isFalse);
    expect(
      isKakaoLoginCancellation(
        KakaoClientException(ClientErrorCause.unknown, 'Canceled'),
      ),
      isFalse,
    );
    expect(
      isKakaoLoginCancellation(PlatformException(code: 'NETWORK_ERROR')),
      isFalse,
    );
  });
}

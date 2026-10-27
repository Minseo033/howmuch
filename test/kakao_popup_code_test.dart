import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_popup_code.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

void main() {
  test(
    'production authorize URL preserves SDK state and RFC 7636 S256 PKCE',
    () {
      final uri = kakaoPopupAuthorizeUri(
        clientId: 'test-js-key',
        state: 'test-state',
        verifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
        kaHeader: 'sdk/1.9.5 sdk_type/flutter',
        host: 'kauth.kakao.com',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'kauth.kakao.com');
      expect(uri.path, '/oauth/authorize');
      expect(uri.queryParameters, {
        'client_id': 'test-js-key',
        'redirect_uri': 'JS-SDK',
        'response_type': 'code',
        'code_challenge': 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
        'code_challenge_method': 'S256',
        'ka': 'sdk/1.9.5 sdk_type/flutter',
        'state': 'test-state',
        'state_token': 'test-state',
        'is_popup': 'true',
      });
      expect(uri.queryParameters.containsKey('code_verifier'), isFalse);
    },
  );
  testWidgets('closed popup cancels promptly and permits a fresh attempt', (
    tester,
  ) async {
    var closed = false;
    var polls = 0;
    var exchanges = 0;
    final result =
        waitForKakaoPopupCode(
          isClosed: () => closed,
          readCode: () async {
            polls++;
            return 'error';
          },
        ).then((code) {
          exchanges++;
          return code;
        });
    Object? failure;
    result.catchError((Object e) {
      failure = e;
      return '';
    });
    await tester.pump(const Duration(seconds: 1));
    closed = true;
    await tester.pump(const Duration(seconds: 4));
    expect(
      failure,
      isA<KakaoClientException>().having(
        (e) => e.reason,
        'reason',
        ClientErrorCause.cancelled,
      ),
      reason: 'closing the SDK popup must release the login immediately',
    );
    final afterCancel = polls;
    await tester.pump(const Duration(seconds: 30));
    expect(polls, afterCancel, reason: 'cancel must stop code polling');
    expect(exchanges, 0);
    expect(
      await waitForKakaoPopupCode(
        isClosed: () => false,
        readCode: () async => 'new-code',
      ),
      'new-code',
    );
  });

  testWidgets('closed popup cannot be held by a stalled request or late code', (
    tester,
  ) async {
    var closed = false;
    final pending = Completer<String>();
    var exchanges = 0;
    final result =
        waitForKakaoPopupCode(
          isClosed: () => closed,
          readCode: () => pending.future,
        ).then((code) {
          exchanges++;
          return code;
        });
    final cancelled = expectLater(result, throwsA(isA<KakaoClientException>()));
    closed = true;
    await tester.pump(const Duration(seconds: 4));
    await cancelled;
    pending.complete('obsolete-code');
    await tester.pump();
    expect(exchanges, 0);
  });

  testWidgets(
    'successful callback may close its popup before the code poll returns',
    (tester) async {
      var closed = false;
      final pending = Completer<String>();
      final result = waitForKakaoPopupCode(
        isClosed: () => closed,
        readCode: () => pending.future,
      );
      closed = true;
      await tester.pump(const Duration(milliseconds: 250));
      pending.complete('valid-code');
      await tester.pump();
      expect(await result, 'valid-code');
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets(
    'auto-close tolerates a short delay before callback code publication',
    (tester) async {
      var closed = false;
      var polls = 0;
      final result = waitForKakaoPopupCode(
        isClosed: () => closed,
        readCode: () async => ++polls < 3 ? 'error' : 'valid-code',
      );
      closed = true;
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(await result, 'valid-code');
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('network failure is not classified as user cancellation', (
    tester,
  ) async {
    final error = StateError('network failure');
    await expectLater(
      waitForKakaoPopupCode(
        isClosed: () => false,
        readCode: () async => throw error,
      ),
      throwsA(same(error)),
    );
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('open popup timeout fails and ignores late responses', (
    tester,
  ) async {
    final pending = Completer<String>();
    var exchanges = 0;
    final result =
        waitForKakaoPopupCode(
          isClosed: () => false,
          readCode: () => pending.future,
          timeout: const Duration(seconds: 5),
        ).then((code) {
          exchanges++;
          return code;
        });
    final timedOut = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 5));
    await timedOut;
    pending.complete('late-code');
    await tester.pump();
    expect(exchanges, 0);
  });
}

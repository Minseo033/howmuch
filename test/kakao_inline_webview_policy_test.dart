import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/constants/kakao_map_constants.dart';
import 'package:howmuch/core/security/kakao_inline_webview_policy.dart';

void main() {
  late KakaoInlineWebViewPolicy policy;
  late int generation;
  setUp(() {
    policy = KakaoInlineWebViewPolicy();
    generation = policy.beginDocument();
  });
  String envelope(String message, {String? token, String? origin}) =>
      jsonEncode({
        'token':
            token ??
            RegExp(
              r'const mapBridgeToken = "([a-f0-9]+)"',
            ).firstMatch(policy.bridgeScript('Print'))!.group(1),
        'origin': origin ?? kakaoMapAuthorizedOrigin,
        'message': message,
      });
  test(
    'permits only a bootstrap document then blocks even same-origin links',
    () {
      expect(
        policy.allowNavigation(
          'about:blank',
          generation: generation,
          isMainFrame: true,
        ),
        isTrue,
      );
      expect(
        policy.allowNavigation(
          kakaoMapAuthorizedOrigin,
          generation: generation,
          isMainFrame: true,
        ),
        isFalse,
      );
      generation = policy.beginDocument();
      expect(
        policy.allowNavigation(
          '$kakaoMapAuthorizedOrigin/',
          generation: generation,
          isMainFrame: true,
        ),
        isTrue,
      );
      policy.readMessage(
        envelope('INLINE_DOCUMENT_READY'),
        currentUrl: kakaoMapAuthorizedOrigin,
      );
      expect(
        policy.allowNavigation(
          'about:blank',
          generation: generation,
          isMainFrame: true,
        ),
        isFalse,
      );
    },
  );
  test('stale document readiness cannot close a newer bootstrap', () {
    final oldReady = envelope('INLINE_DOCUMENT_READY');
    generation = policy.beginDocument();
    expect(
      policy.readMessage(oldReady, currentUrl: kakaoMapAuthorizedOrigin),
      isNull,
    );
    expect(
      policy.allowNavigation(
        kakaoMapAuthorizedOrigin,
        generation: generation,
        isMainFrame: true,
      ),
      isTrue,
    );
    generation = policy.beginDocument();
    expect(
      policy.readMessage(
        envelope('INLINE_DOCUMENT_READY'),
        currentUrl: kakaoMapAuthorizedOrigin,
      ),
      'INLINE_DOCUMENT_READY',
    );
    expect(
      policy.allowNavigation(
        kakaoMapAuthorizedOrigin,
        generation: generation,
        isMainFrame: true,
      ),
      isFalse,
    );
  });
  test('obsolete delegate callbacks cannot mutate a newer document', () {
    final oldGeneration = generation;
    generation = policy.beginDocument();
    expect(
      policy.allowNavigation(
        kakaoMapAuthorizedOrigin,
        isMainFrame: true,
        generation: oldGeneration,
      ),
      isFalse,
    );
    policy.observePage('https://evil.test', generation: oldGeneration);
    expect(
      policy.allowNavigation(
        kakaoMapAuthorizedOrigin,
        isMainFrame: true,
        generation: generation,
      ),
      isTrue,
    );
  });
  test('blocks external links, frames, escapes and non-HTTPS schemes', () {
    for (final url in [
      'https://evil.test',
      '$kakaoMapAuthorizedOrigin.evil.test',
      'https://howmuch-zeta.vercel.app@evil.test',
      '$kakaoMapAuthorizedOrigin/other',
      '$kakaoMapAuthorizedOrigin/?x=1',
      '$kakaoMapAuthorizedOrigin/#fragment',
      '$kakaoMapAuthorizedOrigin/%2e%2e',
      'https://howmuch-zeta.vercel.app:443',
      'https://howmuch-zeta.vercel.app\\@evil.test',
      'http://howmuch-zeta.vercel.app',
      'javascript:alert(1)',
      'data:text/html,evil',
      'file:///tmp/map.html',
      'intent://map',
      'about:blank#x',
    ]) {
      expect(
        policy.allowNavigation(url, generation: generation, isMainFrame: true),
        isFalse,
        reason: url,
      );
    }
    expect(
      policy.allowNavigation(
        kakaoMapAuthorizedOrigin,
        generation: generation,
        isMainFrame: false,
      ),
      isFalse,
    );
    expect(
      policy.allowNavigation(
        'about:blank',
        generation: generation,
        isMainFrame: false,
      ),
      isFalse,
    );
  });
  test(
    'accepts current inline messages and rejects forgery/replay/origin swaps',
    () {
      final valid = envelope('ready');
      expect(
        policy.readMessage(valid, currentUrl: kakaoMapAuthorizedOrigin),
        'ready',
      );
      expect(policy.readMessage(valid, currentUrl: 'about:blank'), 'ready');
      for (final bad in [
        'ready',
        '{}',
        envelope('ready', token: 'forged'),
        envelope('ready', origin: 'https://evil.test'),
      ]) {
        expect(
          policy.readMessage(bad, currentUrl: kakaoMapAuthorizedOrigin),
          isNull,
        );
      }
      expect(
        policy.readMessage(
          valid,
          currentUrl: '$kakaoMapAuthorizedOrigin/injected',
        ),
        isNull,
      );
      expect(policy.readMessage(valid, currentUrl: null), isNull);
      generation = policy.beginDocument();
      expect(
        policy.readMessage(valid, currentUrl: kakaoMapAuthorizedOrigin),
        isNull,
      );
      final next = envelope('ready');
      policy.observePage('https://evil.test', generation: generation);
      expect(
        policy.readMessage(next, currentUrl: kakaoMapAuthorizedOrigin),
        isNull,
      );
    },
  );
  test(
    'validates rendered identity, not arbitrary current-catalog store IDs',
    () {
      expect(isRenderedMapMarker(0, 'a', ['a', 'b']), isTrue);
      expect(isRenderedMapMarker(0, 'b', ['a', 'b']), isFalse);
      expect(isRenderedMapMarker(-1, 'a', ['a']), isFalse);
      expect(isRenderedMapMarker(3, 'a', ['a']), isFalse);
      expect(isRenderedMapMarker(0, '', ['a']), isFalse);
    },
  );
  test(
    'script JSON cannot escape into HTML and round trips hostile labels',
    () {
      const label = '</ScRiPt><iframe src="https://evil.test">&\u2028\u2029';
      final encoded = encodeMapScriptValue({'name': label});
      expect(encoded, isNot(contains('<')));
      expect(encoded, isNot(contains('>')));
      expect(encoded, isNot(contains('&')));
      expect(jsonDecode(encoded), {'name': label});
      expect(kakaoInlineFramePolicy, contains("frame-src 'none'"));
      expect(policy.bridgeScript('Print'), contains('window.top !== window'));
      expect(
        policy.bridgeScript('Print'),
        contains('location.origin !== mapBridgeOrigin'),
      );
    },
  );
}

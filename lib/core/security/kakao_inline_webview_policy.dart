import 'dart:convert';
import 'dart:math';
import 'package:howmuch/core/constants/kakao_map_constants.dart';

/// Restricts the native bridge to each app-generated in-memory document.
class KakaoInlineWebViewPolicy {
  String _token = '';
  bool _initialNavigation = false;
  int _generation = 0;
  int beginDocument() {
    final random = Random.secure();
    _token = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _initialNavigation = true;
    return ++_generation;
  }

  bool isCurrentDocument(int generation) =>
      generation == _generation && _token.isNotEmpty;

  static bool isInlineDocumentUrl(String? url) =>
      url == 'about:blank' ||
      url == kakaoMapAuthorizedOrigin ||
      url == '$kakaoMapAuthorizedOrigin/';
  bool allowNavigation(
    String url, {
    required bool isMainFrame,
    required int generation,
  }) {
    if (!isCurrentDocument(generation) ||
        !isMainFrame ||
        !_initialNavigation ||
        !isInlineDocumentUrl(url)) {
      return false;
    }
    _initialNavigation = false;
    return true;
  }

  void observePage(String url, {required int generation}) {
    if (!isCurrentDocument(generation)) return;
    if (!isInlineDocumentUrl(url)) {
      _token = '';
      _initialNavigation = false;
    }
  }

  String? readMessage(String raw, {required String? currentUrl}) {
    if (_token.isEmpty ||
        raw.length > 16384 ||
        !isInlineDocumentUrl(currentUrl)) {
      return null;
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map ||
          value.length != 3 ||
          value['token'] != _token ||
          value['origin'] != kakaoMapAuthorizedOrigin ||
          value['message'] is! String) {
        return null;
      }
      // Page callbacks carry no document identity. Only the current document's
      // capability may seal bootstrap, so a late old onPageFinished is harmless.
      _initialNavigation = false;
      return value['message'] as String;
    } on FormatException {
      return null;
    }
  }

  /// Place inside a private IIFE. webview_flutter supplies no origin/frame
  /// metadata; the fresh capability rejects other frames and stale documents.
  /// SDK scripts execute as trusted same-origin code, not as a sandbox.
  String bridgeScript(String channel) =>
      '''
    const mapBridgeToken = TOKEN_VALUE;
    const mapBridgeOrigin = ORIGIN_VALUE;
    const nativeMapBridge = window[CHANNEL_VALUE];
    if (document.currentScript) document.currentScript.remove();
    function sendMapMessage(message) {
      if (window.top !== window || location.origin !== mapBridgeOrigin) return;
      nativeMapBridge.postMessage(JSON.stringify({token: mapBridgeToken, origin: mapBridgeOrigin, message: message}));
    }
    sendMapMessage('INLINE_DOCUMENT_READY');
  '''
          .replaceAll('TOKEN_VALUE', jsonEncode(_token))
          .replaceAll('ORIGIN_VALUE', jsonEncode(kakaoMapAuthorizedOrigin))
          .replaceAll('CHANNEL_VALUE', jsonEncode(channel));
}

/// JSON in inline scripts must not terminate the script element.
String encodeMapScriptValue(Object? value) => jsonEncode(value)
    .replaceAll('<', r'\u003c')
    .replaceAll('>', r'\u003e')
    .replaceAll('&', r'\u0026')
    .replaceAll(String.fromCharCode(0x2028), r'\u2028')
    .replaceAll(String.fromCharCode(0x2029), r'\u2029');

/// No child frames may access the plugin's all-frame JavaScript channel.
const kakaoInlineFramePolicy =
    "<meta http-equiv=\"Content-Security-Policy\" content=\"frame-src 'none'; child-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'\">";

bool isRenderedMapMarker(int index, String storeId, List<String> renderedIds) =>
    index >= 0 &&
    index < renderedIds.length &&
    storeId.isNotEmpty &&
    renderedIds[index] == storeId;

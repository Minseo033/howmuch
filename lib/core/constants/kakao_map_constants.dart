/// Public JavaScript key used by the Kakao Maps SDK.
///
/// This key is intentionally client-side. Its use must remain restricted to
/// the approved web origin in the Kakao Developers console.
const String kakaoMapJavaScriptKey = '8aa42a2f5dc0314f1fe917a90aa6c112';

/// The production origin registered for the Kakao Maps JavaScript platform.
///
/// WKWebView uses the base URL of an HTML string as the page origin. Keeping
/// this aligned with the registered production origin is required for map
/// tiles to load on iOS while still loading the HTML itself from memory.
const String kakaoMapAuthorizedOrigin = 'https://howmuch-zeta.vercel.app';

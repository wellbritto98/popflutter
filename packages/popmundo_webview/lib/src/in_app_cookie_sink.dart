import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Writes [GameCookie]s into the WebView's jar via `CookieManager`.
///
/// This is what makes the native auth handshake visible to the WebView: page
/// loads authenticate from this jar, not from the `dart:io` client's.
class InAppCookieSink implements CookieSink {
  InAppCookieSink({CookieManager? manager})
      : _manager = manager ?? CookieManager.instance();

  final CookieManager _manager;

  @override
  Future<void> write(Iterable<GameCookie> cookies) async {
    for (final cookie in cookies) {
      await _manager.setCookie(
        url: WebUri('https://${cookie.host}${cookie.path}'),
        name: cookie.name,
        value: cookie.value,
        path: cookie.path,
        // Host-only cookies must stay host-only: passing a domain here would
        // create a different, broader cookie than the server set.
        domain: cookie.domainAttribute,
        expiresDate: cookie.expires?.millisecondsSinceEpoch,
        isSecure: cookie.secure,
        isHttpOnly: cookie.httpOnly,
        sameSite: sameSitePolicyFor(cookie.sameSite),
      );
    }
  }
}

/// Maps a `SameSite` attribute string onto the plugin's enum.
///
/// Unset means the browser default, which modern Chromium treats as Lax — the
/// same value the game sends explicitly.
HTTPCookieSameSitePolicy? sameSitePolicyFor(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'lax':
      return HTTPCookieSameSitePolicy.LAX;
    case 'strict':
      return HTTPCookieSameSitePolicy.STRICT;
    case 'none':
      return HTTPCookieSameSitePolicy.NONE;
    default:
      return null;
  }
}

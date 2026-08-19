import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Writes [GameCookie]s into the WebView's jar via `CookieManager`, and reads
/// them back so the session heartbeat can seed [AuthSession] (AD-019).
class InAppCookieSink implements CookieSink, CookieSource {
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

  @override
  Future<List<GameCookie>> read(Uri url) async {
    final cookies = await _manager.getCookies(url: WebUri(url.toString()));
    return [for (final cookie in cookies) gameCookieFromInApp(cookie, url)];
  }
}

/// Maps a plugin [Cookie] onto [GameCookie], preserving host-only scope.
///
/// Android may omit `domain`/`path`/`httpOnly` unless `GET_COOKIE_INFO` is
/// available — name+value still produce a sendable `Cookie` header. A domain
/// equal to [url]'s host is treated as host-only.
GameCookie gameCookieFromInApp(Cookie cookie, Uri url) {
  final rawDomain = cookie.domain?.trim();
  String? domainAttribute;
  if (rawDomain != null && rawDomain.isNotEmpty) {
    final bare =
        rawDomain.startsWith('.') ? rawDomain.substring(1) : rawDomain;
    if (bare.toLowerCase() != url.host.toLowerCase()) {
      domainAttribute = rawDomain;
    }
  }
  final path = cookie.path;
  return GameCookie(
    name: cookie.name,
    value: '${cookie.value ?? ''}',
    host: url.host,
    path: (path == null || path.isEmpty) ? '/' : path,
    domainAttribute: domainAttribute,
    secure: cookie.isSecure ?? url.scheme == 'https',
    httpOnly: cookie.isHttpOnly ?? false,
    sameSite: sameSiteName(cookie.sameSite),
    expires: cookie.expiresDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(cookie.expiresDate!, isUtc: true),
  );
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

String? sameSiteName(HTTPCookieSameSitePolicy? policy) {
  switch (policy) {
    case HTTPCookieSameSitePolicy.LAX:
      return 'Lax';
    case HTTPCookieSameSitePolicy.STRICT:
      return 'Strict';
    case HTTPCookieSameSitePolicy.NONE:
      return 'None';
    default:
      return null;
  }
}

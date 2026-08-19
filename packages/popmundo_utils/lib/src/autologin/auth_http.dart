import '../timed_fetch.dart' show ClockNow, Sleeper;
import 'game_cookie.dart';

/// One outgoing request of the auth handshake.
class AuthHttpRequest {
  const AuthHttpRequest({
    required this.url,
    required this.method,
    this.headers = const {},
    this.body,
  });

  final Uri url;
  final String method;
  final Map<String, String> headers;
  final String? body;
}

/// One raw response, with redirects **not** followed.
class AuthHttpResponse {
  const AuthHttpResponse({
    required this.status,
    required this.body,
    this.setCookieHeaders = const [],
    this.location,
  });

  final int status;
  final String body;

  /// Every `Set-Cookie` line, unparsed.
  final List<String> setCookieHeaders;

  /// `Location` exactly as sent — may be relative.
  final String? location;

  bool get isRedirect => status >= 300 && status < 400 && location != null;
}

/// Performs a single request without following redirects.
typedef AuthHttpSend = Future<AuthHttpResponse> Function(AuthHttpRequest req);

class AuthHttpException implements Exception {
  AuthHttpException(this.message);
  final String message;

  @override
  String toString() => 'AuthHttpException: $message';
}

/// Where a chain of requests ended up.
class AuthExchange {
  const AuthExchange({
    required this.finalUrl,
    required this.status,
    required this.body,
    required this.hops,
  });

  final Uri finalUrl;
  final int status;
  final String body;

  /// Every URL visited, first to last — the redirect chain, for diagnostics.
  final List<Uri> hops;
}

/// A cookie-aware HTTP session for the Popmundo login handshake.
///
/// This runs **outside** the WebView, so no CORS applies and the `www` to
/// `N.popmundo.com` handover can be followed. Redirects are followed by hand so
/// every hop's `Set-Cookie` is captured — the auth cookie is only set on the
/// last hop, by the numbered host.
///
/// The 750 ms cooldown of AD-006 is honoured here too: this talks to the same
/// throttled game servers as [TimedFetch], just over a different transport.
class AuthSession {
  AuthSession({
    required this.send,
    required this.userAgent,
    this.delay = const Duration(milliseconds: 750),
    ClockNow? now,
    Sleeper? sleep,
  })  : _now = now ?? DateTime.now,
        _sleep = sleep ?? Future<void>.delayed {
    _lastCall = _now().subtract(delay);
  }

  static const maxHops = 10;

  /// Transport. Injected so tests can drive the handshake without sockets.
  final AuthHttpSend send;

  /// Copied from the WebView so the game sees one client, not two.
  final String userAgent;

  final Duration delay;
  final ClockNow _now;
  final Sleeper _sleep;
  late DateTime _lastCall;

  final _jar = <String, GameCookie>{};

  /// Live, non-expired cookies gathered so far.
  List<GameCookie> get cookies {
    final now = _now();
    return [
      for (final c in _jar.values)
        if (!c.expiredAt(now)) c,
    ];
  }

  /// GETs [url] and follows redirects, returning where it landed.
  Future<AuthExchange> get(Uri url) => _run(url, 'GET', null, null);

  /// POSTs a urlencoded [body] to [url] and follows redirects.
  ///
  /// Redirects after a POST are re-issued as GET, which is what a browser does
  /// for 302 and what the game's `Location` to `Login.aspx` expects.
  Future<AuthExchange> postForm(Uri url, String body) => _run(
        url,
        'POST',
        body,
        'application/x-www-form-urlencoded',
      );

  Future<AuthExchange> _run(
    Uri url,
    String method,
    String? body,
    String? contentType,
  ) async {
    var current = url;
    var currentMethod = method;
    String? currentBody = body;
    String? currentType = contentType;
    final hops = <Uri>[current];

    for (var hop = 0; hop < maxHops; hop++) {
      await _cooldown();
      final response = await send(AuthHttpRequest(
        url: current,
        method: currentMethod,
        headers: _headersFor(current, currentType, currentBody),
        body: currentBody,
      ));
      _lastCall = _now();
      _absorb(response, current);

      if (!response.isRedirect) {
        return AuthExchange(
          finalUrl: current,
          status: response.status,
          body: response.body,
          hops: hops,
        );
      }

      final next = _resolveLocation(current, response.location!);
      if (next == null) {
        throw AuthHttpException(
          'Unusable Location "${response.location}" from $current',
        );
      }
      current = next;
      hops.add(current);
      // A 302 after POST becomes a GET, as browsers do.
      currentMethod = 'GET';
      currentBody = null;
      currentType = null;
    }
    throw AuthHttpException('More than $maxHops redirects starting at $url');
  }

  Map<String, String> _headersFor(Uri url, String? contentType, String? body) {
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
    };
    if (contentType != null) headers['Content-Type'] = contentType;
    if (body != null) headers['Origin'] = 'https://${url.host}';
    final jarHeader = _cookieHeaderFor(url);
    if (jarHeader.isNotEmpty) headers['Cookie'] = jarHeader;
    return headers;
  }

  String _cookieHeaderFor(Uri url) {
    final now = _now();
    return [
      for (final c in _jar.values)
        if (!c.expiredAt(now) && c.matches(url)) c.headerPair,
    ].join('; ');
  }

  void _absorb(AuthHttpResponse response, Uri from) {
    for (final cookie in GameCookie.parseAll(response.setCookieHeaders, from)) {
      if (cookie.value.isEmpty && cookie.expiredAt(_now())) {
        // A deletion, e.g. the game clearing a stale auth cookie.
        _jar.remove(cookie.key);
        continue;
      }
      _jar[cookie.key] = cookie;
    }
  }

  /// Resolves a `Location`, which the game sends both absolute and relative —
  /// and sometimes with a doubled slash (`https://74.popmundo.com//Login.aspx`).
  static Uri? _resolveLocation(Uri from, String location) {
    if (location.isEmpty) return null;
    final parsed = Uri.tryParse(location);
    if (parsed == null) return null;
    final resolved = parsed.hasScheme ? parsed : from.resolveUri(parsed);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    return resolved;
  }

  Future<void> _cooldown() async {
    final elapsed = _now().difference(_lastCall);
    if (elapsed < delay) await _sleep(delay - elapsed);
  }
}

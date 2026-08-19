import 'dart:convert';
import 'dart:io';

/// One hop of a redirect chain.
class LiveHop {
  LiveHop({
    required this.method,
    required this.url,
    required this.status,
    this.location,
  });

  final String method;
  final Uri url;
  final int status;
  final String? location;

  bool get isRedirect => status >= 300 && status < 400;

  @override
  String toString() =>
      '$method ${url.host}${url.path} -> $status'
      '${location == null ? '' : ' => $location'}';
}

class LiveResponse {
  LiveResponse({
    required this.body,
    required this.requestUrl,
    required this.finalUrl,
    required this.chain,
    required this.status,
    required this.headers,
    required this.setCookies,
  });

  final String body;

  /// URL the request started at.
  final Uri requestUrl;

  /// URL of the last response, after every redirect — the `res.url` an in-page
  /// `fetch` would report.
  final Uri finalUrl;

  /// Every hop, so a test can assert whether the chain left the origin.
  final List<LiveHop> chain;

  /// Status of the last response in the chain.
  final int status;

  /// Response headers of the last hop, lowercase names.
  final Map<String, List<String>> headers;

  /// `Set-Cookie` of the **first** hop, parsed. Kept unmerged so a test can
  /// inspect attributes (notably `domain`) rather than just the value.
  final List<Cookie> setCookies;

  /// True when the first hop was a redirect — i.e. the request itself bounced.
  bool get isRedirect => chain.first.isRedirect;

  /// Target of the first redirect, resolved against the request URL.
  Uri? get location {
    final raw = chain.first.location;
    return raw == null ? null : requestUrl.resolve(raw);
  }

  /// True when any hop moved to a different host, which is what makes an
  /// in-page `fetch` fail on CORS and forces the form-navigation fallback.
  bool get crossedOrigin =>
      chain.map((h) => h.url.host.toLowerCase()).toSet().length > 1;

  String get trail => chain.map((h) => h.toString()).join(' | ');
}

/// Minimal cookie-jar HTTP client that follows redirects the way a browser
/// does, so a live test sees the same chain the WebView would.
///
/// Deliberately not `package:http`: this package has no HTTP dependency, and
/// these tests need per-hop visibility that a follow-redirects client hides.
class LiveClient {
  LiveClient({this.maxRedirects = 10})
      : _client = HttpClient()..userAgent = _userAgent;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0.0.0 Mobile Safari/537.36';

  final int maxRedirects;
  final HttpClient _client;

  /// host -> (cookie name -> value). Popmundo's auth cookie is host-only (no
  /// `domain=`), so the jar must be keyed by host to reproduce the real hop.
  final _jar = <String, Map<String, String>>{};

  void close() => _client.close(force: true);

  Map<String, String> cookiesFor(String host) =>
      Map.unmodifiable(_jar[host.toLowerCase()] ?? const {});

  /// Every cookie name held for any host.
  Set<String> get cookieNames =>
      {for (final bucket in _jar.values) ...bucket.keys};

  Future<LiveResponse> get(Uri url) => _send('GET', url, null);

  Future<LiveResponse> postForm(Uri url, String encodedBody) =>
      _send('POST', url, encodedBody);

  Future<LiveResponse> _send(String method, Uri url, String? body) async {
    final chain = <LiveHop>[];
    final requestUrl = url;
    var current = url;
    var currentMethod = method;
    String? currentBody = body;
    List<Cookie>? firstSetCookies;

    for (var i = 0; i <= maxRedirects; i++) {
      final request = await _client.openUrl(currentMethod, current);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      final cookies = _jar[current.host.toLowerCase()];
      if (cookies != null && cookies.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader,
            cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }
      if (currentBody != null) {
        request.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded');
        final bytes = utf8.encode(currentBody);
        request.headers.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close();
      final parsed = _parseCookies(response);
      firstSetCookies ??= parsed;
      _storeCookies(current.host, parsed);

      final location = response.headers.value(HttpHeaders.locationHeader);
      final text = await response.transform(utf8.decoder).join();
      chain.add(LiveHop(
        method: currentMethod,
        url: current,
        status: response.statusCode,
        location: location,
      ));

      final redirecting = response.statusCode >= 300 &&
          response.statusCode < 400 &&
          location != null;
      if (redirecting) {
        current = current.resolve(location);
        // 302/303 turn a POST into a GET, same as a browser.
        currentMethod = 'GET';
        currentBody = null;
        continue;
      }
      return LiveResponse(
        body: text,
        requestUrl: requestUrl,
        finalUrl: current,
        chain: chain,
        status: response.statusCode,
        headers: _headerMap(response),
        setCookies: firstSetCookies,
      );
    }
    throw StateError('Too many redirects: ${chain.join(' | ')}');
  }

  static Map<String, List<String>> _headerMap(HttpClientResponse response) {
    final out = <String, List<String>>{};
    response.headers.forEach((name, values) => out[name.toLowerCase()] = values);
    return out;
  }

  static List<Cookie> _parseCookies(HttpClientResponse response) {
    final raw = response.headers[HttpHeaders.setCookieHeader] ?? const <String>[];
    final out = <Cookie>[];
    for (final value in raw) {
      try {
        out.add(Cookie.fromSetCookieValue(value));
      } on Exception {
        // A malformed Set-Cookie is the site's problem, not the jar's.
      }
    }
    return out;
  }

  void _storeCookies(String host, List<Cookie> cookies) {
    final key = host.toLowerCase();
    for (final cookie in cookies) {
      final domain = cookie.domain;
      final targets = <String>{key};
      if (domain != null) {
        final suffix = domain.startsWith('.') ? domain.substring(1) : domain;
        targets.addAll(_jar.keys.where((h) => h == suffix || h.endsWith('.$suffix')));
      }
      for (final target in targets) {
        final bucket = _jar.putIfAbsent(target, () => <String, String>{});
        if (cookie.value.isEmpty) {
          bucket.remove(cookie.name);
        } else {
          bucket[cookie.name] = cookie.value;
        }
      }
    }
  }
}

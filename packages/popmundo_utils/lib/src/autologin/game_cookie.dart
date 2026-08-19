/// A cookie captured from a `Set-Cookie` header during the auth handshake.
///
/// Popmundo's session cookies are **host-only** — `ASP.NET_SessionId` and the
/// `popmundo.com` auth cookie arrive with no `domain=` attribute — so [host]
/// and [domainAttribute] are kept apart: writing a domain where the server sent
/// none would turn a host-only cookie into a domain cookie, which the browser
/// treats as a different cookie.
class GameCookie {
  const GameCookie({
    required this.name,
    required this.value,
    required this.host,
    this.path = '/',
    this.domainAttribute,
    this.secure = false,
    this.httpOnly = false,
    this.sameSite,
    this.expires,
  });

  final String name;
  final String value;

  /// Host of the response that set it — the owner of a host-only cookie.
  final String host;

  final String path;

  /// `domain=` exactly as sent, or null for a host-only cookie.
  final String? domainAttribute;

  final bool secure;
  final bool httpOnly;

  /// `Lax` / `Strict` / `None`, as sent.
  final String? sameSite;

  /// Absolute expiry, or null for a session cookie.
  final DateTime? expires;

  bool get isHostOnly => domainAttribute == null;

  bool expiredAt(DateTime now) => expires != null && !expires!.isAfter(now);

  /// Whether this cookie should be sent to [url].
  bool matches(Uri url) {
    if (secure && url.scheme != 'https') return false;
    if (!_hostMatches(url.host)) return false;
    return _pathMatches(url.path.isEmpty ? '/' : url.path);
  }

  bool _hostMatches(String requestHost) {
    final target = requestHost.toLowerCase();
    final domain = domainAttribute;
    if (domain == null) return target == host.toLowerCase();
    final bare = domain.startsWith('.') ? domain.substring(1) : domain;
    final lower = bare.toLowerCase();
    return target == lower || target.endsWith('.$lower');
  }

  bool _pathMatches(String requestPath) {
    if (path == '/' || requestPath == path) return true;
    if (!requestPath.startsWith(path)) return false;
    return path.endsWith('/') || requestPath[path.length] == '/';
  }

  String get headerPair => '$name=$value';

  /// Same identity the browser uses: name + owner + path.
  String get key => '$name ${domainAttribute ?? host} $path';

  @override
  String toString() => 'GameCookie($name, host: $host, '
      'domain: ${domainAttribute ?? '<host-only>'}, path: $path, '
      'secure: $secure, httpOnly: $httpOnly, sameSite: $sameSite)';

  /// Parses every `Set-Cookie` line of one response.
  ///
  /// [from] is the URL that produced them, used as the host of a host-only
  /// cookie.
  static List<GameCookie> parseAll(Iterable<String> headers, Uri from) {
    final out = <GameCookie>[];
    for (final header in headers) {
      final cookie = parse(header, from);
      if (cookie != null) out.add(cookie);
    }
    return out;
  }

  static GameCookie? parse(String header, Uri from) {
    final parts = header.split(';');
    if (parts.isEmpty) return null;
    final first = parts.first;
    final eq = first.indexOf('=');
    if (eq <= 0) return null;
    final name = first.substring(0, eq).trim();
    final value = first.substring(eq + 1).trim();
    if (name.isEmpty) return null;

    var path = '/';
    String? domain;
    var secure = false;
    var httpOnly = false;
    String? sameSite;
    DateTime? expires;
    int? maxAge;

    for (final raw in parts.skip(1)) {
      final attr = raw.trim();
      if (attr.isEmpty) continue;
      final idx = attr.indexOf('=');
      final key = (idx == -1 ? attr : attr.substring(0, idx)).toLowerCase();
      final val = idx == -1 ? '' : attr.substring(idx + 1).trim();
      switch (key) {
        case 'path':
          if (val.startsWith('/')) path = val;
        case 'domain':
          if (val.isNotEmpty) domain = val;
        case 'secure':
          secure = true;
        case 'httponly':
          httpOnly = true;
        case 'samesite':
          if (val.isNotEmpty) sameSite = val;
        case 'expires':
          expires = parseCookieDate(val);
        case 'max-age':
          maxAge = int.tryParse(val);
      }
    }

    // Max-Age wins over Expires, per RFC 6265.
    if (maxAge != null) {
      expires = DateTime.now().toUtc().add(Duration(seconds: maxAge));
    }

    return GameCookie(
      name: name,
      value: value,
      host: from.host,
      path: path,
      domainAttribute: domain,
      secure: secure,
      httpOnly: httpOnly,
      sameSite: sameSite,
      expires: expires,
    );
  }

  static const _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Parses both cookie date spellings the game emits:
  /// `Thu, 19-Aug-2027 15:45:05 GMT` and `Thu, 19 Aug 2027 15:45:05 GMT`.
  static DateTime? parseCookieDate(String raw) {
    final m = RegExp(
      r'(\d{1,2})[ -]([A-Za-z]{3})[A-Za-z]*[ -](\d{2,4})\s+'
      r'(\d{1,2}):(\d{2}):(\d{2})',
    ).firstMatch(raw.trim());
    if (m == null) return null;
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;
    var year = int.parse(m.group(3)!);
    if (year < 100) year += year < 70 ? 2000 : 1900;
    return DateTime.utc(
      year,
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}

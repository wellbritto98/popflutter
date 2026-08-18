/// Sticky Popmundo origin. Starts at www and follows in-game host changes.
class HostTracker {
  static const String defaultOrigin = 'https://www.popmundo.com';

  Uri _current = Uri.parse(defaultOrigin);

  Uri get currentOrigin => _current;

  static bool isPopmundoHost(String host) {
    final h = host.toLowerCase();
    return h == 'popmundo.com' || h.endsWith('.popmundo.com');
  }

  static bool isPopmundoUri(Uri uri) => isPopmundoHost(uri.host);

  /// Updates origin only for Popmundo http(s) navigations.
  void onNavigation(Uri url) {
    if (!isPopmundoUri(url)) return;
    if (url.scheme != 'http' && url.scheme != 'https') return;
    _current = Uri(scheme: 'https', host: url.host);
  }

  /// Builds `https://{currentHost}{path}` with leading and trailing slashes.
  Uri resolve(String urlPath) {
    var path = urlPath;
    if (!path.startsWith('/')) path = '/$path';
    if (!path.endsWith('/')) path = '$path/';
    return Uri.parse('https://${_current.host}$path');
  }
}

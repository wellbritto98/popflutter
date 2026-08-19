import 'game_cookie.dart';

/// Writes cookies into the WebView's own cookie jar.
///
/// The native auth handshake ([AuthSession]) authenticates over `dart:io`,
/// which has a jar of its own — the WebView authenticates page loads from
/// `android.webkit.CookieManager`, so nothing is logged in until the cookies
/// are copied across. Implemented in the WebView adapter; a port here keeps
/// this package Flutter-free (AD-002).
abstract class CookieSink {
  Future<void> write(Iterable<GameCookie> cookies);
}

/// Reads cookies out of the WebView (or a test double) for one URL.
///
/// The session heartbeat seeds [AuthSession] from this jar so the Character
/// GET carries the cookies the player is actually using, not an empty dart:io
/// jar (AD-019).
abstract class CookieSource {
  Future<List<GameCookie>> read(Uri url);
}

/// Records writes and serves reads. Test double for both ports.
class MemoryCookieSink implements CookieSink, CookieSource {
  final written = <GameCookie>[];
  final _jar = <GameCookie>[];

  /// Makes cookies readable without going through [write] — the WebView jar
  /// as it exists before a handshake.
  void seed(Iterable<GameCookie> cookies) => _jar.addAll(cookies);

  @override
  Future<void> write(Iterable<GameCookie> cookies) async {
    written.addAll(cookies);
    _jar.addAll(cookies);
  }

  @override
  Future<List<GameCookie>> read(Uri url) async {
    return [for (final c in _jar) if (c.matches(url)) c];
  }
}

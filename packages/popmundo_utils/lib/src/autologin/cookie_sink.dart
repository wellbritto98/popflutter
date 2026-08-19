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

/// Records writes instead of performing them. Test double.
class MemoryCookieSink implements CookieSink {
  final written = <GameCookie>[];

  @override
  Future<void> write(Iterable<GameCookie> cookies) async {
    written.addAll(cookies);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'debug_overlay.dart' show CookieSummary;

/// Reads the WebView's cookie jar for the debug overlay's `name@domain` list.
///
/// This is the app layer's **only** direct use of `flutter_inappwebview`,
/// bypassing the `popmundo_webview` adapter — a coupling `CLAUDE.md` documents
/// as intentional. It lives in its own file so that coupling has a name and a
/// single place to look, rather than sitting anonymously inside the composition
/// root. Deliberately *not* a port: there is one implementation and no seam to
/// justify an interface.
///
/// Values are never exposed — only `name` and `domain`, per the debug-overlay
/// rule in `docs/ARQUITETURA.md`.
class CookieWatcher {
  CookieWatcher(this._host);

  final HostTracker _host;

  final cookies = ValueNotifier<List<CookieSummary>>(const []);

  bool _disposed = false;

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final url = WebUri(_host.currentOrigin.toString());
      final raw = await CookieManager.instance().getCookies(url: url);
      // The await above can outlive dispose() — writing then would throw.
      if (_disposed) return;
      cookies.value = [
        for (final cookie in raw)
          CookieSummary(name: cookie.name, domain: cookie.domain ?? url.host),
      ];
    } catch (_) {
      // CookieManager is unavailable in some test/desktop bindings.
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cookies.dispose();
  }
}

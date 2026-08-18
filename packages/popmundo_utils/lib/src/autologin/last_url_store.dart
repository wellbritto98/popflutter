import '../host_tracker.dart';
import '../storage.dart';

class LastUrlStore {
  LastUrlStore(this.store, {this.storageKey = defaultStorageKey});

  static const defaultStorageKey = 'session.last_url.v1';

  static const authPathPrefixes = <String>[
    '/Login.aspx',
    '/World/Popmundo.aspx/ChooseCharacter',
  ];

  final KeyValueStore store;
  final String storageKey;

  /// Returns true when [url] is a Popmundo URL worth restoring after login.
  static bool isEligible(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!HostTracker.isPopmundoUri(uri)) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/' || path == '/Default.aspx') return false;
    for (final prefix in authPathPrefixes) {
      if (path == prefix || path.startsWith('$prefix/')) return false;
    }
    return true;
  }

  Future<void> record(String url) async {
    if (!isEligible(url)) return;
    await store.set(storageKey, url);
  }

  Future<String?> read() async {
    final raw = await store.get(storageKey);
    if (raw is! String || raw.isEmpty) return null;
    if (!isEligible(raw)) return null;
    return raw;
  }

  /// Cold-start URL for [PopmundoWebView.initialUrl] (NAV-04).
  static String resolveInitialUrl(String? lastEligible) {
    if (lastEligible != null && lastEligible.isNotEmpty) {
      return lastEligible;
    }
    return HostTracker.defaultOrigin;
  }
}

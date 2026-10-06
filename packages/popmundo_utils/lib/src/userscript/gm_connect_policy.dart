import '../core/host_tracker.dart';

/// Runtime allowlist for `GM.xmlHttpRequest` to non-Popmundo hosts.
///
/// Popmundo hosts are always allowed when the script has the XHR grant.
/// Other hosts require a matching `@connect` header from the userscript.
class GmConnectPolicy {
  /// Maximum bytes per `@resource` body at import time.
  static const int maxResourceBytes = 1024 * 1024;

  /// Returns true when [url] may be fetched via GM XHR for a script whose
  /// `@connect` headers are [connectHeaders].
  static bool allows(Uri url, List<String> connectHeaders) {
    if (url.scheme != 'http' && url.scheme != 'https') return false;
    if (HostTracker.isPopmundoUri(url)) return true;
    final host = url.host.toLowerCase();
    for (final raw in connectHeaders) {
      if (_matchesHostPattern(raw.trim().toLowerCase(), host)) return true;
    }
    return false;
  }

  static bool _matchesHostPattern(String pattern, String host) {
    if (pattern.isEmpty) return false;
    if (pattern == '*') return true;
    if (pattern.startsWith('*.')) {
      final bare = pattern.substring(2);
      return host == bare || host.endsWith('.$bare');
    }
    return host == pattern;
  }
}

/// Parses `@resource name url` metadata lines into a name→url map.
class UserScriptResourceParser {
  static Map<String, String> parseHeaders(List<String> lines) {
    final result = <String, String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final space = trimmed.indexOf(' ');
      if (space <= 0) continue;
      final name = trimmed.substring(0, space).trim();
      final url = trimmed.substring(space + 1).trim();
      if (name.isNotEmpty && url.isNotEmpty) {
        result[name] = url;
      }
    }
    return result;
  }
}

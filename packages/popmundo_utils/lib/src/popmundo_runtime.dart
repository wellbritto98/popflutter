import 'events.dart';
import 'host_tracker.dart';

class InPageFetchResult {
  const InPageFetchResult({
    required this.ok,
    required this.status,
    required this.text,
    this.headers = const {},
    this.url,
  });

  final bool ok;
  final int status;
  final String text;

  /// Lowercase header names when present (e.g. `location`).
  final Map<String, String> headers;

  /// Request or final URL when the adapter provides it.
  final String? url;

  String? get locationHeader {
    final raw = headers['location'] ?? headers['Location'];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

class PopmundoRuntimeException implements Exception {
  PopmundoRuntimeException(this.message);
  final String message;

  @override
  String toString() => 'PopmundoRuntimeException: $message';
}

/// Adapter contract implemented by the WebView package.
abstract class PopmundoRuntime {
  HostTracker get host;
  PopmundoEventBus get events;

  Future<String?> evaluate(String source);

  Future<InPageFetchResult> fetchInPage({
    required String url,
    Map<String, dynamic>? options,
  });

  /// Navigate the document (updates host sticky via native navigation).
  Future<void> loadUrl(Uri url);

  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  });
}

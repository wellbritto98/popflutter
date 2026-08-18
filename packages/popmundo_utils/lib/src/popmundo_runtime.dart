import 'events.dart';
import 'host_tracker.dart';

class InPageFetchResult {
  const InPageFetchResult({
    required this.ok,
    required this.status,
    required this.text,
  });

  final bool ok;
  final int status;
  final String text;
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

  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  });
}

import 'dart:async';
import 'dart:convert';

class NetworkEvent {
  NetworkEvent({
    required this.method,
    required this.url,
    this.status,
    this.body,
    this.bodyTruncated = false,
    this.bodyOmitted = false,
    this.source = 'fetch',
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String method;
  final String url;
  final int? status;
  final String? body;
  final bool bodyTruncated;
  final bool bodyOmitted;
  final String source;
  final DateTime at;
}

class ConsoleEvent {
  ConsoleEvent({required this.level, required this.message, DateTime? at})
      : at = at ?? DateTime.now();

  final String level;
  final String message;
  final DateTime at;
}

class NavigationEvent {
  NavigationEvent({required this.url, DateTime? at}) : at = at ?? DateTime.now();

  final String url;
  final DateTime at;
}

class BodyCapture {
  static const int maxBytes = 32768;

  static BodyCaptureResult capture(String? body, {bool binary = false}) {
    if (binary) {
      return const BodyCaptureResult(body: null, truncated: false, omitted: true);
    }
    if (body == null) {
      return const BodyCaptureResult(body: null, truncated: false, omitted: false);
    }
    final bytes = utf8.encode(body);
    if (bytes.length <= maxBytes) {
      return BodyCaptureResult(body: body, truncated: false, omitted: false);
    }
    final cut = utf8.decode(bytes.sublist(0, maxBytes), allowMalformed: true);
    return BodyCaptureResult(body: cut, truncated: true, omitted: false);
  }
}

class BodyCaptureResult {
  const BodyCaptureResult({
    required this.body,
    required this.truncated,
    required this.omitted,
  });

  final String? body;
  final bool truncated;
  final bool omitted;
}

class PopmundoEventBus {
  final _network = StreamController<NetworkEvent>.broadcast(sync: true);
  final _console = StreamController<ConsoleEvent>.broadcast(sync: true);
  final _navigation = StreamController<NavigationEvent>.broadcast(sync: true);

  Stream<NetworkEvent> get network => _network.stream;
  Stream<ConsoleEvent> get console => _console.stream;
  Stream<NavigationEvent> get navigation => _navigation.stream;

  void emitNetwork(NetworkEvent event) => _network.add(event);
  void emitConsole(ConsoleEvent event) => _console.add(event);
  void emitNavigation(NavigationEvent event) => _navigation.add(event);

  Future<void> dispose() async {
    await _network.close();
    await _console.close();
    await _navigation.close();
  }
}

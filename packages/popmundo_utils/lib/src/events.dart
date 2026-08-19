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

class GmValueEvent {
  GmValueEvent({
    required this.scriptId,
    required this.action,
    required this.key,
    this.value,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String scriptId;
  final String action;
  final String key;
  final Object? value;
  final DateTime at;
}

/// Host GM API call from a userscript (`type: 'gm'` on the JS bridge).
class GmCallEvent {
  GmCallEvent({
    required this.scriptId,
    required this.action,
    this.callId,
    this.data = const {},
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String scriptId;
  final String action;
  final String? callId;
  final Map<String, dynamic> data;
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
  final _gmValue = StreamController<GmValueEvent>.broadcast(sync: true);
  final _gmCall = StreamController<GmCallEvent>.broadcast(sync: true);

  Stream<NetworkEvent> get network => _network.stream;
  Stream<ConsoleEvent> get console => _console.stream;
  Stream<NavigationEvent> get navigation => _navigation.stream;
  Stream<GmValueEvent> get gmValue => _gmValue.stream;
  Stream<GmCallEvent> get gmCall => _gmCall.stream;

  void emitNetwork(NetworkEvent event) => _network.add(event);
  void emitConsole(ConsoleEvent event) => _console.add(event);
  void emitNavigation(NavigationEvent event) => _navigation.add(event);
  void emitGmValue(GmValueEvent event) => _gmValue.add(event);
  void emitGmCall(GmCallEvent event) => _gmCall.add(event);

  Future<void> dispose() async {
    await _network.close();
    await _console.close();
    await _navigation.close();
    await _gmValue.close();
    await _gmCall.close();
  }
}

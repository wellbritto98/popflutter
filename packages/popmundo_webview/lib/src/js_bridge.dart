import 'package:popmundo_utils/popmundo_utils.dart';

class PopmundoJsBridge {
  PopmundoJsBridge(this.runtime, {this.onReady});

  final PopmundoRuntime runtime;
  void Function()? onReady;

  void handleArguments(List<dynamic> arguments) {
    if (arguments.isEmpty) return;
    final raw = arguments.first;
    if (raw is Map) {
      handle(Map<String, dynamic>.from(raw));
    }
  }

  void handle(Map<String, dynamic> message) {
    final type = message['type'];
    final payload = message['payload'] is Map
        ? Map<String, dynamic>.from(message['payload'] as Map)
        : <String, dynamic>{};
    switch (type) {
      case 'ready':
        onReady?.call();
      case 'network':
        runtime.events.emitNetwork(
          NetworkEvent(
            method: '${payload['method'] ?? 'GET'}',
            url: '${payload['url'] ?? ''}',
            status: payload['status'] is int
                ? payload['status'] as int
                : int.tryParse('${payload['status']}'),
            body: payload['body'] as String?,
            bodyTruncated: payload['bodyTruncated'] == true,
            bodyOmitted: payload['bodyOmitted'] == true,
            source: '${payload['source'] ?? 'fetch'}',
          ),
        );
      case 'console':
        runtime.events.emitConsole(
          ConsoleEvent(
            level: '${payload['level'] ?? 'log'}',
            message: '${payload['message'] ?? ''}',
          ),
        );
    }
  }
}

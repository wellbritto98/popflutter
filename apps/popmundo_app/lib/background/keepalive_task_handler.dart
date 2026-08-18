import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level entry for the foreground task isolate (AD-012: heartbeat only).
@pragma('vm:entry-point')
void keepaliveStartCallback() {
  FlutterForegroundTask.setTaskHandler(KeepaliveTaskHandler());
}

/// Emits an ISO-8601 heartbeat on each repeat tick. No TimedFetch / WebView.
class KeepaliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({
      'heartbeat': timestamp.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
